=head1 Pulma::Extensions::Data::MongoDB

Part of Pulma system

Class for operations with MongoDB as a source of main data

Copyright (C) 2012 Fedor A. Fetisov <faf@ossg.ru>. All Rights Reserved

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License

=cut

package Pulma::Extensions::Data::MongoDB;

use strict;
use warnings;

use Data::Structure::Util qw( unbless );
use MongoDB;

use Pulma::Service::Data::Operations;
use Pulma::Service::Log;

=head1 Method: new

=head2 Description

Class constructor

=head2 Argument(s)

=over

=item 1. (link to hash) configuration

=item 2. (link to link to hash) cache hash

=back

=head2 Returns

=over

=item (object) instance of class I<or> undef on initialization error

=back

=head2 Configuration hash structure

see in example Pulma configuration file - data section of the configurations
of Main data, Authorization, and Logger modules

=cut

sub new {
    my $package = shift;
    my $config = shift;
    my $cache = shift;
    $cache = $$cache;
    my $name = __PACKAGE__;

    my $self = {
	'config' => $config,
	'name' => $name
    };

# try to establish connection with the MongoDB (or restore it from cache)
    eval {
	$self->{'db'} = $cache->{$self->{'name'} . '_db'} ||
			    MongoDB::Connection->new( $self->{'config'} );
    };
    if ($@) {

	log_it( 'err',
		$self->{'name'} .
		    '::new: failed to initialize MongoDB connection: %s',
		$@ );

	return undef;
    }

    log_it('debug', $self->{'name'} . '::new: MongoDB connection initialized');

# store MongoDB connection object into common built-in cache
    $cache->{$self->{'name'} . '_db'} ||= $self->{'db'};

    return bless($self, $package);
}


=head1 Method: get_entity

=head2 Description

Method to get entity by id and entity's type

=head2 Argument(s)

=over

=item 1. (string) entity id

=item 2. (string) entity type

=item 3. (boolean) flag to save internal id field (i.e. '_id') (optional,
default: false)

=back

=head2 Returns

=over

=item (link to hash) result hash

=back

=head2 Structure of result hash

Structure of result hash mimics the similar structure of result hash in class
for working with local DB data source. See Pulma::Core::DB for details

=cut

sub get_entity {
    my $self = shift;
    my $id = shift;
    my $etype = shift;
    my $save_id = shift || 0;

    my $result;
    eval {
	@$result = $self->{'db'}->get_database($self->{'config'}->{'database'})->get_collection('entities')->find( { 'id' => $id,
														     'etype' => $etype } )->all();
    };
    if ($@) {
	return { 'error' => $@ };
    }
    else {
# untie resulting hash from objects
	foreach (@$result) {
	    unbless $_;
# remove internal '_id' field if need to
	    delete $_->{'_id'} unless $save_id;
	}
# all data that comes from MongoDB is Unicode
	$result = set_unicode_flag($result, 1);
	return { 'data' => $result };
    }
}

# to document
sub get_entities {
    my $self = shift;
    my $filters = shift;
    my $etype = shift;
    my $limit = shift;
    my $offset = shift;

    $filters = $self->_construct_filters($filters, $etype);

    unless (defined $filters) {

	log_it( 'err',
		$self->{'name'} .
		    "::get_entities: can't get entities of type %s: invalid filters supplied",
		$etype );

	return [];

    }

    my $result;
    eval {
	my $cursor = $self->{'db'}->get_database($self->{'config'}->{'database'})->get_collection('entities')->find( $filters->{'filters'} );
	foreach my $sorting (@{$filters->{'sorting'}}) {
	    $cursor = $cursor->sort( $sorting );
	}
	if (defined($limit)) {
	    $cursor = $cursor->limit($limit);
	}
	if (defined($offset)) {
	    $cursor = $cursor->skip($offset);
	}
	@$result = $cursor->all();
    };
    if ($@) {

	log_it( 'err',
		$self->{'name'} .
		    "::get_entities: can't get entities of type %s: got error %s",
		$etype, $@ );
	return [];

    }
    else {
# all data that comes from MongoDB is Unicode
	foreach (@$result) {
	    unbless $_;
	    delete $_->{'_id'};
	}
	$result = set_unicode_flag($result, 1);
	return $result;
    }


}

# to document
sub get_entities_count {
    my $self = shift;
    my $filters = shift;
    my $etype = shift;

    my $result = 0;

    $filters = $self->_construct_filters($filters, $etype);

    unless (defined $filters) {

	log_it( 'err',
		$self->{'name'} .
		    "::get_entities_count: can't count entities of type %s: invalid filters supplied",
		$etype );

	return [];

    }

    eval {
	$result = $self->{'db'}->get_database($self->{'config'}->{'database'})->get_collection('entities')->count( $filters->{'filters'} );
    };
    if ($@) {

	log_it( 'err',
		$self->{'name'} .
		    "::get_entities_count: can't count entities of type %s: got error %s",
		$etype, $@ );
	return 0;

    }

    return $result;
}

