=head1 Pulma::Output

Part of Pulma system

Default class for output preparation

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

package Pulma::Output;

use strict;
use warnings;

use Pulma::Service::Log;

use Template;

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

{   'cache'	=> <path to cache>,
    'templates' => <path to templates>   }

=cut

sub new {
    my $package = shift;
    my $config = shift;

    my $self = {
	'config' => $config,
	'name' => __PACKAGE__
    };

# initialize Templates Toolkit object
    $self->{'output'} = Template->new( {    ABSOLUTE		=> 1,
					    RELATIVE		=> 1,
					    INTERPOLATE		=> 0,
					    POST_CHOMP		=> 1,
					    COMPILE_EXT		=> '.tt2',
					    COMPILE_DIR		=> $config->{'cache'},
					    INCLUDE_PATH	=> $config->{'templates'},
					    EVAL_PERL		=> 1,
					    ENCODING		=> 'utf8'
    } );

    return bless($self, $package);
}

=head1 Method: generate

=head2 Description

Method to generate document based upon template name and data to populate
template with

=head2 Argument(s)

=over

=item 1. (link to hash) data structure (see system documentation for details)

=back

=head2 Returns

=over

=item (link to hash) data structure (with generated document as result->document)

=back

=cut

sub generate {
    my $self = shift;
    my $data = shift;

    my $result;

    $self->{'output'}->process( $data->{'result'}->{'template'},
				$data,
				\$result,
				{ binmode => ":utf8" } );

    $data->{'result'}->{'document'} = $result;

    return $data;
}

1;
