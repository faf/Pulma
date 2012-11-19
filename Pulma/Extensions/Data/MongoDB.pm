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

# set unicode flag for all data from MongoDB
$MongoDB::BSON::utf8_flag_on = 1;

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

=item 3. (boolean) flag to return data object instead of data
structure (optional, default: false)

=back

=head2 Returns

=over

=item (link to hash) resulting hash

=back

=head2 Structure of resulting hash

Structure of resulting hash mimics the similar structure of resulting hash in class
for working with local DB data source. See Pulma::Core::DB for details

=cut

sub get_entity {
    my $self = shift;
    my $id = shift;
    my $etype = shift;
    my $return_object = shift || 0;

# try to get entity from MongoDB
    my $result;
    eval {
	@$result = $self->{'db'}->get_database($self->{'config'}->{'database'})->get_collection('entities')->find( { 'id' => $id,
														     'etype' => $etype } )->all();
    };
    if ($@) {
	return { 'error' => $@ };
    }
    else {

	log_it( 'debug',
		$self->{'name'} .
		    '::get_entity: successfully got entities (%s) with id %s and of type %s',
		scalar(@$result), $id, $etype );

# unbless resulting hash from objects and remove internal '_id' field if need to
	unless ($return_object) {

	    foreach (@$result) {
		unbless $_;
		delete $_->{'_id'};
	    }

# all data that comes from MongoDB is in Unicode (actually unicode flag should
# already be set by MongoDB, but we set it once again just in case...
	    $result = set_unicode_flag($result, 1);

	}

	return { 'data' => $result };
    }
}

=head1 Method: get_entities

=head2 Description

Method to get entities of a given type and (maybe) filtered by some criteria

=head2 Argument(s)

=over

=item 1. (link to array) filters to choose entities

=item 2. (string) entities' type

=item 3. (integer) entities limit (optional, default: no limits)

=item 4. (integer) offset (optional, default: no offset)

=back

=head2 Returns

=over

=item (array) entities (as an array of hashes, each one stands for an entity)

=back

=head2 Filters structure

See Pulma::Data for details

=cut

sub get_entities {
    my $self = shift;
    my $filters = shift;
    my $etype = shift;
    my $limit = shift;
    my $offset = shift;

# construct filters for query to MongoDB based upon incoming filters
    $filters = $self->_construct_filters($filters, $etype);

    unless (defined $filters) {

	log_it( 'err',
		$self->{'name'} .
		    "::get_entities: can't get entities of type %s: invalid filters supplied",
		$etype );

	return [];

    }

    log_it( 'debug',
	    $self->{'name'} .
		'::get_entities: successfully constructed filters for getting entities of type %s',
	    $etype );

# try to get entities
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

	log_it( 'debug',
		$self->{'name'} .
		    '::get_entities: successfully got %s entities of type %s',
		scalar(@$result), $etype );

# unbless resulting hashes from objects
	foreach (@$result) {
	    unbless $_;
	    delete $_->{'_id'};
	}

# all data that comes from MongoDB is in Unicode
	$result = set_unicode_flag($result, 1);

	return $result;

    }
}

=head1 Method: get_entities_count

=head2 Description

Method to count entities of a given type and (maybe) filtered by some criteria

=head2 Argument(s)

=over

=item 1. (link to array) filters to choose entities

=item 2. (string) entities' type

=back

=head2 Returns

=over

=item (integer) number of entities

=back

=head2 Filters structure

See Pulma::Data for details

=cut

sub get_entities_count {
    my $self = shift;
    my $filters = shift;
    my $etype = shift;

    my $result = 0;

# construct filters for query to MongoDB based upon incoming filters
    $filters = $self->_construct_filters($filters, $etype);

    unless (defined $filters) {

	log_it( 'err',
		$self->{'name'} .
		    "::get_entities_count: can't count entities of type %s: invalid filters supplied",
		$etype );

	return [];

    }

    log_it( 'debug',
	    $self->{'name'} .
		'::get_entities_count: successfully constructed filters for counting entities of type %s',
	    $etype );

# try to count entities
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

    log_it( 'debug',
	    $self->{'name'} .
		'::get_entities_count: successfully counted entities of type %s, got %s',
	    $etype, $result );

    return $result;
}

