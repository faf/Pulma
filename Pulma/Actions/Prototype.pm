package Pulma::Actions::Prototype;

use strict;
use warnings;

use Pulma::Auth;
use Pulma::Data;
use Pulma::Logger;

use Pulma::Service::Functions;
use Pulma::Service::Log;
use Pulma::Service::Data::Parser;

# Method: new
# Description: constructor
# Argument(s): 1: config (link to hash)
# Return: object
#
# Config hash structure: { 'cache' => <path to cache>, 'templates' => <path to templates> }
sub new {
    my $package = shift;
    my $config = shift;
    my $cache = shift;
    $cache = $$cache;

    my $self = {
	'config' => $config
    };

    if (exists($config->{'logger'})) {
# initialize logger object
	log_it('debug',  __PACKAGE__ . '::new: initializing logger object');
	$self->{'logger'} = Pulma::Logger->new($config->{'logger'}, \$cache);
	unless (defined $self->{'logger'}) {
	    log_it('err', __PACKAGE__ . "::new: can't initialize logger object!");
	    return undef;
	}
    }

    if (exists($config->{'data'})) {
# initialize data object
	log_it('debug',  __PACKAGE__ . '::new: initializing data object');
	$self->{'data'} = Pulma::Data->new($config->{'data'}, \$cache);
	unless (defined $self->{'data'}) {
	    log_it('err', __PACKAGE__ . "::new: can't initialize data object!");
	    return undef;
	}
    }

    if (exists($config->{'auth'})) {
# initialize auth object
	log_it('debug',  __PACKAGE__ . '::new: initializing auth object');
	$self->{'auth'} = Pulma::Auth->new($config->{'auth'}, \$cache);
	unless (defined $self->{'auth'}) {
	    log_it('err', __PACKAGE__ . "::new: can't initialize auth object!");
	    return undef;
	}
    }

# initialize parser object
    log_it('debug', __PACKAGE__ . '::new: initializing parser object');
    $self->{'parser'} = Pulma::Service::Data::Parser->new({});

    return bless($self, $package);
}

sub action {
    my $self = shift;
    my $data = shift;
    my $specs = shift;

    return $data;
}

1;
