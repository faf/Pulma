=head1 Pulma::Dummy

Part of Pulma system

Class for dummy operations with source of data: act as real but empty
data source

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

package Pulma::Dummy;

use strict;
use warnings;

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

=item (object) instance of class

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

    return bless($self, $package);
}

=head1 Method: get_entity_by_id

=head2 Description

Method to emulate search of entity by it's identifier

=head2 Argument(s)

=over

=item 1. (string) entity identifier

=item 2. (string) entity type

=back

=head2 Returns

=over

=item undef

=back

=cut

sub get_entity_by_id {
    my $self = shift;
    return undef;
}

=head1 Method: get_entities_count

=head2 Description

Method to emulate the process of getting count of entities of a given type and
(maybe) filtered/sorted by some criteria

=head2 Argument(s)

=over

=item 1. (link to array) filters to choose entities

=item 2. (string) entities' type

=back

=head2 Returns

=over

=item 0

=back

=cut

sub get_entities_count {
    my $self = shift;
    return 0;
}

=head1 Method: get_entities

=head2 Description

Method to emulate the process of getting entities of a given type and (maybe)
filtered by some criteria

=head2 Argument(s)

=over

=item 1. (link to array) filters to choose entities

=item 2. (string) entities' type

=item 3. (integer) entities limit (optional, default: no limits)

=item 4. (integer) offset (optional, default: no offset)

=back

=head2 Returns

=over

=item (array) empty array

=back

=cut

sub get_entities {
    my $self = shift;
    return [];
}

=head1 Method: sort_entities

=head2 Description

Method to "sort" entities by a given criteria

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

=item (link to array) incoming entities without any sorting

=back

=cut

sub sort_entities {
    my $self = shift;
    my $entities = shift;

    unless (ref($entities) eq 'ARRAY') {

	log_it( 'err',
		$self->{'name'} .
		    '::sort_entities: invalid data supplied. Expected array, got %s. Nothing to sort',
		ref($entities) );

    }

    return $entities;
}

=head1 Method: create_entity

=head2 Description

Method to emulate the process of new entity creation

=head2 Argument(s)

=over

=item 1. (link to hash) entity

=back

=head2 Results

=over

=item 0

=back

=cut

sub create_entity {
    my $self = shift;
    return 0;
}

=head1 Method: update_entity

=head2 Description

Method to emulate the process of update attributes of an existed entity

=head2 Argument(s)

=over

=item 1. (link to hash) entity

=back

=head2 Results

=over

=item 0

=back

=cut

sub update_entity {
    my $self = shift;
    return 0;
}

=head1 Method: delete_entity

=head2 Description

Method to emulate the process of existed entity deletion

=head2 Argument(s)

=over

=item 1. (link to hash) entity

=back

=head2 Results

=over

=item 0

=back

=cut

sub delete_entity {
    my $self = shift;
    return 0;
}

=head1 Method: delete_entities

=head2 Description

Method to emulate the process of deletion of existed entities

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
    'deleted'	=> 0,

    'failed'	=> 0

}

=cut

sub delete_entities {
    my $self = shift;
    return { 'deleted' => 0, 'failed' => 0 };
}

1;
