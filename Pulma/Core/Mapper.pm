package Pulma::Core::Mapper;

use strict;
use warnings;

use Pulma::Service::Log;
use Pulma::Cacher::File;
use Pulma::Service::Data::Parser;

# Method: new
# Description: constructor
# Argument(s): 1: config (link to hash)
# Return: object
#
# Config hash structure: see docs for cbc.conf format
sub new {
    my $package = shift;
    my $config = shift;

    my $self = {};

# store configuration
    $self->{'config'} = $config;

# setup map file cacher
    $self->{'file'} = Pulma::Cacher::File->new($config->{'file'});

# setup data parser
    $self->{'parser'} = Pulma::Service::Data::Parser->new();

    return bless($self, $package);
}

sub steps {
    my $self = shift;
    my $request = shift;
    $request = $$request;

# get map
    my $map = $self->{'parser'}->decode(join('', @{$self->{'file'}->get()->{'content'}}));

    unless (defined($map)) {
	return [];
    }

    my $variants = {
	'default' => undef,
	'real' => undef,
	'before' => undef,
	'after' => undef
    };

    if (exists($map->{'/default'})) {
	$variants->{'default'} = $map->{'/default'};
    }
    else {
	log_it('warning', __PACKAGE__ . '::steps: default steps missing!');
    }

    $variants->{'before'} = $map->{'/before'} if exists($map->{'/before'});
    $variants->{'after'} = $map->{'/after'} if exists($map->{'/after'});

    if (exists($map->{$request->{'path'}})) {
	$variants->{'real'} = $map->{$request->{'path'}};
    }
    else {
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

    my $result = (scalar(@{$steps->{'real'}})) ? $steps->{'real'} : $steps->{'default'};

    @$result = (@{$steps->{'before'}}, @$result, @{$steps->{'after'}});

    return $result;
}

1;
