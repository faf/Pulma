=head1 Pulma::Service::Constants

Part of Pulma system

Library module with named constants

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

package Pulma::Service::Constants;

use strict;
use warnings;

require Exporter;

our @ISA = ('Exporter');
our @EXPORT = qw( FORBIDDEN NOT_FOUND OK REDIRECT ERROR BIG_REQUEST );

=head1 HTTP status codes

=cut

=head2 OK = 200

=cut

use constant OK => 200;

=head2 REDIRECT = 302

=cut

use constant REDIRECT => 302;

=head2 FORBIDDEN = 403

=cut

use constant FORBIDDEN => 403;

=head2 NOT_FOUND = 404

=cut

use constant NOT_FOUND => 404;

=head2 BIG_REQUEST = 413

=cut

use constant BIG_REQUEST => 413;

=head2 ERROR = 500

=cut

use constant ERROR => 500;

1;
