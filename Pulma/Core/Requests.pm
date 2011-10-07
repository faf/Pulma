# Part of Pulma system
# Requests parser class
#
# Copyright (C) 2011 Fedor A. Fetisov <faf@ossg.ru>. All Rights Reserved
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package Pulma::Core::Requests;

use strict;
use warnings;

use CGI::Cookie;
use CGI::Fast qw(:standard);
use Digest::MD5 qw(md5_hex);

# Method: new
# Description: constructor
# Argument(s): 1: config (link to hash)
# Return: object
#
# Config hash structure: see docs for cbc.conf format
sub new {
    my $package = shift;
    my $config = shift;

    my $self = {};

# store configuration
    $self->{'config'} = $config;

    return bless($self, $package);
}

sub request {
    my $self = shift;
    my $requestid = shift;

    my $token = md5_hex(time . $requestid);

# deconstruct path
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
		    'urlbase' => url(-base => 1),
		    'url' => url(-absolute => 1, -path => 1),
		    'fullurl' => url(-absolute => 1, -query => 1, -path => 1),
		    'query' => query_string()
    };

    return $request;
}

############# Service methods ###########################

# Method: _get_path
# Description: extract all path nodes from the incoming request
# Argument(s): 1: requested uri (string)
# Return: link to array with path nodes
sub _get_path {
    my $self = shift;
    my $url = shift;
    my $root = $self->{'config'}->{'root'};
    $url =~ s/^$root//;
    $url =~ s/\/{2,}/\//g;
    $url =~ s~^/~~;
    return $url;
}

# Method: _get_params
# Description: extract all parameters from the incoming request
# Argument(s): none
# Return: link to hash with parameters
#
# Resulting hash structure:
# {
# <parameter name> => [<value1>, ...]
# }
sub _get_params {
    my $self = shift;
    my $res = {};

# fetch all url parameters (i.e. parameters in URI when method is POST)
    my @params = url_param();
    foreach my $param (@params) {

# ignore special parameters
	next if ($param eq 'username');
	next if ($param eq 'password');

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
# when URI is something like <path>?<param1>[+<param2>+...] CGI fetch it as <path>?keywords=param1[+param2+...] - see documentation on CGI module
	    map { $res->{$_} = [1] } split(/\+/, param($param));
	}
	else {
	    my @temp = param($param);
	    $res->{$param} = \@temp;
	}
    }

    return $res;
}

1;
