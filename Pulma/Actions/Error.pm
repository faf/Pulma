package Pulma::Actions::Error;

use strict;
use warnings;

use Pulma::Actions::Prototype;
our @ISA = ('Pulma::Actions::Prototype');

# Method: new
# Description: constructor
# Argument(s): 1: config (link to hash)
# Return: object
#
# Config hash structure: { 'cache' => <path to cache>, 'templates' => <path to templates> }
sub new {
    my $package = shift;

    my $self = $package->SUPER::new(@_);

    $self->{'errors'} = {
	'404' => {
	    'title' => 'Not found',
	    'text' => 'Requested resource not found'
	},
	'403' => {
	    'title' => 'Forbidden',
	    'text' => 'You are not allowed to access requested resource'
	},
	'default' => {
	    'title' => 'Internal server error',
	    'text' => 'Internal server error occured. Please visit our site later'
	}
    };

    return $self;
}

sub action {
    my $self = shift;
    my $data = shift;
    my $specs = shift;

    my $error = $self->{'errors'}->{'default'};
    if (exists ($specs->{'code'}) && exists($self->{'errors'}->{$specs->{'code'}})) {
	$data->{'result'}->{'status'} = $specs->{'code'};
	$data->{'pulma'}->{'data'}->{'error'}->{'title'} = $self->{'errors'}->{$specs->{'code'}}->{'title'};
	$data->{'pulma'}->{'data'}->{'error'}->{'text'} = $self->{'errors'}->{$specs->{'code'}}->{'text'};
	$data->{'pulma'}->{'data'}->{'error'}->{'code'} = $specs->{'code'};
    }

    $data->{'result'}->{'template'} = 'error.tpl';

    $self->{'logger'}->create_entity({
	'etype' => 'http_error',
	'attributes' => {
	    'time'	=> [ time ],
	    'aentity'	=> [ exists($data->{'pulma'}->{'user'}->{'id'}) ? $data->{'pulma'}->{'user'}->{'id'} : 0 ],
	    'dentity'	=> [ 0 ],
	    'code'	=> [ $data->{'result'}->{'status'} ],
	    'url'	=> [ $data->{'request'}->{'url'} ],
	    'fullurl'	=> [ $data->{'request'}->{'fullurl'} ],
	    'method'	=> [ $data->{'request'}->{'method'} ]
	}
    });

    return $data;
}

1;
