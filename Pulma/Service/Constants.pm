# Library module with named constants
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

package Pulma::Service::Constants;

use strict;
use warnings;

require Exporter;

our @ISA = ('Exporter');
our @EXPORT = qw( FORBIDDEN NOT_FOUND OK REDIRECT ERROR BIG_REQUEST );

# HTTP status codes
use constant OK => 200;
use constant REDIRECT => 302;
use constant FORBIDDEN => 403;
use constant NOT_FOUND => 404;
use constant BIG_REQUEST => 413;
use constant ERROR => 500;

1;
