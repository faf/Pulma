# Part of Pulma system
# Module providing means for logging events using standard syslog
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

package Pulma::Service::Log;

use strict;
use warnings;

use Sys::Syslog qw(:standard :macros);

require Exporter;

our @ISA = ('Exporter');
our @EXPORT = qw(&log_it);

# Syslog configuration parameters
# (could be overriden in module making use of this one)
our $Level;
$Level = 2 unless defined $Level;
our $Ident;
$Ident = '' unless defined $Ident;
our $Logopt;
$Logopt = '' unless defined $Logopt;
our $Facility;
$Facility = '' unless defined $Facility;

# Function: log_it
# Description: write message to syslog
# Argument(s): 1: priority (string), 2: message (string in sprintf format), 3: array of values to populate message with
# Return: 1 in all cases
sub log_it {
    my $priority = shift;
    my $message = shift;
    my @data = @_;
    openlog($Ident, $Logopt, $Facility);
    my $level;
# set up actual log level
    if ($Level == 0) {
	$level = LOG_WARNING;
    }
    elsif ($Level == 1) {
	$level = LOG_NOTICE;
    }
    elsif ($Level == 2) {
	$level = LOG_INFO;
    }
    else {
	$level = LOG_DEBUG;
    }
    setlogmask(LOG_UPTO($level));
# write message to syslog
    syslog($priority, sprintf($message, @data));
    closelog();

    return 1;
}

1;
