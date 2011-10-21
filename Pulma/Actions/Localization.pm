=head1 Pulma::Actions::Localization

Part of Pulma system

Default class for localization

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

package Pulma::Actions::Localization;

use strict;
use warnings;

use Pulma::Service::Constants;
use Pulma::Service::Log;

use Pulma::Actions::Prototype;
our @ISA = ('Pulma::Actions::Prototype');

=head1 Method: new

=head2 Description

Class constructor

=head2 Argument(s)

=over

=item see Pulma::Actions::Prototype class

=back

=head2 Returns

=over

=item see Pulma::Actions::Prototype class

=back

=cut

sub new {
    my $package = shift;

    my $self = $package->SUPER::new(@_);

    $self->{'name'} = __PACKAGE__;

    return $self;
}

=head1 Method: action

=head2 Description

Main action method for data handler

=head3 Details

=over

=item Set locale code based upon incoming params ('locale' param in incoming
request or 'locale' cookie), default value: 'en'

=item Set 'locale' cookie

=item Translate all values in data->pulma->data hash using previously defined
locale value and data object as data source

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

    log_it('debug', $self->{'name'} . '::action: invoked');

    $data->{'pulma'}->{'locale'} = $data->{'request'}->{'params'}->{'locale'}->[0]
				   || $data->{'request'}->{'cookies'}->{'locale'}->[0]
				   || 'en';

    push ( @{$data->{'result'}->{'cookies'}},
	   { 'name' => 'locale',
	     'value' => $data->{'pulma'}->{'locale'},
	     'expires' => 30 * 24 * 3600 }
    );

    if ( ($data->{'pulma'}->{'locale'} ne 'en') &&
	($data->{'result'}->{'status'} != REDIRECT) &&
	!$data->{'result'}->{'binary_data'} ) {

	$data->{'pulma'}->{'data'} = $self->_translate( $data->{'pulma'}->{'locale'},
							$data->{'pulma'}->{'data'} );

    }

    return $data;
}

############################## Private methods ##################################

# Method: _translate
# Description
#	Method to recursively translate data
# Argument(s)
#	1. (string) locale code
#	2. (custom) data to translate
# Returns
#	(custom) translated data

sub _translate {
    my $self = shift;
    my $locale = shift;
    my $tree = shift;

# check type of incoming data
    if (ref($tree) eq 'HASH') {
# incoming data is hash - recursively translate all values
	foreach (keys(%$tree)) {
	    $tree->{$_} = $self->_translate($locale, $tree->{$_});
	}
    }
    elsif (ref($tree) eq 'ARRAY') {
# incoming data is array - recursively translate all elements
	foreach (@$tree) {
	    $_ = $self->_translate($locale, $_);
	}
    }
    elsif (!ref($tree)) {
# incoming data is scalar value - translate value by getting appropriate data
	$tree = $self->_translate_value($locale, $tree);
    }

    return $tree;
}

# Method: _translate_value
# Description
#	Method to translate scalar value
# Argument(s)
#	1. (string) locale code
#	2. (string) scalar value
# Returns
#	(custom) translated value

sub _translate_value {
    my $self = shift;
    my $locale = shift;
    my $value = shift;

    return $value unless defined $value;

    my $translation = $self->{'data'}->get_entities( [ [ { 'name' => 'value',
							   'value' => $value,
							   'op' => '=' } ],
						     [ { 'name' => 'locale',
							 'value' => $locale,
							 'op' => '=' } ] ],
						     'translation' )->[0]->{'attributes'}->{'translation'}->[0];

    if ($translation) {
# localized constant found
	return $translation;
    }
    else {
# localized constant not found - place it into data storage to prevent from
# new searches
	$self->{'data'}->create_entity( { 'etype' => 'translation',
					  'attributes' => {
						'value' => [ $value ],
						'locale' => [ $locale ],
						'translation' => [ $value ]
					} } );

	return $value;
    }

}

1;