=head1 Method: create_entity

=head2 Description

Method to create new entity

=head2 Argument(s)

=over

=item 1. (link to hash) entity

=back

=head2 Returns

=over

=item (integer) entity id on success I<or> 0 on error

=back

=cut

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
		    "::create_entity: can't create entity with id %s and of type %s: there is already entity with the same id! Got %s entity(ies)",
		$entity->{'id'}, $entity->{'etype'}, scalar(@{$temp->{'data'}}) );

	return 0;

    }

    log_it( 'debug',
	    $self->{'name'} .
		'::create_entity: entity with id %s and of type %s not found in database',
	    $entity->{'id'}, $entity->{'etype'} );

# try to create entity
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

	log_it( 'debug',
		$self->{'name'} .
		    '::create_entity: successfully created entity with id %s and of type %s',
		$entity->{'id'}, $entity->{'etype'} );

	return $entity->{'id'};

    }
}

=head1 Method: delete_entity

=head2 Description

Method to delete entity

=head2 Argument(s)

=over

=item 1. (link to hash) entity

=back

=head2 Returns

=over

=item (integer) 1 on success I<or> 0 on error

=back

=cut

sub delete_entity {
    my $self = shift;
    my $entity = shift;

# check entity id and type
    unless (exists($entity->{'id'})) {

	log_it( 'err',
		$self->{'name'} .
		    '::delete_entity: attempt to delete entity without id' );

	return 0;

    }

    unless (exists($entity->{'etype'})) {

	log_it( 'err',
		$self->{'name'} .
		    '::delete_entity: attempt to delete entity without type' );

	return 0;

    }

# try to delete entity
    my $result = 0;
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

    log_it( 'debug',
	    $self->{'name'} .
		'::delete_entity: successfully deleted entity with id %s and of type %s',
	    $entity->{'id'}, $entity->{'etype'} );

    return 1;
}

=head1 Method: delete_entities

=head2 Description

Method to delete entities of a given type filtered by some criteria

=head2 Argument(s)

=over

=item 1. (link to array) filters to choose entities

=item 2. (string) entities' type

=back

=head2 Returns

=over

=item (link to hash) resulting hash

=back

=head2 Structure of resulting hash

{
    'deleted'	=> <number of successfully deleted entities>,

    'deleted_ids' => [ array of ids of successfully deleted entities ],

    'failed'	=> <number of entities failed to delete>
}

=cut

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

=head1 Method: update_entity

=head2 Description

Method to update an existed entity

=head2 Argument(s)

=over

=item 1. (link to hash) entity

=back

=head2 Results

=over

=item 1 on success I<or> 0 on error

=back

=cut

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

# get entity as an object
    my $entity_object = $self->get_entity($entity->{'id'}, $entity->{'etype'}, 1);

    if (exists($entity_object->{'error'})) {

	log_it( 'err',
		$self->{'name'} .
		    "::update_entity: can't check entity with id %s and of type %s for existance: %s",
		$entity->{'id'}, $entity->{'etype'}, $entity_object->{'error'} );

	return 0;

    }
    elsif (scalar(@{$entity_object->{'data'}}) != 1) {

	log_it( 'err',
		$self->{'name'} .
		    "::update_entity: failed to update entity with id %s and of type %s for existance: there are several (%s) entities with the same ids!",
		$entity->{'id'}, $entity->{'etype'}, scalar(@{$entity_object->{'data'}}) );

	return 0;

    }
    elsif (!exists($entity_object->{'data'}->[0]->{'_id'})) {

	log_it( 'err',
		$self->{'name'} .
		    "::update_entity: failed to update entity with id %s and of type %s for existance: something weird, can't get internal id of the entity!",
		$entity->{'id'}, $entity->{'etype'} );

	return 0;

    }
    else {

	log_it( 'debug',
		$self->{'name'} .
		    "::update_entity: entity with id %s and of type %s exists and unique, successfully got it as an object",
		$entity->{'id'}, $entity->{'etype'} );

    }

