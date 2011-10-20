=head1 Pulma::Core::Requests

Part of Pulma system

Class for parsing incoming requests

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

package Pulma::Core::Requests;

use strict;
use warnings;

use CGI::Cookie;
use CGI::Fast qw(:standard);
use Digest::MD5 qw(md5_hex);
use Encode qw(decode_utf8);

=head1 Method: new

=head2 Description

Class constructor

=head2 Argument(s)

=over

=item 1. (link to hash) configuration

=back

=head2 Returns

=over

=item (object) instance of class

=back

=head2 Configuration hash structure

{

    'root' => <URI of the system's root> (as set in pulma configuration,
					  map->root parameter)

}

=cut

sub new {
    my $package = shift;
    my $config = shift;

    my $self = { 'name' => __PACKAGE__ };

# store configuration
    $self->{'config'} = $config;

    return bless($self, $package);
}

=head1 Method: request

=head2 Description

Method to get all incoming request's parameters

=head2 Argument(s)

=over

=item 1. (string) request id

=back

=head2 Returns

=over

=item (link to hash) request

=back

=head2 Structure of request hash

{

    'requestid' => <request id>,

    'token' => <unique request token>,

    'path' => <real requested path> (to be used by mapper object),

    'params' => <link to hash with parameters>,

    'cookies' => <link to hash with cookies>,

    'method' => <request method>,

    'remoteip' => <remote ip address>,

    'useragent' => <remote user agent>,

    'urlbase' => <base url of the requested url>,

    'url' => <url in short form, without query string>,

    'fullurl' => <url in full form, with query string>,

    'query' => <query string>

}

=head2 Structure of hash with request parameters

{ <first parameter name> => [ <value1>, ... ], ... }

=head2 Structure of hash with cookie parameters

{ <first cookie name> => [ <value1> ], ... }

=cut

sub request {
    my $self = shift;
    my $requestid = shift;

    my $token = md5_hex(time . $requestid);

# remove garbage from requested path
    my $path = $self->_get_path(script_name());

# deconstruct incoming request parameters
    my $params = $self->_get_params();

# fetch incoming cookies
    my $cookies = CGI::Cookie->fetch();
    foreach my $cookie (keys(%$cookies)) {
	$cookies->{$cookie} = [$cookies->{$cookie}->value()];
    }

# prepare request data structure
    my $request = { 'requestid' => $requestid,
		    'token' => $token,
		    'path' => $path,
		    'params' => $params,
		    'cookies' => $cookies,
		    'method' => request_method(),
		    'remoteip' => remote_addr(),
		    'useragent' => user_agent(),
		    'urlbase' => url(-base => 1),
		    'url' => url(-absolute => 1, -path => 1),
		    'fullurl' => url(-absolute => 1, -query => 1, -path => 1),
		    'query' => query_string()
    };

    return $request;
}

############################## Private methods ##################################

# Method: _get_path
# Description
#	Method to remove all useless nodes (double slashes, root path, etc.)
#	from requested path (URL)
#	the incoming request
# Argument(s)
#	1: (string) requested uri
# Returns
#	(string) path nodes

sub _get_path {
    my $self = shift;
    my $url = shift;
    my $root = $self->{'config'}->{'root'};
# remove root path
    $url =~ s/^$root//;
# remove double slashes
    $url =~ s/\/{2,}/\//g;
# remove first slash
    $url =~ s~^/~~;
    return $url;
}

# Method: _get_params
# Description
#	extract all parameters from the incoming request
# Argument(s)
#	none
# Returns
#	(link to hash) with parameters
#
# Resulting hash structure
#
# {
#	<parameter name> => [<value1>, ...]
# }

sub _get_params {
    my $self = shift;
    my $res = {};

# fetch all url parameters (i.e. parameters in URI when method is POST)
    my @params = url_param();
    foreach my $param (@params) {

	if ($param eq 'keywords') {
	    map { $res->{$_} = [1] } split(/\;/, url_param($param));
	}
	else {
	    my @temp = url_param($param);
	    $res->{$param} = \@temp;
	}
    }

# fetch all parameters passed through GET or POST methods
    @params = param();
    foreach my $param (@params) {
	if ($param eq 'keywords') {
# when URI is something like <path>?<param1>[+<param2>+...] CGI fetch it as
# <path>?keywords=param1[+param2+...] - see documentation on CGI module
	    map { $res->{$_} = [1] } split(/\+/, param($param));
	}
	else {
	    my @temp = param($param);
	    $res->{$param} = \@temp;
	}
    }

# utf-decode
    foreach my $param (keys %$res) {
	foreach (@{$res->{$param}}) {
	    $_ = decode_utf8( $_ ) if (ref($_) ne 'Fh');
	}
    }

    return $res;
}

1;
