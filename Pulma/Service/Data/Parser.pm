=head1 Pulma::Service::Data::Parser

Part of Pulma system

Class for encoding / decoding data into / from JSON format

Can be used, for example for data exchange between data handlers on
different systems (through sockets, etc.)

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

package Pulma::Service::Data::Parser;

use strict;
use warnings;

use JSON::XS;

use Pulma::Service::Log;

=head1 Method: new

=head2 Description

Class constructor

=head2 Argument(s)

=over

=item 1. (link to hash) configuration

=back

Configuration is optional and currently not used

=head2 Returns

=over

=item (object) instance of class

=back

=cut

sub new {
    my $package = shift;
    my $config = shift;

# setup configuration
    my $self = { 'config' => $config };

# setup JSON parser
    $self->{'parser'} = JSON::XS->new();
    $self->{'parser'}->allow_unknown(1);
    $self->{'parser'}->shrink(1);

    return bless($self, $package);
}

=head1 Method: encode

=head2 Description

Method to encode incoming data into JSON format

=head2 Argument(s)

=over

=item 1. (custom) data

=back

=head2 Returns

=over

=item (string) JSON-encoded data I<or> undef on error

=back

=cut

sub encode {
    my $self = shift;
    my $data = shift;

# check data
    return undef unless (defined $data);

# try to encode
    my $string;
    eval {
	$string = $self->{'parser'}->encode($data);
    };
    if ($@) {

	log_it('err', __PACKAGE__ . '::encode: fail to encode: %s', $@);

	$string = undef;

    }
    elsif (ref($string)) {

	log_it( 'err',
		__PACKAGE__ . '::encode: fail to encode: got result as %s',
		ref($string) );

	$string = undef;

    }
    else {

	log_it( 'debug',
		__PACKAGE__ . '::encode: successfully encoded data' );

    }

    return $string;
}

=head1 Method: decode

=head2 Description

Method to decode incoming data from JSON format

=head2 Argument(s)

=over

=item 1. (string) data

=back

=head2 Returns

=over

=item (custom) decoded data as link to array or link to hash I<or> undef on error

=back

=cut

sub decode {
    my $self = shift;
    my $string = shift;

# check incoming data
    return undef unless (defined $string);

# try to decode
    my $data;
    eval {
	$data = $self->{'parser'}->decode($string);
    };
    if ($@) {

	log_it('err', __PACKAGE__ . '::decode: fail to decode: %s', $@);

	$data = undef;

    }
    elsif ((ref($data) ne 'HASH') && (ref($data) ne 'ARRAY')) {

	log_it( 'err',
		__PACKAGE__ . '::decode: fail to decode: got result as %s',
		ref($data) );

	$data = undef;

    }
    else {

	log_it( 'debug',
		__PACKAGE__ . '::decode: successfully decoded data' );

    }

    return $data;
}

1;
