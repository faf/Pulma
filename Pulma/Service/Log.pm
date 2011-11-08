=head1 Pulma::Service::Log

Part of Pulma system

Module providing tools for logging events using standard syslog

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

package Pulma::Service::Log;

use strict;
use warnings;

use Sys::Syslog qw(:standard :macros);

require Exporter;

our @ISA = ('Exporter');
our @EXPORT = qw( &log_it );

=head1 Syslog configuration parameters that could be overriden

see module Sys::Syslog for more details

=cut

=head2 Pulma::Service::Log::Level

=cut
our $Level;
$Level = 2 unless defined $Level;

=head2 Pulma::Service::Log::Ident

=cut

our $Ident;
$Ident = '' unless defined $Ident;

=head2 Pulma::Service::Log::Logopt

=cut

our $Logopt;
$Logopt = '' unless defined $Logopt;

=head2 Pulma::Service::Log::Facility

=cut

our $Facility;
$Facility = '' unless defined $Facility;

=head1 Function: Pulma::Service::Log::ExtLog

=head2 Description

External log function that could be overriden

=head2 Argument(s)

=over

=item ?. (various) elements of the B<Pulma::Service::Log::ExtLogArgs> array

=item 1. (string) priority

=item 2. (string) message (in sprintf format, with placeholders)

=item 3. (array) values to populate message with (using sprintf)

=back

=head2 Returns

=over

=item 1 in all cases

=back

B<NOTE!> This function called right after log into syslog. There are
usually a lot of messages of level 'debug', so you have to correctly handle
priorities in your own logging function.

B<IMPORTANT!> If function for external logging written with use of
B<Pulma::Service::Log::ExtLogsArgs> array it should correctly handle a situation
when all elements of that array is defined but empty. It should be done for
validation of that function during Pulma startup.

=cut

our @ExtLogArgs = ();

our $ExtLog;
$ExtLog = sub { return 1; } unless (defined $ExtLog && (ref($ExtLog) ne 'CODE'));



=head1 Function: log_it

=head2 Description

Write message to syslog

Call external logging function

=head2 Argument(s)

=over

=item 1. (string) priority

=item 2. (string) message (in sprintf format, with placeholders)

=item 3. (array) values to populate message with (using sprintf)

=back

=head2 Returns

=over

=item 1 in all cases

=back

=cut

sub log_it {
    my $priority = shift;
    my $message = shift;
    my @data = @_;

# check whether syslog switched on
    unless ($Level < 0) {

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

    }

# call external logging function
    &$ExtLog(@ExtLogArgs, $priority, $message, @data);

    return 1;
}

1;
