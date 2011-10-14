=head1 Pulma::Cacher::Data

Part of Pulma system

Class for using standard memory caching mechanism of Pulma system

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

package Pulma::Cacher::Data;

use strict;
use warnings;

use Clone qw( clone );

use Pulma::Service::Log;

=head1 Method: new

=head2 Description

Class constructor

=head2 Argument(s)

=over

=item 1. (link to link to hash) standard memory cache

=item 2. (string) cache part to store data to (hash key, optional, default
key: 'common')

=back

=head2 Returns

=over

=item (object) instance of class

=back

=cut

sub new {
    my $package = shift;
    my $cache = shift;
    $cache = $$cache;
    my $key = shift || 'common';

    my $self = {
	'cache' => \$cache,
	'key' => $key,
	'name' => __PACKAGE__
    };

    return bless($self, $package);
}

=head1 Method: set_key

=head2 Description

Method to set cache part to use

=head2 Argument(s)

=over

=item 1. (string) cache part to store data to

=back

=head2 Returns

=over

=item 1 on success I<or> 0 on error

=back

=cut

sub set_key {
    my $self = shift;
    my $key = shift;

# check key value
    return 0 unless defined $key;

    $self->{'key'} = $key;

    return 1;
}

=head1 Method: get

=head2 Description

Method to get entity from cache

=head2 Argument(s)

=over

=item 1. (string) entity id

=item 2. (integer) last modification timestamp

=back

=head2 Returns

=over

=item (link to hash) entity I<or> undef if (actual) entity was not found in cache

=back

=cut

sub get {
    my $self = shift;
    my $id = shift;
    my $time = shift;

# look for entity with given id in cache
    if (exists(${$self->{'cache'}}->{$self->{'key'}}->{$id})) {
# check last modification time
	if (${$self->{'cache'}}->{$self->{'key'}}->{$id}->{'modtime'} < $time) {
# entity in cache obsolete - remove it from cache
	    $self->del($id);
	    return undef;
	}
	else {
# actual entity found in cache
	    return clone( ${$self->{'cache'}}->{$self->{'key'}}->{$id} );
	}
    }
    else {
	return undef;
    }
}

=head1 Method: put

=head2 Description

Method to put entity into cache

=head2 Argument(s)

=over

=item 1. (string) entity id

=item 2. (link to hash) entity

=back

=head2 Returns

=over

=item 1 in all cases

=back

=cut

sub put {
    my $self = shift;
    my $id = shift;
    my $data = shift;

    ${$self->{'cache'}}->{$self->{'key'}}->{$id} = clone($data);

    return 1;
}

=head1 Method: del

=head2 Description

Method to remove entity from cache

=head2 Argument(s)

=over

=item 1. (string) entity id

=back

=head2 Returns

=over

=item 1 in all cases

=back

=cut

sub del {
    my $self = shift;
    my $id = shift;

    delete ${$self->{'cache'}}->{$self->{'key'}}->{$id};

    return 1;
}

1;
