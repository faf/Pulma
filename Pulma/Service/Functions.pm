# Part of Pulma system
# Module providing miscellanous service functions
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

package Pulma::Service::Functions;

use strict;
use warnings;

require Exporter;

our @ISA = ('Exporter');
our @EXPORT = qw(&check_email &check_number &check_sum &check_uri &check_date &generate_rnd_string
		 &calculate_password_hash &calculate_password_strength &check_login
		 &check_color &pager &uri_escape &uri_unescape &uri_escape_utf8
		 &truncate_string &generate_entity_id &escape);

use CGI::Fast qw(:standard);
use Digest::MD5 qw(md5_hex);
use Digest::SHA1 qw(sha1_hex);
use Email::Valid;
use Encode qw(_utf8_on _utf8_off);
use Regexp::Common qw(URI);
use URI::Escape;

# Function: check_email
# Description: check email address using Email::Valid module
# Argument(s): 1: email address (string)
# Return: link to hash with result. hash structure: { 'result' => <result>[, 'error' => <error description>] }
#	  where result is 1 if email is valid, or 0 - otherwise
sub check_email {
    my $email = shift;
    my $temp;
    my $result = {};

    eval {
	$temp = Email::Valid->address(	-address => $email );
    };
    if ($@) {
	$result = { 'result' => 0, 'error' => $@ };
    }
    elsif (!$temp) {
	$result = { 'result' => 0, 'error' => $Email::Valid::Details };
    }
    else {
	$result = { 'result' => 1 }
    }

    return $result;
}

# Function: check_number
# Description: check incoming value to be a valid number
# Argument(s): 1: incoming value (string)
# Return: 1 if number is valid, 0 - otherwise
sub check_number {
    my $string = shift;

    return 0 unless defined $string;
    return ($string =~ /^[0-9]+$/) ? 1 : 0;
}

# Function: check_sum
# Description: check incoming value to be a valid money amount
# Argument(s): 1: incoming value (string)
# Return: 1 if money amount is valid, 0 - otherwise
sub check_sum {
    my $string = shift;

    return 0 unless defined $string;
    return 0 if (($string eq '') || ($string eq '.'));
    $string = '0' . $string;
    return ($string =~ /^[0-9]+(\.[0-9]{0,2})?$/) ? 1 : 0;
}

# Function: check_date
# Description: check incoming value to be a valid date in format of YYYY-MM-DD
# Argument(s): 1: incoming value (string)
# Return: 1 if date is valid, 0 - otherwise
sub check_date {
    my $string = shift;

    return 0 unless defined $string;

    return 0 unless ($string =~ /^(\d{4})-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$/);

# we started in 2011, while 2039 seems considerably far in future
    return 0 if ($1 < 2011) || ($1 > 2039);

    my $months = [0,31,28,31,30,31,30,31,31,30,31,30,31];

# check day against value of days in month (except february)
    return ($months->[$2] >= $3) ? 1 : 0 if ($2 != 2);

# february in non-leap years
    return ($months->[$2] >= $3) ? 1 : 0 if (($1 % 4 != 0) || ($1 % 100 == 0) && ($1 % 400 != 0));

# february in leap years
    return ($3 >= 29) ? 1 : 0;
}

# Function: check_uri
# Description: check incoming value to be a valid HTTP URI
# Argument(s): 1: incoming value (string)
# Return: 1 if URI is valid, 0 - otherwise
sub check_uri {
    my $string = shift;
    $string =~ s/^https/http/;
    return $string =~ /$RE{URI}{HTTP}/ ? 1 : 0;
}



sub generate_entity_id {
    my $type = shift;
    my $time = time;
    my $salt = generate_rnd_string(7);
    return md5_hex($type . $time . $salt);
}

# Function: generate_rnd_string
# Description: generate random string with given length consists of alphanumeric symbols
# Argument(s): 1: string length (number) (default: 16)
# Return: random string
sub generate_rnd_string {
    my $length = shift;
# check incoming value
    $length = check_number($length) && ($length > 0) ? $length : 16;

    my $str = '';
    for(my $i=0; $i<$length; $i++) {
        my $rand = int(rand(62));

        if ($rand>35) { $rand += 61; }
        elsif ($rand>9) { $rand += 55; }
        else { $rand += 48; }
        $str .= chr($rand);
    }

    return $str;
}

# Function calculate_password_hash
# Description: generate password hash based upon values of username and password
# Argument(s): 1: username (string), 2: password in plain text (string)
# Return: password hash (string)
sub calculate_password_hash {
    my $username = shift;
    my $password = shift;

    return sha1_hex($username . "aihaixoo6eej9iXe" . $password);
}

