package Pulma::Actions::Localization;

use strict;
use warnings;

use Pulma::Actions::Prototype;
our @ISA = ('Pulma::Actions::Prototype');

sub new {
    my $package = shift;

    my $self = $package->SUPER::new(@_);

    return $self;
}

sub action {
    my $self = shift;
    my $data = shift;

    $data->{'pulma'}->{'locale'} = $data->{'request'}->{'params'}->{'locale'}->[0] || $data->{'request'}->{'cookies'}->{'locale'}->[0] || 'en';
    push (@{$data->{'result'}->{'cookies'}}, {'name' => 'locale', 'value' => $data->{'pulma'}->{'locale'}, 'expires' => 30 * 24 * 3600});

    if ($data->{'pulma'}->{'locale'} ne 'en') {
	$data->{'pulma'}->{'data'} = $self->_translate($data->{'pulma'}->{'locale'}, $data->{'pulma'}->{'data'});
    }

    return $data;
}

sub _translate {
    my $self = shift;
    my $locale = shift;
    my $tree = shift;

    if (ref($tree) eq 'HASH') {
	foreach (keys(%$tree)) {
	    $tree->{$_} = $self->_translate($locale, $tree->{$_});
	}
    }
    elsif (ref($tree) eq 'ARRAY') {
	foreach (@$tree) {
	    $_ = $self->_translate($locale, $_);
	}
    }
    elsif (!ref($tree)) {
	return $self->{'data'}->get_entities( [ [ {'name' => 'value', 'value' => $tree, 'op' => '='} ],
						[ {'name' => 'locale', 'value' => $locale, 'op' => '='} ] ], 'translation')->[0]->{'attributes'}->{'translation'}->[0] || $tree;
    }

    return $tree;
}

1;
