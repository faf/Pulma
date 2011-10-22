=head1 Pulma::Service::Functions

Part of Pulma system

Module providing miscellanous service functions

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

package Pulma::Service::Functions;

use strict;
use warnings;

require Exporter;

our @ISA = ('Exporter');
our @EXPORT = qw( &calculate_password_hash &calculate_password_strength
		  &check_color &check_date &check_email &check_login
		  &check_number &check_sum &check_uri &escape &generate_entity_id
		  &generate_rnd_string &make_http_date &pager &truncate_string
		  &uri_escape &uri_escape_utf8 &uri_unescape );

use CGI::Fast qw(:standard);
use Digest::MD5 qw(md5_hex);
use Digest::SHA1 qw(sha1_hex);
use Email::Valid;
use Encode qw(_utf8_on _utf8_off);
use HTTP::Date;
use Regexp::Common qw(URI);
use URI::Escape;

=head1 Function: calculate_password_hash

=head2 Description

Function to generate hash-encrypted password based upon values of username and
password

=head2 Argument(s)

=over

=item 1. (string) username

=item 2. (string) password in plain text

=back

=head2 Returns

=over

=item (string) encrypted password

=back

=cut

sub calculate_password_hash {
    my $username = shift;
    my $password = shift;

    return sha1_hex($username . $password);
}

=head1 Function: calculate_password_strength

=head2 Description

Function to calculate password strength based upon it's value

=head2 Argument(s)

=over

=item 1. (string) password in plain text

=back

=head2 Returns

=over

=item (integer) password strength

=back

=head2 Strength level

Whole idea - the higher the better

=over

=item everything below the value of 5 should be considered as weak

=item everything below or equal to the value of 8 should be considered as
moderate

=item everything higher than the value of 8 should be considered as strong

=back

=cut

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

=head1 Function: check_color

=head2 Description