# Function calculate_password_strength
# Description: calculate password strength based upon it's value
# Argument(s): 1: password in plain text (string)
# Return: password strength (integer) - the higher is better
#	  everything below the value of 5 should be considered as weak
#	  everything below or equal to the value of 8 should be considered as moderate
#	  everything higher than the value of 8 should be considered as strong
sub calculate_password_strength {
    my $password = shift;

    return 0 unless defined $password;

    _utf8_on($password);
    my $length = length($password);

# length check (password should contain at least 8 symbols)
    if ($length < 8) { return 0; }

# check for a bad characters
    if ($password =~ /[\0-\x1F\x7F]/) { return -1; }

# calculate password's "weight"
    my $classes = {};
    my $weight = 0;
    foreach (split(//, $password)) {
# add the 'weight' of the current symbols to the common summary
        if (/[A-Z]/) {
	    $weight += 0.5;
	    $classes->{'cap'} ||= 1;
	}
        elsif (/[a-z]/) {
	    $weight += 0.4;
	    $classes->{'let'} ||= 1;
	}
        elsif (/[0-9\-\+ ]/) {
	    $weight += 0.3;
	    $classes->{'dig'} ||= 1;
	}
        else {
	    $weight += 0.7;
	    $classes->{'oth'} ||= 1;
	}
    }
    $weight = $weight*(1+(scalar(keys(%{$classes}))-1)/3);
    return $weight;
}

# Function check_login
# Description: validate login (correct login could contain only latin letters and digits)
#	       and should be at least 3 symbols long and no more than 15 symbols long
# Argument(s): 1: login (string)
# Return: 1 if validation passed, 0 - otherwise
sub check_login {
    my $login = shift;
    return 0 unless defined $login;
    return ($login =~ /^[A-Za-z0-9]{3,15}$/) ? 1 : 0;
}

# Function check_color
# Description: validate value to be a correct color in RGB format (i.e. #xxxxxx)
# Argument(s): 1: value (string)
# Return: 1 if validation passed, 0 - otherwise
sub check_color {
    my $value = shift;
    return 0 unless defined $value;
    return ($value =~ /^\#[A-Fa-f0-9]{6}$/) ? 1 : 0;
}

# Function: pager
# Description: building a navigation structure based upon incoming data structure
# Argument(s): 1: data structure (link to hash)
# Return: navigation structure (link to hash)
# NOTE:
# data structure format: { 'limit' => <number of items per page>, 'count' => <overall number of items>, 'page' => <current page> }
# navigation structure format: { 'pages_count' => <number of pages>,
#				 'limit => <number of items per page>,
#				 'page' => <current page>,
#				 'items' => <number of items>,
#				 'beg' => <page number to begin pager from>,
#				 'end' => <page number to end pager at>
#				}
sub pager {
    my $data = shift;

    my $pager = {
	'pages_count' => int($data->{'count'} / $data->{'limit'}) + ($data->{'count'} % $data->{'limit'} ? 1 : 0),
	'limit' => $data->{'limit'},
	'page' => $data->{'page'},
	'items' => $data->{'count'}
    };

    if ($pager->{'pages_count'} > 9) {
	$pager->{'beg'} = ($pager->{'page'} < 4) ? 0 : ($pager->{'page'}  - 4);
	$pager->{'end'} = (($pager->{'pages_count'} - $pager->{'page'}) > 5) ? ($pager->{'page'} + 4) : ($pager->{'pages_count'} - 1);
	if (($pager->{'end'} - $pager->{'beg'})<8) {
	    if ($pager->{'end'} == ($pager->{'pages_count'} - 1)) { $pager->{'beg'} = $pager->{'end'} - 8; }
	    else { $pager->{'end'} = $pager->{'beg'} + 8; }
	}
    } else {
	$pager->{'beg'} = 0;
	$pager->{'end'} = $pager->{'pages_count'} - 1;
    }

    return $pager;
}

# Function truncate_string
# Description: truncate string to a given limit
# Argument(s): 1: value (string)[, 2: limit (integer, default: 10)]
# Return: truncated string
sub truncate_string {
    my $string = shift;
    my $limit = shift;
    $limit ||= 10;

    return undef unless defined $string;

    _utf8_on($string);
    if (length($string) > $limit) {
	$string = substr($string, 0, $limit) . '...';
    }
    _utf8_off($string);

    return $string;
}

sub escape {
    return escapeHTML(@_);
}

1;
