=head1 Pulma::Data

Part of Pulma system

Class for operations with source of main data

Copyright (C) 2011 Fedor A. Fetisov <faf@ossg.ru>. All Rights Reserved

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

package Pulma::Data;

use strict;
use warnings;

use Pulma::Cacher::Data;
use Pulma::Core::DB;
use Pulma::Service::Functions;
use Pulma::Service::Log;

=head1 Method: new

=head2 Description

Class constructor

=head2 Argument(s)

=over

=item 1. (link to hash) configuration

=item 2. (link to link to hash) cache hash

=item 3. (string) real package name (optional)

=back

=head2 Returns

=over

=item (object) instance of class I<or> undef on initialization error

=back

=head2 Configuration hash structure

see in example Pulma configuration file

=cut

sub new {
    my $package = shift;
    my $config = shift;
    my $cache = shift;
    $cache = $$cache;
    my $name = shift || __PACKAGE__;

    my $self = {
	'config' => $config,
	'name' => $name
    };

# check for data source
    unless ($config->{'type'} eq 'localdb') {

	log_it( 'err',
		$self->{'name'} . "::new: unknown backend type for object: %s",
		$config->{'type'} );

	return undef;

    }
    else {

# data source: local DB

	log_it('debug', $self->{'name'} . '::new: initializing DB object');

# initialize object to work with local DB (or get it from cache if exists)
	$self->{'db'} = $cache->{$self->{'name'} . '_db'} ||
			    Pulma::Core::DB->new($config->{'data'});

	unless (defined $self->{'db'}) {

	    log_it( 'err',
		    $self->{'name'} . '::new: failed to initialize DB object' );

	    return undef;

	}

	log_it('debug', $self->{'name'} . '::new: DB object initialized');
    }

# set up data cache object if need to
    if ( exists($config->{'cache'}) && $config->{'cache'} eq 'memory' ) {

	$self->{'cache'} = Pulma::Cacher::Data->new( \$cache, $self->{'name'} );

# store local DB connection into cache
	$cache->{$self->{'name'} . '_db'} ||= $self->{'db'};

    }

    return bless($self, $package);
}

=head1 Method: get_entity_by_id

=head2 Description

Method to get data entity by it's identifier

=head2 Argument(s)

=over

=item 1. (string) entity identifier

=item 2. (string) entity type

=back

=head2 Returns

=over

=item (link to hash) entity I<or> undef on error

=back

=head2 Entity structure

{

    'id'	=> <entity identifier>,
    'modtime	=> <timestamp of last modification time>,
    'attributes => { <hash of entity attributes> }

}

Each attribute value is in form of array (thus there can be more than one value for an attribute).

For example:

=over

=item 'attribute1' => [ 'value1' ], 'attribute2' => [ 'value1', 'value2' ]

=back

=cut