# to document
sub create_entity {
    my $self = shift;
    my $entity = shift;

# check entity id (should not exist in database)
    my $temp = $self->get_entity( $entity->{'id'}, $entity->{'etype'} );
    if (exists($temp->{'error'})) {

	log_it( 'err',
		$self->{'name'} .
		    '::create_entity: failed to check entity with id %s and of type %s for existance: %s',
		$entity->{'id'}, $entity->{'etype'}, $temp->{'error'} );

	return 0;

    }
    elsif (scalar(@{$temp->{'data'}})) {

	log_it( 'err',
		$self->{'name'} .
		    "::create_entity: can't create entity with id %s and of type %s: there is already entity with the same id! Got %s entity(ies).",
		$entity->{'id'}, $entity->{'etype'}, scalar(@{$temp->{'data'}}) );

	return 0;

    }

    my $object_id;
    eval {
# prevent errors on insert of binary data or strings containing wide characters
	$entity = set_unicode_flag($entity, 0);
	$object_id = $self->{'db'}->get_database($self->{'config'}->{'database'})->get_collection('entities')->insert($entity);

    };
    if ($@) {

	log_it( 'err',
		$self->{'name'} .
		    '::create_entity: failed to insert new entity of type %s into database: %s',
	$entity->{'etype'}, $@ );

	return 0;

    }
    elsif (!$object_id) {

	log_it( 'err',
		$self->{'name'} .
		    '::create_entity: failed to insert new entity of type %s into database: something went wrong, object not created',
	$entity->{'etype'}, $@ );

	return 0;

    }
    else {

	return $entity->{'id'};

    }
}

# to document
sub delete_entity {
    my $self = shift;
    my $entity = shift;


    unless (exists($entity->{'id'})) {

	log_it( 'err',
		$self->{'name'} .
		    '::delete_entity: attempt to delete entity without id!' );

	return 0;

    }

    unless (exists($entity->{'etype'})) {

	log_it( 'err',
		$self->{'name'} .
		    '::delete_entity: attempt to delete entity without type!' );

	return 0;

    }

    my $result = 0;
# try to delete entity
    eval {
	$result = $self->{'db'}->get_database($self->{'config'}->{'database'})->get_collection('entities')->remove( { 'id' => $entity->{'id'},
														      'etype' => $entity->{'etype'} },
														    { 'just_one' => 1,
														       'safe' => 1 } );
    };
    if ($@) {

	log_it( 'err',
		$self->{'name'} .
		    "::get_entities_count: can't delete entity %s of type %s: got error %s",
		$entity->{'id'}, $entity->{'etype'}, $@ );
	return 0;

    }

    return 1;

}

# to document
sub delete_entities {
    my $self = shift;
    my $filters = shift;
    my $etype = shift;

# get list of entities to delete
    my $entities = $self->get_entities($filters, $etype);
    my $result = { 'deleted' => 0,
		   'deleted_ids' => [],
		   'failed' => 0 };

    foreach (@$entities) {

	if ($self->delete_entity($_)) {

	    $result->{'deleted'}++;
	    push(@{$result->{'deleted_ids'}}, $_->{'id'});

	}
	else {

	    $result->{'failed'}++;

	}

    }

    return $result;

}

