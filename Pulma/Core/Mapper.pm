=head1 Pulma::Core::Mapper

Part of Pulma system

Class for incoming request mapping

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

package Pulma::Core::Mapper;

use strict;
use warnings;

use Pulma::Cacher::File;
use Pulma::Service::Data::Parser;
use Pulma::Service::Functions;
use Pulma::Service::Log;

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

see in example Pulma configuration file (section map)

=cut

sub new {
    my $package = shift;
    my $config = shift;

# prepare object frame
    my $self = { 'name' => __PACKAGE__ };

# store configuration
    $self->{'config'} = $config;

# setup data parser
    $self->{'parser'} = Pulma::Service::Data::Parser->new();

# setup map file cacher(s)
    $self->{'files'} = [];

    if (ref($config->{'file'}) eq '') {
	$config->{'file'} = [ $config->{'file'} ];
    }

    if (ref($config->{'file'}) eq 'ARRAY') {
	foreach my $file (@{$config->{'file'}}) {
	    push ( @{$self->{'files'}}, Pulma::Cacher::File->new($file) );
	}
    }

    return bless($self, $package);
}

=head1 Method: steps

=head2 Description

Method to determine chain of steps (data handlers) for the incoming request

=head2 Argument(s)

=over

=item 1. (link to link to hash) request hash

=back

=head2 Returns

=over

=item (link to array) chain of steps

=back

=cut

sub steps {
    my $self = shift;
    my $request = shift;
    $request = $$request;

# get map
    my $map = $self->_get_map();

    return [] unless defined $map;

    my $variants = {
	'default' => undef,
	'real' => undef,
	'before' => undef,
	'after' => undef
    };

# try to determine default steps
    if (exists($map->{'/default'})) {
	$variants->{'default'} = $map->{'/default'};
    }
    else {
	log_it('warning', $self->{'name'} . '::steps: default steps missing!');
    }

# try to determine neccessary starting and finishing steps
    $variants->{'before'} = $map->{'/before'} if exists($map->{'/before'});
    $variants->{'after'} = $map->{'/after'} if exists($map->{'/after'});

# look in mapping for exact matching of requested path
    if (exists($map->{$request->{'path'}})) {
	$variants->{'real'} = $map->{$request->{'path'}};
    }
    else {
# exact match not found, test requested path againts regular expressions in
# mapping
	foreach my $key (sort(keys(%$map))) {
	    my @check = regexp_check($request->{'path'}, $key);
	    if ($check[0] > 0) {
		$variants->{'real'} = $map->{$key};
		$request->{'subpath'} = $check[1] if (defined $check[1]);
		last;
	    }
	}
    }

    my $steps = {
	'before' => [],
	'default' => [],
	'real' => [],
	'after' => []
    };

# take into account all restrictions for all chains of steps (default, found,
# starting and finishing)
    foreach ('default', 'real', 'before', 'after') {
	next unless defined $variants->{$_};
	foreach my $step (@{$variants->{$_}}) {
	    if (exists($step->{'restrictions'})) {
		my $match = 1;
# restrictions by method
		if (exists($step->{'restrictions'}->{'method'})) {
		    $match = 0;
		    if (ref($step->{'restrictions'}->{'method'}) eq 'ARRAY') {
			foreach my $restriction (@{$step->{'restrictions'}->{'method'}}) {
			    if ($restriction eq $request->{'method'}) {
				$match = 1;
				last;
			    }
			}
		    }
		    elsif (ref($step->{'restrictions'}->{'method'}) eq '') {
			$match = 1 if ($step->{'restrictions'}->{'method'} eq $request->{'method'});
		    }

# method not matched - skip step
		    next unless $match;
		}

# restrictions by IP
		if (exists($step->{'restrictions'}->{'ip'})) {
		    $match = 0;
		    if (ref($step->{'restrictions'}->{'ip'}) eq 'ARRAY') {
			foreach my $restriction (@{$step->{'restrictions'}->{'ip'}}) {
			    if ($restriction eq $request->{'remoteip'}) {
				$match = 1;
				last;
			    }
			}
		    }
		    elsif (ref($step->{'restrictions'}->{'ip'}) eq '') {
			$match = 1 if ($step->{'restrictions'}->{'ip'} eq $request->{'remoteip'});
		    }

# ip not matched - skip step
		    next unless $match;
		}
# restrictions by path
		if (exists($step->{'restrictions'}->{'path'})) {
		    $match = 0;
		    if (ref($step->{'restrictions'}->{'path'}) eq '') {
			$step->{'restrictions'}->{'path'} = [ $step->{'restrictions'}->{'path'} ];
		    }
		    if (ref($step->{'restrictions'}->{'path'}) eq 'ARRAY') {
			foreach my $restriction (@{$step->{'restrictions'}->{'path'}}) {
			    if ($restriction eq $request->{'path'}) {
				$match = 1;
				last;
			    }
			    else {
				my @check = regexp_check($request->{'path'}, $restriction);
				if ($check[0] > 0) {
				    $match = 1;
				    last;
				}
			    }
			}
		    }
		}
# restrictions by useragent
		if (exists($step->{'restrictions'}->{'ua'})) {
		    $match = 0;
		    if (ref($step->{'restrictions'}->{'ua'}) eq '') {
			$step->{'restrictions'}->{'ua'} = [ $step->{'restrictions'}->{'ua'} ];
		    }
		    if (ref($step->{'restrictions'}->{'ua'}) eq 'ARRAY') {
			foreach my $restriction (@{$step->{'restrictions'}->{'ua'}}) {
			    if ($restriction eq $request->{'useragent'}) {
				$match = 1;
				last;
			    }
			    else {
				my @check = regexp_check($request->{'useragent'}, $restriction);
				if ($check[0] > 0) {
				    $match = 1;
				    last;
				}
			    }
			}
		    }
# useragent not matched - skip step
		    next unless $match;
		}

		push(@{$steps->{$_}}, $step) if ($match);

	    }
	    else {
		push(@{$steps->{$_}}, $step);
	    }
	}
    }

# use found chain of steps if there are at least one, otherwise - use default chain of steps
    my $result = (scalar(@{$steps->{'real'}})) ? $steps->{'real'} : $steps->{'default'};

# add starting and finishing chains
    @$result = (@{$steps->{'before'}}, @$result, @{$steps->{'after'}});

    return $result;
}

=head1 Method: init_steps

=head2 Description

Method to determine chain of steps (data handlers) for the server start-up

=head2 Argument(s)

=over

=item none

=back

=head2 Returns

=over

=item (link to array) chain of steps

=back

=cut

sub init_steps {
    my $self = shift;

# get map
    my $map = $self->_get_map();

    return (defined $map && exists($map->{'/init'})) ? $map->{'/init'} : [];
}

############################## Private methods ##################################

# Method: _get_map
# Description
#	Method to get requests handling map
# Argument(s)
#	none
# Returns
#	(link to hash) requests handling map I<or> undef if correct map was not
#		       found

sub _get_map {
    my $self = shift;

    my $map;
    foreach my $file (@{$self->{'files'}}) {
	my $part = $self->{'parser'}->decode(join('',@{$file->get()->{'content'}}));
	if (defined $part) {
	    foreach (keys %$part) {
		$map->{$_} = $part->{$_};
	    }
	}
    }

    return defined($map) ? $map : undef;
}

1;