sub get_entity_by_id {
    my $self = shift;
    my $id = shift;
    my $etype = shift;

    my $result = undef;

# check type of data source
    if ($self->{'config'}->{'type'} eq 'localdb') {

# data source: local DB

# try to get entity (id and time of last modification)
	my $entity = $self->{'db'}->execute( {'select' => 1, 'cache' => 1},
					     'select id, modtime from entities where id = ? and etype = ?',
					     $id, $etype);

	if (exists($entity->{'error'})) {

	    log_it( 'err',
		    $self->{'name'} .
			'::get_entity_by_id: got error when tried to get entity of type %s with id %s: %s',
		    $etype, $id, $entity->{'error'} );

	}
	elsif (!scalar(@{$entity->{'data'}})) {

	    log_it( 'debug',
		    $self->{'name'} .
			'::get_entity_by_id: entity with id %s not found',
		    $id );

	}
	elsif (scalar(@{$entity->{'data'}}) != 1) {

	    log_it( 'err',
		    $self->{'name'} .
			'::get_entity_by_id: something weird, got more than one entity with id %s',
		    $id );

	}
	else {

	    log_it( 'debug',
		    $self->{'name'} .
			'::get_entity_by_id: successfully got entity by id %s',
		    $id );

# entity id is valid, look for this entity in cache
	    if (exists($self->{'cache'})) {

		log_it( 'debug',
			$self->{'name'} .
			    '::get_entity_by_id: look for actual entity with id %s in cache',
			$id );

		my $data = $self->{'cache'}->get( $id,
						  $entity->{'data'}->[0]->{'modtime'} );
		if (defined $data) {

		    log_it( 'debug',
			    $self->{'name'} .
				'::get_entity_by_id: actual entity with id %s found in cache',
			    $id );

		    return $data;

		}
		else {

		    log_it( 'debug',
			    $self->{'name'} .
				'::get_entity_by_id: actual entity with id %s not found in cache',
			    $id );

		}
	    }

# prepare entity hash
	    $result = {
			'id' => $id,
			'modtime' => $entity->{'data'}->[0]->{'modtime'},
			'etype' => $etype, 'attributes' => {}
	    };

# try to get attributes for the entity
	    my $attributes = $self->{'db'}->execute( {'select' => 1, 'cache' => 1},
						     'select * from attributes where entity = ?',
						     $id );
	    if (exists($attributes->{'error'})) {

		log_it( 'err',
			$self->{'name'} .
			    '::get_entity_by_id: got error when tried to get attributes for an entity with id %s: %s',
			$id, $attributes->{'error'} );

	    }
	    else {

# attributes obtained

		foreach my $attribute (@{$attributes->{'data'}}) {
		    if (exists($result->{'attributes'}->{$attribute->{'name'}})) {

		        push( @{$result->{'attributes'}->{$attribute->{'name'}}},
			      $attribute->{'val'} );

		    }
		    else {

			$result->{'attributes'}->{$attribute->{'name'}} = [$attribute->{'val'}];

		    }
		}
	    }
	}

# store entity in cache (if have to)
	if ((defined $result) && (exists($self->{'cache'}))) {

	    log_it( 'debug',
		    $self->{'name'} .
			'::get_entity_by_id: stored entity with id %s in cache',
		    $id );

	    $self->{'cache'}->put($id, $result);

	}

	return $result;

    }
    else {

	log_it( 'warning',
		$self->{'name'} .
		    "::get_entity_by_id: unknown backend type %s, can't obtain data!",
		$self->{'config'}->{'type'} );

	return $result;

    }
}

=head1 Method: get_entities_count

=head2 Description

Method to get count of entities of a given type and (maybe) filtered by some criteria

=head2 Argument(s)

=over

=item 1. (link to array) filters to choose entities

=item 2. (string) entities' type

=back

=head2 Returns

=over

=item (integer) entities' count

=back

=head2 Filters structure

[ [filter1], [filter2], ... ]

That means B<filter1> && B<filter2> && ...

All filters are optional. Each filter is an array:

[A, B, C, ...]

That means B<A> || B<B> || B<C> || ...

All conditions are optional. Each condition is a hash:

{ 'name' => <name>, 'op' => <operation>, 'value' => <value> }

where <name> is a name of entity's attribute, <value> is the value of that
attribute, and <operation> is one of '=', '<=', '>=', '<', '>'

=cut

sub get_entities_count {
    my $self = shift;
    my $filters = shift;
    my $etype = shift;

    if ($self->{'config'}->{'type'} eq 'localdb') {

	my $entities = $self->_get_entities_from_localdb($filters, $etype);

	return scalar(@$entities) || 0;

    }
    else {

	log_it( 'warning',
		$self->{'name'} .
		    "::get_entities_count: unknown backend type %s, can't obtain data!",
		$self->{'config'}->{'type'} );

	return 0;

    }
}

=head1 Method: get_entities

=head2 Description

Method to get entities of a given type and (maybe) filtered by some criteria

=head2 Argument(s)

=over

=item 1. (link to array) filters to choose entities

=item 2. (string) entities' type

=back

=head2 Returns

=over

=item (array) entities (as an array of hashes, see above in description of
B<get_entity_by_id> method)

=back

=cut

sub get_entities {
    my $self = shift;
    my $filters = shift;
    my $etype = shift;

    if ($self->{'config'}->{'type'} eq 'localdb') {

	my $entities = $self->_get_entities_from_localdb($filters, $etype);
	my $result = [];

	foreach my $entity (@$entities) {

	    push (@$result, $self->get_entity_by_id($entity, $etype));

	}

	return $result;

    }
    else {

	log_it( 'warning',
		$self->{'name'} .
		    "::get_entities: unknown backend type %s, can't obtain data!",
		$self->{'config'}->{'type'} );

	return [];

    }
}

