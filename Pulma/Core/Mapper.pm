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

# setup map file cacher
    $self->{'file'} = Pulma::Cacher::File->new($config->{'file'});

# setup data parser
    $self->{'parser'} = Pulma::Service::Data::Parser->new();

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
	    next unless ($key =~ /^\/(.+)\/$/) && eval { '' =~ /$1/; 1 };
	    my $template = $1;
	    if ($request->{'path'} =~ /$template/) {
		$variants->{'real'} = $map->{$key};
		$request->{'subpath'} = $1 if (defined $1);
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

# TODO: add restriction by path

# take into account all restrictions for all chains of steps (default, found,
# starting and finishing)
    foreach ('default', 'real', 'before', 'after') {
	next unless defined $variants->{$_};
	foreach my $step (@{$variants->{$_}}) {
	    if (exists($step->{'restrictions'})) {
		if (exists($step->{'restrictions'}->{'method'})) {
		    if (ref($step->{'restrictions'}->{'method'}) eq 'ARRAY') {
			foreach my $restriction (@{$step->{'restrictions'}->{'method'}}) {
			    if ($restriction eq $request->{'method'}) {
				push(@{$steps->{$_}}, $step);
				last;
			    }
			}
		    }
		    elsif (ref($step->{'restrictions'}->{'method'}) eq '') {
			push(@{$steps->{$_}}, $step) if ($step->{'restrictions'}->{'method'} eq $request->{'method'});
		    }
		}
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

    my $map = $self->{'parser'}->decode(join('',@{$self->{'file'}->get()->{'content'}}));

    return defined($map) ? $map : undef;
}

1;