Function to check value to be a correct color in RGB format (i.e. #xxxxxx)

=head2 Argument(s)

=over

=item 1. (string) value to check

=back

=head2 Returns

=over

=item 1 if validation passed I<or> 0 - otherwise

=back

=cut

sub check_color {
    my $value = shift;
    return 0 unless defined $value;
    return ($value =~ /^\#[A-Fa-f0-9]{6}$/) ? 1 : 0;
}

=head1 Function: check_date

=head2 Description

Function to check incoming value to be a valid date in format of YYYY-MM-DD

=head2 Argument(s)

=over

=item 1. (string) value to check

=back

=head2 Returns

=over

=item 1 if validation passed I<or> 0 - otherwise

=back

=cut

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


=head1 Function: check_email

=head2 Description

Function to check value to be a valid email address (using Email::Valid module)

=head2 Argument(s)

=over

=item 1. (string) value to check

=back

=head2 Returns

=over

=item (link to hash) check result

=back

=head2 Structure of check result hash

{

    'result' => <result>,

    'error' => <error message>

}

Where result is 1 if email is valid I<or> 0 - otherwise. Error message is set
only if result is 0.

=cut

sub check_email {
    my $email = shift;
    my $temp;
    my $result = {};

    eval {
	$temp = Email::Valid->address( -address => $email );
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

=head1 Function: check_login

=head2 Description

Function to validate login (correct login could contain only latin letters and
digits) and should be at least 3 symbols long and no more than 15 symbols long

=head2 Argument(s)

=over

=item 1. (string) value to check

=back

=head2 Returns

=over

=item 1 if validation passed I<or> 0 - otherwise

=back

=cut

sub check_login {
    my $login = shift;
    return 0 unless defined $login;
    return ($login =~ /^[A-Za-z0-9]{3,15}$/) ? 1 : 0;
}

=head1 Function: check_number

=head2 Description

Function to check incoming value to be a valid number

=head2 Argument(s)

=over

=item 1. (string) value to check

=back

=head2 Returns

=over

=item 1 if validation passed I<or> 0 - otherwise

=back

=cut

sub check_number {
    my $string = shift;
    return 0 unless defined $string;
    return ($string =~ /^[0-9]+$/) ? 1 : 0;
}

=head1 Function: check_sum

=head2 Description

Function to check incoming value to be a valid money amount

=head2 Argument(s)

=over

=item 1. (string) value to check

=back

=head2 Returns

=over

=item 1 if validation passed I<or> 0 - otherwise

=back

=cut

sub check_sum {
    my $string = shift;
    return 0 unless defined $string;
    return 0 if (($string eq '') || ($string eq '.'));
    $string = '0' . $string;
    return ($string =~ /^[0-9]+(\.[0-9]{0,2})?$/) ? 1 : 0;
}

=head1 Function: check_uri

=head2 Description

Function to check incoming value to be a valid HTTP URI (using Regexp::Common
module)

=head2 Argument(s)

=over

=item 1. (string) value to check

=back

=head2 Returns

=over

=item 1 if validation passed I<or> 0 - otherwise

=back

=cut

sub check_uri {
    my $string = shift;
    $string =~ s/^https/http/;
    return $string =~ /$RE{URI}{HTTP}/ ? 1 : 0;
}


=head1 Function: escape

=head2 Description

see function B<escapeHTML> in CGI module

=head2 Argument(s)

=over

=item see function B<escapeHTML> in CGI module

=back

=head2 Returns

=over

=item see function B<escapeHTML> in CGI module

=back

=cut

sub escape {
    return escapeHTML(@_) || '';
}

=head1 Function: generate_entity_id

=head2 Description

Function to generate entity id based upon entity type, actual time and some
random value

=head2 Argument(s)

=over

=item 1. (string) entity type

=item 2. (string) salt (optional, by default there will be generated random
string with length of 8 symbols)

=back

=head2 Returns

=over

=item (string) entity id

=back

=cut

sub generate_entity_id {
    my $type = shift;
    my $time = time;
    my $salt = shift || generate_rnd_string(7);
    $salt .= generate_rnd_string(7);
    return md5_hex($type . $time . $salt);
}

=head1 Function: generate_rnd_string

=head2 Description

Function to generate random string with given length consists of latin
alphanumeric symbols

=head2 Argument(s)

=over

=item 1. (integer) string length (optional, default value: 16)

=back

=head2 Returns

=over

=item (string) random string

=back

=cut

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

=head1 Function: make_http_date

=head2 Description

Function to provide valid date in HTTP format (see rfc1123)

=head2 Argument(s)

=over

=item 1. (integer) epoch time in seconds (optional, default: current time)

=back

=head2 Returns

=over

=item (string) date in HTTP format

=back

=cut

sub make_http_date {
    my $time = shift;

    return $time ? time2str($time) : time2str();
}

=head1 Function: pager

=head2 Description

Function to build a navigation structure for pager based upon incoming data
structure

=head2 Argument(s)

=over

=item 1. (link to hash) incoming data

=back

=head2 Returns

=over

=item (link to hash) navigation structure

=back

=head2 Incoming data structure

{

    'limit' => <number of items per page>,

    'count' => <overall number of items>,

    'page' => <current page>,

    ['links' => <number of links to pages> (optional, default: 10)]

}

=head2 Navigation structure

{

    'pages_count' => <number of pages>,

    'limit => <number of items per page>,

    'page' => <current page>,

    'items' => <number of items>,

    'beg' => <page number to begin pager from>,

    'end' => <page number to end pager at>

}

=cut

sub pager {
    my $data = shift;

    my $pager = {
	'pages_count' => int($data->{'count'} / $data->{'limit'}) +
			($data->{'count'} % $data->{'limit'} ? 1 : 0),
	'limit' => $data->{'limit'},
	'page' => $data->{'page'},
	'items' => $data->{'count'}
    };

# check page value, set to 0 if greater than it could be
    $pager->{'page'} = ($pager->{'page'} < $pager->{'pages_count'}) ?
			$pager->{'page'} :
			0;

    my $links = $data->{'links'} || 10;

    my $links_left = int($links / 2) - 1 + 1 * ($links % 2);
    my $links_right = int($links / 2);

    if ($pager->{'pages_count'} > ($links - 1)) {

	$pager->{'beg'} = ($pager->{'page'} < $links_left) ?
			  0 :
			  ($pager->{'page'} - $links_left);

	$pager->{'end'} = (($pager->{'pages_count'} - $pager->{'page'}) > $links_right) ?
			    ($pager->{'page'} + $links_right) :
			    ($pager->{'pages_count'} - 1);

	if (($pager->{'end'} - $pager->{'beg'}) < $links) {

	    if ($pager->{'end'} == ($pager->{'pages_count'} - 1)) {

		    $pager->{'beg'} = $pager->{'end'} - $links + 1;

	    }
	    else {

		    $pager->{'end'} = $pager->{'beg'} + $links - 1;

	    }
	}

    }
    else {

	$pager->{'beg'} = 0;
	$pager->{'end'} = $pager->{'pages_count'} - 1;

    }

    return $pager;
}

=head1 Function: truncate_string

=head2 Description

Function to (Unicode-friendly) truncate string to a given length

=head2 Argument(s)

=over

=item 1. (string) string to truncate

=item 2. (integer) truncation length (optional, default value: 10)

=back

=head2 Returns

=over

=item (string) truncated string

=back

=cut

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

=head1 Function: uri_escape

=head2 Description

see URI::Escape module for details

=head2 Argument(s)

=over

=item see URI::Escape module for details

=back

=head2 Returns

=over

=item see URI::Escape module for details

=back

=cut

=head1 Function: uri_escape_utf8

=head2 Description

see URI::Escape module for details

=head2 Argument(s)

=over

=item see URI::Escape module for details

=back

=head2 Returns

=over

=item see URI::Escape module for details

=back

=cut

=head1 Function: uri_unescape

=head2 Description

see URI::Escape module for details

=head2 Argument(s)

=over

=item see URI::Escape module for details

=back

=head2 Returns

=over

=item see URI::Escape module for details

=back

=cut

1;