=head1 Method: sort_entities

=head2 Description

Method to sort entities by a given criteria

=head2 Argument(s)

=over

=item 1. (link to array) entities

=item 2. (string) attribute name to sort entities by

=item 3. (string) sort order (optional, default: ascendant sort with symbolic
comparsion)

=back

Available sort orders:

=over

=item 'asc' - for acendant sort with symbolic comparsion

=item 'desc' - for descendant sort with symbolic comparsion

=item 'nasc' - for acendant sort with numeric comparsion

=item 'ndesc' - for descendant sort with numeric comparsion

=back

=head2 Results

=over

=item (link to array) sorted entities

=back

=cut

sub sort_entities {
    my $self = shift;
    my $entities = shift;
    my $name = shift;
    my $order = shift;
    $order ||= 'asc';

    unless (ref($entities) eq 'ARRAY') {

	log_it( 'err',
		$self->{'name'} .
		    '::sort_entities: invalid data supplied. Expected array, got %s. Nothing to sort',
		ref($entities) );

	return $entities;

    }

    @$entities = sort {
	_compare_attributes($a, $b, $name, $order)
    } @$entities;

    return $entities;
}

=head1 Method: create_entity

=head2 Description

Method to create new entity

=head2 Argument(s)

=over

=item 1. (link to hash) entity

=back

=head2 Results

=over

=item 1 on success I<or> 0 on error

=back

=cut

sub create_entity {
    my $self = shift;
    my $entity = shift;

# check type of data source
    if ($self->{'config'}->{'type'} ne 'localdb') {

	log_it( 'warning',
		$self->{'name'} .
		    "::create_entity: unknown backend type %s, can't update data!",
		$self->{'config'}->{'type'} );

	return 0;

    }
    else {
# data source: local DB

# check entity type
	unless (exists($entity->{'etype'})) {

	    log_it( 'err',
		    $self->{'name'} .
			'::create_entity: attempt to create entity without type!' );

	    return 0;

	}

# set entity id (if need to)
	$entity->{'id'} ||= generate_entity_id( $entity->{'etype'},
						$self->{'config'}->{'nodeid'} );

# set entity last modification time
	$entity->{'modtime'} ||= time;

	log_it( 'debug',
		$self->{'name'} .
		    '::create_entity: creating entity with id %s and of type %s',
		$entity->{'id'}, $entity->{'etype'} );

# check for entity with given id (there should be no duplicates)
	my $check = $self->{'db'}->execute( {'select' => 1, 'cache' => 1},
					    'select count(*) as count from entities where id = ?',
					    $entity->{'id'} );

	if (exists($check->{'error'})) {

	    log_it( 'err',
		    $self->{'name'} .
			"::create_entity: can't check entity with id %s and of type %s for existance: %s",
		    $entity->{'id'}, $entity->{'etype'}, $check->{'error'} );

	    return 0;

	}
	elsif (scalar(@{$check->{'data'}}) != 1) {

	    log_it( 'err',
		    $self->{'name'} .
			"::create_entity: can't check entity with id %s and of type %s for existance: something weird occured. Expected 1 value, got %s value(s)",
		    $entity->{'id'}, $entity->{'etype'}, scalar(@{$check->{'data'}}) );

	    return 0;

	}
	elsif ($check->{'data'}->[0]->{'count'} > 0) {

	    log_it( 'err',
		    $self->{'name'} .
			"::create_entity: can't create entity with id %s and of type %s: there is already entity with the same id! Got %s entity(ies).",
		    $entity->{'id'}, $entity->{'etype'}, $check->{'data'}->[0]->{'count'} );

	    return 0;

	}
	else {

	    log_it( 'debug',
		    $self->{'name'} .
			"::create_entity: entity with id %s and of type %s not found and thus can be created",
		    $entity->{'id'}, $entity->{'etype'} );

	}

# try to create entity
	my $res = $self->{'db'}->execute( {'select' => 1, 'cache' => 1},
					  'insert into entities (id, etype, modtime) values (?, ?, ?)',
					  $entity->{'id'}, $entity->{'etype'}, $entity->{'modtime'} );

	if (exists($res->{'error'})) {

	    log_it( 'err',
		    $self->{'name'} .
			"::create_entity: can't create entity with id %s and of type %s: %s",
		    $entity->{'id'}, $entity->{'etype'}, $res->{'error'} );

	    return 0;

	}
	elsif (!$res->{'data'}) {

	    log_it( 'err',
		    $self->{'name'} .
			"::create_entity: can't create entity with id %s and of type %s: something went wrong",
		    $entity->{'id'}, $entity->{'etype'} );

	    return 0;

	}
	else {

	    log_it( 'debug',
		    $self->{'name'} .
			"::create_entity: entity with id %s and of type %s successfully created",
		    $entity->{'id'}, $entity->{'etype'} );

	}

# entity created
# try to store attributes
	if (!$self->_store_entity_attributes($entity)) {

	    log_it( 'err',
		    $self->{'name'} .
			"::create_entity: can't store some (or all) attributes for entity with id %s and of type %s!",
		    $entity->{'id'}, $entity->{'etype'} );

	    return 0;

	}
	else {

	    log_it( 'debug',
		    $self->{'name'} .
			"::create_entity: attributes for entity with id %s and of type %s successfully stored",
		    $entity->{'id'}, $entity->{'etype'} );

# put entity in cache (if need to)
	    if (exists($self->{'cache'})) {

		log_it( 'debug',
			$self->{'name'} .
			    '::create_entity: store entity with id %s in cache',
			$entity->{'id'} );

		$self->{'cache'}->put($entity->{'id'}, $entity);

	    }

	    return 1;

	}
    }
}

