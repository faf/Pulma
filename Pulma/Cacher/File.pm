=head1 Pulma::Cacher::File

Part of Pulma system

Class for access to contents of a given file with built-in cache mechanism

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

package Pulma::Cacher::File;

use strict;
use warnings;

use File::stat;

use Pulma::Service::Log;

=head1 Method: new

=head2 Description

Class constructor

=head2 Argument(s)

=over

=item 1. (string) filename

=back

=head2 Returns

=over

=item (object) instance of class

=back

=cut

sub new {
    my $package = shift;
    my $filename = shift;

    my $self = {
	'filename' => $filename,
	'lasttime' => undef,
	'content' => []
    };

    return bless($self, $package);
}

=head1 Method: get

=head2 Description

Method to get file contents

=head2 Argument(s)

=over

=item none

=back

=head2 Returns

=over

=item (link to hash) resulting hash

=back

=head2 Structure of resulting hash

{

	'updated' => 1 if file contents were updated, 0 - otherwise

	'content' => <file contents> (link to array of strings)

}

=cut

sub get {
    my $self = shift;

    my $flag = 0;

# check file to be readable
    unless (-r $self->{'filename'}) {

	log_it( 'err',
		__PACKAGE__ . '::get: file %s not readable, return old content',
		$self->{'filename'} );

    }
    else {

	log_it( 'debug',
		__PACKAGE__ . '::get: file %s is readable',
		$self->{'filename'} );

# get time of last modification of the file
	my $old = 1;
	my $timestamp = stat($self->{'filename'})->mtime;

# check whether it is the first time of getting file's contents
	if (defined $self->{'lasttime'}) {

# file was already stored in cache, check if stored data is obsolete

	    log_it( 'debug',
		    __PACKAGE__ . '::get: last change of file %s is %s', $self->{'filename'},
		    $timestamp );

	    unless ($self->{'lasttime'} < $timestamp) {

		log_it( 'debug',
			__PACKAGE__ . '::get: old change time is %s, should keep old content',
			$self->{'lasttime'} );
		$old = 0;

	    }
	    else {

		log_it( 'debug',
			__PACKAGE__ . '::get: old change time is %s, should update content',
			$self->{'lasttime'} );

	    }
	}
	else {

# first time call
	    log_it( 'debug',
		    __PACKAGE__ . '::get: first read of file %s',
		    $self->{'filename'} );

	}

	if ($old) {

# data is obsolete (or it is a first-time call) - try to  read file contents
	    if ($self->_read_file()) {

		log_it( 'debug',
			__PACKAGE__ . '::get: everything fine, update last change time'
		);

		$self->{'lasttime'} = $timestamp;
		$flag = 1;

	    }
	    else {

		log_it( 'debug',
			__PACKAGE__ . "::get: something went wrong, don't update last change time");

	    }
	}
    }

    return {
	'updated' => $flag,
	'content' => $self->{'content'}
    };
}

############################## Private methods ##################################

# Method: _read_file
# Description
#	Method to read the file contents and store it in cache
# Argument(s)
#	none
# Returns
#	1 on success or 0 on error

sub _read_file {
    my $self = shift;
    my $file = $self->{'filename'};

# check file to be readable
    unless (-r $file) {

	log_it( 'err',
		__PACKAGE__ . '::_read_file: file %s not readable',
		$file );

	return 0;

    }
    else {

	log_it( 'debug',
		__PACKAGE__ . '::_read_file: file %s is readable',
		$file );

    }

# get file contents
    my @content;
    if (open(IN, '<', $file)) {

	log_it( 'debug',
		__PACKAGE__ . '::_read_file: successfully opened file %s',
		$file );

	@content = <IN>;

	log_it( 'debug',
		__PACKAGE__ . '::_read_file: got file %s contents',
		$file );

	unless (close(IN)) {

	    log_it( 'err',
		    __PACKAGE__ . '::_read_file: can\'t close file %s: %s',
		    $file, $! );

	}
	else {

	    log_it( 'debug',
		    __PACKAGE__ . '::_read_file: successfully closed file %s',
		    $file );

	}

# store file contents in cache
	$self->{'content'} = \@content;

	return 1;

    }
    else {

	log_it( 'err',
		__PACKAGE__ . '::_read_file: can\'t open file %s for read: %s',
		$file, $! );

	return 0;

    }
}

1;
