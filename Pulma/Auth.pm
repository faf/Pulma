=head1 Pulma::Auth

Part of Pulma system

Class for operations with source of auth data

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

package Pulma::Auth;

use strict;
use warnings;

use Pulma::Data;
our @ISA = ('Pulma::Data');

=head1 Method: new

=head2 Description

Class constructor

=head2 Argument(s)

=over

=item see Pulma::Data class

=back

=head2 Returns

=over

=item see Pulma::Data class

=back

=cut

sub new {
    my $package = shift;

    my $self = $package->SUPER::new(@_, __PACKAGE__);

    return $self;
}

1;