=head1 Method: update_entity

=head2 Description

Method to update attributes of an existed entity

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

# check type of data source
    if ($self->{'config'}->{'type'} ne 'localdb') {

	log_it( 'warning',
		$self->{'name'} .
		    "::update_entity: unknown backend type %s, can't update data!",
		$self->{'config'}->{'type'} );

	return 0;

    }
    else {
# data source: local DB

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

# check entity's existance (by given id and type)
	my $check = $self->{'db'}->execute( {'select' => 1, 'cache' => 1},
					    'select count(*) as count from entities where id = ? and etype = ?',
					    $entity->{'id'}, $entity->{'etype'} );

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
			"::update_entity: can't check entity with id %s and of type %s for existance: something weird occured. Expected 1 value, got %s value(s)",
		    $entity->{'id'}, $entity->{'etype'}, scalar(@{$check->{'data'}}) );

	    return 0;

	}
	elsif ($check->{'data'}->[0]->{'count'} > 1) {

	    log_it( 'err',
		    $self->{'name'} .
			"::update_entity: can't check entity with id %s and of type %s for existance: there are several (%s) entities with the same ids!",
		    $entity->{'id'}, $entity->{'etype'}, $check->{'data'}->[0]->{'count'} );

	    return 0;

	}
	elsif (!$check->{'data'}->[0]->{'count'}) {

	    log_it( 'err',
		    $self->{'name'} .
			"::update_entity: can't update entity with id %s and of type %s: no such entity!",
		    $entity->{'id'}, $entity->{'etype'} );

	    return 0;

	}
	else {

	    log_it( 'debug',
		    $self->{'name'} .
			"::update_entity: entity with id %s and of type %s exists and unique",
		    $entity->{'id'}, $entity->{'etype'} );

	}

# try to delete old entity's attributes
	if (!$self->_delete_entity_attributes($entity)) {

	    log_it( 'err',
		    $self->{'name'} .
			"::update_entity: can't delete attributes for entity with id %s and of type %s!",
		    $entity->{'id'}, $entity->{'etype'} );

	    return 0;

	}
	else {

	    log_it( 'debug',
		    $self->{'name'} .
			"::update_entity: attributes for entity with id %s and of type %s successfully deleted",
		    $entity->{'id'}, $entity->{'etype'} );

	}

