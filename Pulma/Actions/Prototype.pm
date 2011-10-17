=head1 Pulma::Actions::Prototype

Part of Pulma system

Prototype class for standard data handler

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

package Pulma::Actions::Prototype;

use strict;
use warnings;

use Pulma::Auth;
use Pulma::Data;
use Pulma::Logger;

use Pulma::Service::Data::Parser;
use Pulma::Service::Functions;
use Pulma::Service::Log;

=head1 Method: new

=head2 Description

Class constructor

=head2 Argument(s)

=over

=item 1. (link to hash) config (later accessible as $object->{config})

=item 2. (link to link to hash) cache

=item 2. (link to object) standard output generator (later accessible as
$object->{output})

=back

=head2 Results

=over

=item (object) instance of class I<or> undef on initialization error

=back

=head2 Config hash structure

{

    'logger' => { <logger object configuration> },

    'data' => { <data object configuration> },

    'auth' => { <auth object configuration> }

}

All configuration keys are optional

=cut

sub new {
    my $package = shift;
    my $config = shift;
    my $cache = shift;
    $cache = $$cache;
    my $output = shift;
    $output = $$output;

# store configuration
    my $self = {
	'config' => $config,
	'output' => $output,
	'name' => __PACKAGE__
    };

    if (exists($config->{'logger'})) {

# initialize logger object (if need to)

	log_it('debug',  $self->{'name'} . '::new: initializing logger object');

	$self->{'logger'} = Pulma::Logger->new($config->{'logger'}, \$cache);
	unless (defined $self->{'logger'}) {

	    log_it( 'err',
		    $self->{'name'} . "::new: can't initialize logger object!" );

	    return undef;

	}

    }

    if (exists($config->{'data'})) {

# initialize data object (if need to)

	log_it('debug',  $self->{'name'} . '::new: initializing data object');

	$self->{'data'} = Pulma::Data->new($config->{'data'}, \$cache);
	unless (defined $self->{'data'}) {

	    log_it( 'err',
		    $self->{'name'} . "::new: can't initialize data object!" );

	    return undef;

	}

    }

    if (exists($config->{'auth'})) {

# initialize auth object (if need to)

	log_it('debug',  $self->{'name'} . '::new: initializing auth object');

	$self->{'auth'} = Pulma::Auth->new($config->{'auth'}, \$cache);
	unless (defined $self->{'auth'}) {

	    log_it( 'err',
		    $self->{'name'} . "::new: can't initialize auth object!" );

	    return undef;

	}

    }

# initialize parser object for data encoding / decoding
    log_it('debug', $self->{'name'} . '::new: initializing parser object');

    $self->{'parser'} = Pulma::Service::Data::Parser->new({});

    return bless($self, $package);
}

=head1 Method: action

=head2 Description

Main action method for data handler

=head3 Details

Do nothing - just prototype

=head2 Argument(s)

=over

=item 1. (link to hash) incoming data

=item 2. (custom) action specifics

=back

=head2 Results

=over

=item (link to hash) outgoing data

=back

=cut

sub action {
    my $self = shift;
    my $data = shift;
    my $specs = shift;

    log_it('debug', $self->{'name'} . '::action: invoked');

    return $data;
}

1;
