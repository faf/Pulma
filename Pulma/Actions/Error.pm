=head1 Pulma::Actions::Error

Part of Pulma system

Default class for handling of HTTP errors

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

package Pulma::Actions::Error;

use strict;
use warnings;

use Pulma::Actions::Prototype;
our @ISA = ('Pulma::Actions::Prototype');

=head1 Method: new

=head2 Description

Class constructor

=head2 Argument(s)

=over

=item see Pulma::Actions::Prototype class

=back

=head2 Results

=over

=item see Pulma::Actions::Prototype class

=back

=cut

sub new {
    my $package = shift;

    my $self = $package->SUPER::new(@_);

    $self->{'name'} = __PACKAGE__;

# set some predefined errors
    $self->{'errors'} = {
	'404' => {
	    'title' => 'Not found',
	    'text' => 'Requested resource not found'
	},
	'403' => {
	    'title' => 'Forbidden',
	    'text' => 'You are not allowed to access requested resource'
	},
	'default' => {
	    'title' => 'Internal server error',
	    'text' => 'Internal server error occured. Please visit our site later'
	}
    };

    return $self;
}

=head1 Method: action

=head2 Description

Main action method for data handler

=head3 Specifics

=over

=item Set standard error page template

=item Set title and error code (in data->pulma->error hash)

=item Log error event via logger object

=item Set appropriate HTTP error status

=back

=head2 Argument(s)

=over

=item 1. (link to hash) incoming data

=back

=head2 Returns

=over

=item (link to hash) outgoing data

=back

=cut

sub action {
    my $self = shift;
    my $data = shift;
    my $specs = shift;

    my $error = $self->{'errors'}->{'default'};
    if ( exists($specs->{'code'}) &&
	 exists($self->{'errors'}->{$specs->{'code'}}) ) {

	$data->{'result'}->{'status'} = $specs->{'code'};
	$data->{'pulma'}->{'data'}->{'error'}->{'title'} = $self->{'errors'}->{$specs->{'code'}}->{'title'};
	$data->{'pulma'}->{'data'}->{'error'}->{'text'} = $self->{'errors'}->{$specs->{'code'}}->{'text'};
	$data->{'pulma'}->{'data'}->{'error'}->{'code'} = $specs->{'code'};

    }

    $data->{'result'}->{'template'} = 'error.tpl';

    $self->{'logger'}->create_entity({

	'etype' => 'http_error',

	'attributes' => {

	    'time'	=> [ time ],
	    'aentity'	=> [ exists($data->{'pulma'}->{'auth'}->{'user'}->{'id'}) ? $data->{'pulma'}->{'auth'}->{'user'}->{'id'} : 0 ],
	    'dentity'	=> [ 0 ],
	    'code'	=> [ $data->{'result'}->{'status'} ],
	    'url'	=> [ $data->{'request'}->{'url'} ],
	    'fullurl'	=> [ $data->{'request'}->{'fullurl'} ],
	    'method'	=> [ $data->{'request'}->{'method'} ],
	    'remoteip'	=> [ $data->{'request'}->{'remoteip'} ],
	    'useragent'	=> [ $data->{'request'}->{'useragent'} ]

	}

    });

    return $data;
}

1;