# try to set new time of the last modification for the entity
	log_it( 'debug',
		$self->{'name'} .
		    '::update_entity: setting new last modification time for entity with id %s and of type %s',
		$entity->{'id'}, $entity->{'etype'} );

	$entity->{'modtime'} = time;

	my $res = $self->{'db'}->execute( {'select' => 0, 'cache' => 1},
					  'update entities set modtime = ? where id = ? and etype = ?',
					  $entity->{'modtime'}, $entity->{'id'}, $entity->{'etype'} );

	if (exists($res->{'error'})) {

	    log_it( 'err',
		    $self->{'name'} .
			"::update_entity: can't set new last modification time for entity with id %s and of type %s: %s",
		    $entity->{'id'}, $entity->{'etype'}, $res->{'error'} );

	    return 0;

	}
	elsif (!$res->{'data'}) {

	    log_it( 'err',
		    $self->{'name'} .
			"::update_entity: can't set new last modification time for entity with id %s and of type %s: something weird happened",
		    $entity->{'id'}, $entity->{'etype'} );

	    return 0;

	}
	else {

	    log_it( 'debug',
		    $self->{'name'} .
			"::update_entity: new last modification time for entity with id %s and of type %s successfully set",
		    $entity->{'id'}, $entity->{'etype'} );

	}

# try to store new attributes
	if (!$self->_store_entity_attributes($entity)) {

	    log_it( 'err',
		    $self->{'name'} .
			"::update_entity: can't store some (or all) attributes for entity with id %s and of type %s!",
		    $entity->{'id'}, $entity->{'etype'} );

	    return 0;

	}
	else {

	    log_it( 'debug',
		    $self->{'name'} .
			"::update_entity: attributes for entity with id %s and of type %s successfully stored",
		    $entity->{'id'}, $entity->{'etype'} );

# put entity in cache (if need to)
	    if (exists($self->{'cache'})) {

		log_it( 'debug',
			$self->{'name'} .
			    '::update_entity: store entity with id %s in cache',
			$entity->{'id'} );

		$self->{'cache'}->put($entity->{'id'}, $entity);

	    }

	    return 1;

	}
    }
}

=head1 Method: delete_entity

=head2 Description

Method to delete existed entity

=head2 Argument(s)

=over

=item 1. (link to hash) entity

=back

=head2 Results

=over

=item 1 on success I<or> 0 on error

=back

=cut

sub delete_entity {
    my $self = shift;
    my $entity = shift;

# check type of data source
    if ($self->{'config'}->{'type'} ne 'localdb') {

	log_it( 'warning',
		$self->{'name'} .
		    "::delete_entity: unknown backend type %s, can't delete data!",
		$self->{'config'}->{'type'} );

	return 0;

    }
    else {

# data source: local DB

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

# try to delete entity
	log_it( 'debug',
		$self->{'name'} .
		    '::delete_entity: deleting entity with id %s and of type %s',
		$entity->{'id'}, $entity->{'etype'} );

	my $res = $self->{'db'}->execute( {'select' => 0, 'cache' => 1},
					  'delete from entities where id = ? and etype = ?',
					  $entity->{'id'}, $entity->{'etype'});

	if (exists($res->{'error'})) {

	    log_it( 'err',
		    $self->{'name'} .
			"::delete_entity: can't delete entity with id %s and of type %s: %s",
		    $entity->{'id'}, $entity->{'etype'}, $res->{'error'} );

	    return 0;

	}
	elsif (!$res->{'data'}) {

	    log_it( 'err',
		    $self->{'name'} .
			"::delete_entity: can't delete entity with id %s and of type %s: something went wrong",
		    $entity->{'id'}, $entity->{'etype'} );

	    return 0;

	}
	else {

	    log_it( 'debug',
		    $self->{'name'} .
			"::delete_entity: entity with id %s and of type %s successfully deleted from entities table",
		    $entity->{'id'}, $entity->{'etype'} );

	}

# try to delete all attributes for the entity
	if ($self->_delete_entity_attributes($entity)) {

	    log_it( 'debug',
		    $self->{'name'} .
			"::delete_entity: attributes for deleted entity with id %s successfully deleted",
		    $entity->{'id'} );

	}
	else {

	    log_it( 'warning',
		    $self->{'name'} .
			"::delete_entity: unable to delete attributes for deleted entity with id %s",
		    $entity->{'id'} );

	}

# remove entity from cache (if need to)
	if (exists($self->{'cache'})) {

	    log_it( 'debug',
		    $self->{'name'} .
			'::delete_entity: deleting entity with id %s from cache',
		    $entity->{'id'} );

	    $self->{'cache'}->del($entity->{'id'});

	}

	return 1;

    }
}