# to document
sub update_entity {
    my $self = shift;
    my $entity = shift;

# check entity id
    unless (exists($entity->{'id'})) {

	log_it( 'err',
		$self->{'name'} .
		    '::update_entity: attempt to update entity without id!' );

	return 0;

    }

# check entity type
    unless (exists($entity->{'etype'})) {

	log_it( 'err',
		$self->{'name'} .
		    '::update_entity: attempt to update entity without type!' );

	return 0;

    }

    log_it( 'debug',
	    $self->{'name'} .
		'::update_entity: updating entity with id %s and of type %s',
	    $entity->{'id'}, $entity->{'etype'} );

# check entity's existance (by given id and type) and get it's internal id
    my $check = $self->get_entity($entity->{'id'}, $entity->{'etype'}, 1);

    if (exists($check->{'error'})) {

	log_it( 'err',
		$self->{'name'} .
		    "::update_entity: can't check entity with id %s and of type %s for existance: %s",
		$entity->{'id'}, $entity->{'etype'}, $check->{'error'} );

	return 0;

    }
    elsif (scalar(@{$check->{'data'}}) != 1) {

	log_it( 'err',
		$self->{'name'} .
		    "::update_entity: failed to update entity with id %s and of type %s for existance: there are several (%s) entities with the same ids!",
		$entity->{'id'}, $entity->{'etype'}, scalar(@{$check->{'data'}}) );

	return 0;

    }
    elsif (!exists($check->{'data'}->[0]->{'_id'})) {

	log_it( 'err',
		$self->{'name'} .
		    "::update_entity: failed to update entity with id %s and of type %s for existance: something weird, can't get internal id of the entity!",
		$entity->{'id'}, $entity->{'etype'} );

	return 0;

    }
    else {

	log_it( 'debug',
		$self->{'name'} .
		    "::update_entity: entity with id %s and of type %s exists and unique, successfully got it's internal id",
		$entity->{'id'}, $entity->{'etype'} );

    }

# prepare entity for update
    $entity->{'_id'} = $check->{'_id'};
    $entity->{'modtime'} = time;

# try to update entity
    my $result = 0;
    eval {
	$result = $self->{'db'}->get_database($self->{'config'}->{'database'})->get_collection('entities')->save( $entity,
														  { 'safe' => 1 } );
    };
    if ($@) {

	log_it( 'err',
		$self->{'name'} .
		    "::update_entity: can't update entity %s of type %s: got error %s",
		$entity->{'id'}, $entity->{'etype'}, $@ );
	return 0;

    }

    return 1;

}

############################## Private methods ##################################


# to document
sub _construct_filters {
    my $self = shift;
    my $filters = shift;
    my $etype = shift;

# validate structure of filters (should be array)
    unless (ref($filters) eq 'ARRAY') {

	log_it( 'err',
		$self->{'name'} .
		    '::_construct_filters: invalid filters supplied. Expected array, got %s, filters ignored',
		ref($filters) );

	return undef;

    }

# check whether there are at least one actual filter
    unless (scalar(@$filters)) {

	return { 'filter' => { 'etype' => $etype }, 'sorting' => [] };

    }

    my $result = [];
    my $sorting = [];
    foreach my $filter (@$filters) {

	unless (ref($filter) eq 'ARRAY') {

	    log_it( 'err',
		    $self->{'name'} .
			'::_construct_filters: invalid filter supplied. Expected array, got %s, filter ignored',
		    ref($filter) );
	    next;

	}

	my $temp = [];
	my $sort = {};
# validate each condition in the filter (skip invalid conditions)
	foreach my $condition (@$filter) {

	    if ( (ref($condition) ne 'HASH') ||
		 !exists($condition->{'name'}) ||
		 ( !exists($condition->{'value'}) ||
		 !check_filter_operation($condition->{'op'}) ) &&
		 !exists($condition->{'sort'}) ) {

		log_it( 'err',
			$self->{'name'} .
			    '::_construct_filters: invalid condition supplied, omitted' );

	    }
	    else {

		if (exists($condition->{'value'})) {

# check regular expression on '~' or '~~' operations,
# replace operation with '=' if regular expression is invalid, fix regular
# expression otherwise

		    my $value = $condition->{'value'};

		    if ( ($condition->{'op'} eq '~') ||
			 ($condition->{'op'} eq '~~') ) {

			unless ( ($condition->{'value'} =~ /^\/(.+)\/$/) &&
			    eval { '' =~ /$1/; 1 } ) {

			    $condition->{'op'} = '=';

			}
			else {

			    $value = $1;

			}
		    }

		    if ($condition->{'op'} eq '=') {

			push ( @$temp,
			       { 'attributes.' . $condition->{'name'} => $value } );

		    }
		    else {
			my $temp2 = { { '>=' => '$gte',
					'<=' => '$lte',
					'>' => '$gt',
					'<' => '$lt',
					'<>' => '$ne',
					'~' => '$regex',
					'~~' => '$regex' }->{$condition->{'op'}} => $value };
			if ($condition->{'op'} eq '~~') {
			    $temp2->{'$options'} = 'i';
			}

			push( @$temp,
			      { 'attributes.' . $condition->{'name'} => $temp2 } );

		    }

		}
		else {
# sorting
		    $sort->{'attributes.' . $condition->{'name'}} = ($condition->{'sort'} eq 'desc') ||
								   ($condition->{'sort'} eq 'ndesc') ?
								   -1 :
								   1;
		}

	    }

	}

	if (scalar(@$temp) > 1) {
	    push(@$result, { '$or' => $temp });
	}
	elsif (scalar(@$temp)) {
	    push(@$result, $temp->[0]);
	}

	if (scalar(keys(%$sort))) {
	    push(@$sorting, $sort);
	}

    }

    push ( @$result, { 'etype' => $etype } );

    return { 'filters' => { '$and' => $result },
	     'sorting' => $sorting };

}

1;
