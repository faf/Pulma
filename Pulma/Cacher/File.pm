package Pulma::Cacher::File;

use strict;
use warnings;

use File::stat;

use Pulma::Service::Log;

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

sub get {
    my $self = shift;

    my $flag = 0;

    unless (-r $self->{'filename'}) {
	log_it('err', __PACKAGE__ . '::get: file %s not readable, return old content', $self->{'filename'});
    }
    else {
	log_it('debug', __PACKAGE__ . '::get: file %s is readable', $self->{'filename'});

	my $old = 1;
	my $timestamp = stat($self->{'filename'})->mtime;
	if (defined $self->{'lasttime'}) {
	    log_it('debug', __PACKAGE__ . '::get: last change of file %s is %s', $self->{'filename'}, $timestamp);
	    unless ($self->{'lasttime'} < $timestamp) {
		log_it('debug', __PACKAGE__ . '::get: old change time is %s, should keep old content', $self->{'lasttime'});
		$old = 0;
	    }
	    else {
		log_it('debug', __PACKAGE__ . '::get: old change time is %s, should update content', $self->{'lasttime'});
	    }
	}
	else {
	    log_it('debug', __PACKAGE__ . '::get: first read of file %s', $self->{'filename'});
	}

	if ($old) {
	    if ($self->_read_file()) {
		log_it('debug', __PACKAGE__ . '::get: everything fine, update last change time');
		$self->{'lasttime'} = $timestamp;
		$flag = 1;
	    }
	    else {
		log_it('debug', __PACKAGE__ . '::get: something went wrong, don\'t update last change time');
	    }
	}
    }

    return {
	'updated' => $flag,
	'content' => $self->{'content'}
    };
}

sub _read_file {
    my $self = shift;
    my $file = $self->{'filename'};

    unless (-r $file) {
	log_it('err', __PACKAGE__ . '::_read_file: file %s not readable', $file);
	return 0;
    }
    else {
	log_it('debug', __PACKAGE__ . '::_read_file: file %s is readable', $file);
    }

    my @content;
    if (open(IN, '<', $file)) {
	log_it('debug', __PACKAGE__ . '::_read_file: successfully opened file %s', $file);
	@content = <IN>;
	log_it('debug', __PACKAGE__ . '::_read_file: got file %s contents', $file);
	unless (close(IN)) {
	    log_it('err', __PACKAGE__ . '::_read_file: can\'t close file %s: %s', $file, $!);
	}
	else {
	    log_it('debug', __PACKAGE__ . '::_read_file: successfully closed file %s', $file);
	}
	$self->{'content'} = \@content;
	return 1;
    }
    else {
	log_it('err', __PACKAGE__ . '::_read_file: can\'t open file %s for read: %s', $file, $!);
	return 0;
    }
}

1;
