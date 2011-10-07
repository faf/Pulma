package Pulma::Cacher::Data;

use strict;
use warnings;

use Pulma::Service::Log;

sub new {
    my $package = shift;
    my $cache = shift;
    $cache = $$cache;

    my $self = {
	'cache' => \$cache
    };

    return bless($self, $package);
}

sub get {
    my $self = shift;
    my $id = shift;
    my $time = shift;

    if (exists(${$self->{'cache'}}->{$id})) {
	if (${$self->{'cache'}}->{$id}->{'modtime'} < $time) {
	    $self->del($id);
	    return undef;
	}
	else {
	    return ${$self->{'cache'}}->{$id};
	}
    }
    else {
	return undef;
    }
}

sub put {
    my $self = shift;
    my $id = shift;
    my $data = shift;

    %{${$self->{'cache'}}->{$id}} = %$data;

    return 1;
}

sub del {
    my $self = shift;
    my $id = shift;

    delete ${$self->{'cache'}}->{$id};

    return 1;
}

1;