=head1 Method: delete_entities

=head2 Description

Method to delete existed entities

=head2 Argument(s)

=over

=item 1. (link to array) filters to choose entities

=item 2. (string) entities' type

=back

=head2 Results

=over

=item (link to hash) resulting hash

=back

=head2 Structure of resulting hash

{
    'deleted'	=> <number of successfully deleted entities>,

    'failed'	=> <number of entities failed to delete>

}

=cut

sub delete_entities {
    my $self = shift;
    my $filters = shift;
    my $etype = shift;

    my $result = { 'deleted' => 0, 'failed' => 0 };

    if ($self->{'config'}->{'type'} eq 'localdb') {

	my $entities = $self->_get_entities_from_localdb($filters, $etype);
	

	foreach my $entity (@$entities) {

	    my $res = $self->delete_entity( { 'id' => $entity,
					      'etype' => $etype } );

	    if ($res) {
		$result->{'deleted'}++;
	    }
	    else {
		$result->{'failed'}++;
	    }

	}

	return $result;

    }
    else {

	log_it( 'warning',
		$self->{'name'} .
		    "::delete_entities: unknown backend type %s, can't obtain data!",
		$self->{'config'}->{'type'} );

    }

    return $result;
}

############################## Private methods ##################################

# Method: _get_entities_from_localdb
# Description
#	Get entities of a given type and (maybe) filtered by some criteria
#	using local database as a data source
# Argument(s)
#	1. (link to array) filters to choose entities
#	2. (string) entities' type
# Returns
#	(link to array) entities (as an array of ids)

sub _get_entities_from_localdb {
    my $self = shift;
    my $filters = shift;
    my $etype = shift;

# validate structure of filters (should be array)
    unless (ref($filters) eq 'ARRAY') {

	log_it( 'err',
		$self->{'name'} .
		    '::_get_entities_from_localdb: invalid filters supplied. Expected array, got %s, filters ignored',
		ref($filters) );

	return [];

    }

    my $results = {};

    if (scalar(@$filters)) {

# at least one filter exists - get entities for each one of filters, and then
# calculate intersection

	my $first = 1;
	foreach my $filter (@$filters) {
# construct DB request for the filter
	    my $request = 'select distinct(entity) from attributes as a, entities as b where b.id = a.entity and etype = ? and (';
	    my @args = ($etype);
	    unless (ref($filter) eq 'ARRAY') {

		log_it( 'err',
			$self->{'name'} .
			    '::_get_entities_from_localdb: invalid filter supplied. Expected array, got %s, filter ignored',
			ref($filter) );
		next;

	    }

# validate each condition in the filter (skip invalid conditions)
	    foreach my $condition (@$filter) {

		if ( (ref($condition) ne 'HASH') ||
		     !exists($condition->{'name'}) ||
		     !exists($condition->{'value'}) ||
		     !$self->_check_filter_operation($condition->{'op'}) ) {

		    log_it( 'err',
			    $self->{'name'} .
				'::_get_entities_from_localdb: invalid condition supplied, omitted' );

		}
		else {

		    $request .= (scalar(@args) == 1 ? '' : ' or ') .
				'(name = ? and val ' . $condition->{'op'} .
				' ?)';
		    push (@args, $condition->{'name'}, $condition->{'value'});

		}
	    }
	    $request .= ')';

# request construction completed, try to get entities
	    my $res = $self->{'db'}->execute( {'select' => 1, 'cache' => 1},
					      $request,
					      @args );
	    if (exists($res->{'error'})) {

		log_it( 'err',
			$self->{'name'} .
			    '::_get_entities_from_localdb: got DB error %s, filter ignored',
			$res->{'error'} );

		next;

	    }

# no entities for the current filter => no entities should be returned at all
	    unless (scalar(@{$res->{'data'}})) {

		log_it( 'debug',
			$self->{'name'} .
			    '::_get_entities_from_localdb: no entities for filter, skip remaining filters' );

		return [];

	    }

	    my $new_results = {};
	    foreach (@{$res->{'data'}}) {

		$new_results->{$_->{'entity'}} = 1;

	    }

# calculate intersection between previously selected entities and the current
# ones
	    unless ($first) {
		foreach my $key (keys(%$new_results)) {
		    unless (exists($results->{$key})) {
			delete($new_results->{$key});
		    }
		}
	    }

	    $results = $new_results;
	    $first &&= 0;

# no entities after intersecion => no entities should be returned at all
	    unless (scalar(keys(%$results))) {

		log_it( 'debug',
			$self->{'name'} .
			    "::_get_entities_from_localdb: no entities after filters' results intersection, skip remaining filters" );

		return [];

	    }

	}

    }
    else {

# filters not specified => get all entities

	my $request = 'select distinct(id) as id from entities where etype = ?';
	my $res = $self->{'db'}->execute( {'select' => 1, 'cache' => 1},
					  $request,
					  $etype );

	if (exists($res->{'error'})) {

	    log_it( 'err',
		    $self->{'name'} .
			"::_get_entities_from_localdb: got DB error %s, can't obtain all entities of type %s",
		    $res->{'error'}, $etype );

	}
	else {

	    log_it( 'debug',
		    $self->{'name'} .
			"::_get_entities_from_localdb: obtained all entities of type %s",
		    $etype );

	    foreach (@{$res->{'data'}}) {
		$results->{$_->{'id'}} = 1;
	    }

	}

    }

# finally return ids of all filtered entities
    my @result = keys(%$results);

    return \@result;
}