# prepare entity object for update
    my $updated_entity = $entity_object->{'data'}->[0];
    $updated_entity->{'modtime'} = time;
    $updated_entity->{'attributes'} = $entity->{'attributes'};

# try to update entity
    my $result = 0;
    eval {
# prevent errors on insert of binary data or strings containing wide characters
	$updated_entity = set_unicode_flag($updated_entity, 0);
	$result = $self->{'db'}->get_database($self->{'config'}->{'database'})->get_collection('entities')->save( $updated_entity,
														  { 'safe' => 1 } );
# return to native Unicoded data representation
	$updated_entity = set_unicode_flag($updated_entity, 1);
    };
    if ($@) {

	log_it( 'err',
		$self->{'name'} .
		    "::update_entity: can't update entity %s of type %s: got error %s",
		$entity->{'id'}, $entity->{'etype'}, $@ );
	return 0;

    }

    log_it( 'debug',
	    $self->{'name'} .
		"::update_entity: successfully updated entity with id %s and of type %s",
	    $entity->{'id'}, $entity->{'etype'} );

    return 1;
}

############################## Private methods ##################################

# Method: _construct_filters
# Description
#	Construct filters for query to MongoDB based upon incoming standard
#	Pulma filters
# Argument(s)
#	1. (link to array) filters to choose (and (maybe) sort) entities
#	2. (string) entities' type
# Returns
#	(link to hash) resulting hash
# Structure of the resulting hash:
#	{
#	    'filters' => { hash: argument for MongoDB's methods find and count },
#	    'sorting' => [ array of hashes: arguments for MongoDB's method sort ]
#	}

sub _construct_filters {
    my $self = shift;
    my $filters = shift;
    my $etype = shift;

# validate structure of incoming filters (should be array)
    unless (ref($filters) eq 'ARRAY') {

	log_it( 'err',
		$self->{'name'} .
		    '::_construct_filters: invalid filters supplied. Expected array, got %s, filters ignored',
		ref($filters) );

	return undef;

    }

# check whether there are at least one actual filter
    unless (scalar(@$filters)) {

# there are no actual filters, set the only one filter by entity type

	return { 'filters' => { 'etype' => $etype }, 'sorting' => [] };

    }

# construct filters for query to MongoDB from all incoming filters
    my $result = [];
    my $sorting = [];
    foreach my $filter (@$filters) {

# validate structure of incoming filter (should be array)
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

# simple equality condition
			push ( @$temp,
			       { 'attributes.' . $condition->{'name'} => $value } );

		    }
		    else {

# more complicated conditions
			my $temp2 = { { '>=' => '$gte',
					'<=' => '$lte',
					'>' => '$gt',
					'<' => '$lt',
					'<>' => '$ne',
					'~' => '$regex',
					'~~' => '$regex' }->{$condition->{'op'}} => $value };

# set case-insensitive regular expression mode for '~~' operation
			if ($condition->{'op'} eq '~~') {
			    $temp2->{'$options'} = 'i';
			}

			push( @$temp,
			      { 'attributes.' . $condition->{'name'} => $temp2 } );

		    }

		}
		else {

# set sorting mode for sorting operation
		    $sort->{'attributes.' . $condition->{'name'}} = ($condition->{'sort'} eq 'desc') ||
								   ($condition->{'sort'} eq 'ndesc') ?
								   -1 :
								   1;
		}

	    }

	}

	if (scalar(@$temp) > 1) {
# more than one operation specified for the filter - use logical 'OR' operator
	    push(@$result, { '$or' => $temp });
	}
	elsif (scalar(@$temp)) {
	    push(@$result, $temp->[0]);
	}

	if (scalar(keys(%$sort))) {
	    push(@$sorting, $sort);
	}

    }

# set additional filter by entity type
    push ( @$result, { 'etype' => $etype } );

    return { 'filters' => { '$and' => normalize_structure($result) },
	     'sorting' => $sorting };

}

1;