# Method: _store_entity_attributes
# Description
#	Method to store attributes of the given entity
# Argument(s)
#	1. (link to hash) entity
# Returns
#	1 on success or 0 on error

sub _store_entity_attributes {
    my $self = shift;
    my $entity = shift;

# check type of data source
    if ($self->{'config'}->{'type'} ne 'localdb') {

	log_it( 'warning',
		$self->{'name'} .
		    "::_store_entity_attributes: unknown backend type %s, can't store attributes!",
		$self->{'config'}->{'type'} );

	return 0;

    }

# data source: local DB

    my $result = 1;

# validate structure of the attributes of the entity (should be anonymous hash,
# see structure of the entity hash)
    unless (ref($entity->{'attributes'}) eq 'HASH') {

	log_it( 'err',
		$self->{'name'} .
		    "::_store_entity_attributes: invalid entity structure. Expected hash of attributes, got %s",
		ref($entity->{'attributes'}) );

	return 0;

    }

    foreach my $attribute (keys(%{$entity->{'attributes'}})) {

# validate structure of all attributes (should be arrays, see structure of the
# entity hash)
	unless (ref($entity->{'attributes'}->{$attribute}) eq 'ARRAY') {

	    log_it( 'err',
		    $self->{'name'} .
			"::_store_entity_attributes: invalid entity structure. Expected array of %s attribute values, got %s",
		    $attribute, ref($entity->{'attributes'}->{$attribute}) );

	    $result &&= 0;

	    next;

	}

# try to store attribute
	foreach my $value (@{$entity->{'attributes'}->{$attribute}}) {

# ...each of attribute's values
	    my $res = $self->{'db'}->execute( {'select' => 0, 'cache' => 1},
					      'insert into attributes (entity, name, val) values (?, ?, ?)',
					      $entity->{'id'}, $attribute, $value );

	    if (exists($res->{'error'})) {

		log_it( 'err',
			$self->{'name'} .
			    "::_store_entity_attributes: can't store attribute %s for entity with id %s: %s",
			$attribute, $entity->{'id'}, $res->{'error'} );

		$result &&= 0;

	    }
	    elsif (!$res->{'data'}) {

		log_it( 'err',
			$self->{'name'} .
			    "::_store_entity_attributes: can't store attribute %s for entity with id %s: something went wrong",
			$attribute, $entity->{'id'} );

		$result &&= 0;

	    }
	    else {

		log_it( 'debug',
			$self->{'name'} .
			    "::_store_entity_attributes: attribute %s for entity with id %s successfully stored",
			$attribute, $entity->{'id'} );

	    }
	}
    }

    return $result;
}

# Method: _delete_entity_attributes
# Description
#	Method to delete all attributes of the given entity
# Argument(s)
#	1. (link to hash) entity
# Returns
#	1 on success or 1 on error

sub _delete_entity_attributes {
    my $self = shift;
    my $entity = shift;

# check type of data source
    if ($self->{'config'}->{'type'} ne 'localdb') {

	log_it( 'warning',
		$self->{'name'} .
		    "::_delete_entity_attributes: unknown backend type %s, can't delete attributes!",
		$self->{'config'}->{'type'} );

	return 0;

    }

# data source: local DB

# try to delete attributes
    my $res = $self->{'db'}->execute( {'select' => 0, 'cache' => 1},
				      'delete from attributes where entity = ?',
				      $entity->{'id'} );

    if (exists($res->{'error'})) {

	log_it( 'err',
		$self->{'name'} .
		    "::_delete_entity_attributes: can't delete attributes for deleted entity with id %s: %s",
		$entity->{'id'}, $res->{'error'} );

	return 0;

    }
    elsif (!$res->{'data'}) {

	log_it( 'err',
		$self->{'name'} .
		    "::_delete_entity_attributes: can't delete attributes for deleted entity with id %s: something went wrong",
		$entity->{'id'} );

	return 0;

    }
    else {

	log_it( 'debug',
		$self->{'name'} .
		    "::_delete_entity_attributes: attributes for deleted entity with id %s successfully deleted",
		$entity->{'id'} );

    }

    return 1;
}

# Method: _check_filter_operation
# Description
#	Method to validate an operation used in filter
# Argument(s)
#	1. (string) operation
# Returns
#	true if operation is valid or false on error

sub _check_filter_operation {
    my $self = shift;
    my $operation = shift;

    return ( ($operation eq '=') ||
	     ($operation eq '<') ||
	     ($operation eq '>') ||
	     ($operation eq '<=') ||
	     ($operation eq '>=') );
}

# Function: _compare_attributes
# Description
#	Compare given attributes of two entities in order to sort them
# Argument(s)
#	1. (link to hash) first entity
#	2. (link to hash) second entity
#	3. (string) attribute name
#	4. (string) sort mode (optional, default: ascendant sort with symbolic
#		    comparsion)
# Returns
#	1 if first entity should stand before second entity, 0 if they are equal,
#	or -1 if second entity should stand before first entity

sub _compare_attributes {
    my $first = shift;
    my $second = shift;
    my $name = shift;
    my $order = shift;

# (in case of multiple values compare only first ones)
    my @attrsa;
    my @attrsb;

# initialize entities' attributes to sort by if they're not defined
    if ( !defined($first->{'attributes'}->{$name}) ) {
	$first->{'attributes'}->{$name} = [];
    }
    if ( !defined($second->{'attributes'}->{$name}) ) {
	$second->{'attributes'}->{$name} = [];
    }

# ascendant sort with symbolic comparsion
    if ($order eq 'asc') {

	@attrsa = sort { $a cmp $b } (@{$first->{'attributes'}->{$name}});
	@attrsb = sort { $a cmp $b } (@{$second->{'attributes'}->{$name}});

	return $attrsa[0] || '' cmp $attrsb[0] || '';

    }
# descendant sort with symbolic comparsion
    elsif ($order eq 'desc') {

	@attrsa = sort { $b cmp $a } (@{$first->{'attributes'}->{$name}});
	@attrsb = sort { $b cmp $a } (@{$second->{'attributes'}->{$name}});

	return $attrsb[0] || '' cmp $attrsa[0] || '';

    }
# ascendant sort with numeric comparsion
    elsif ($order eq 'nasc') {

	@attrsa = sort { $a <=> $b } (@{$first->{'attributes'}->{$name}});
	@attrsb = sort { $a <=> $b } (@{$second->{'attributes'}->{$name}});

	return 0 + ($attrsa[0] || 0) <=> 0 + ($attrsb[0] || 0);

    }
# descendant sort with numeric comparsion
    elsif ($order eq 'ndesc') {

	@attrsa = sort { $b <=> $a } (@{$first->{'attributes'}->{$name}});
	@attrsb = sort { $b <=> $a } (@{$second->{'attributes'}->{$name}});

	return 0 + ($attrsb[0] || 0) <=> 0 + ($attrsa[0] || 0);

    }
    return 0;
}

1;
