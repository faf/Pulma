package Pulma::Service::Data::Parser;

use strict;
use warnings;

use JSON::XS;

use Pulma::Service::Log;

sub new {
    my $package = shift;
    my $config = shift;

# setup configuration
    my $self = { 'config' => $config };

# setup JSON parser
    $self->{'parser'} = JSON::XS->new();
    $self->{'parser'}->allow_unknown(1);
    $self->{'parser'}->shrink(1);

    return bless($self, $package);
}

sub encode {
    my $self = shift;
    my $data = shift;

    return undef unless (defined $data);

    my $string;
    eval {
	$string = $self->{'parser'}->encode($data);
    };
    if ($@) {
	log_it('err', __PACKAGE__ . '::encode: fail to encode: %s', $@);
	$string = undef;
    }
    elsif (ref($string)) {
	log_it('err', __PACKAGE__ . '::encode: fail to encode: got result as %s', ref($string));
	$string = undef;
    }
    else {
	log_it('debug', __PACKAGE__ . '::encode: successfully encoded data');
    }

    return $string;
}

sub decode {
    my $self = shift;
    my $string = shift;

    return undef unless (defined $string);

    my $data;
    eval {
	$data = $self->{'parser'}->decode($string);
    };
    if ($@) {
	log_it('err', __PACKAGE__ . '::decode: fail to decode: %s', $@);
	$data = undef;
    }
    elsif ((ref($data) ne 'HASH') && (ref($data) ne 'ARRAY')) {
	log_it('err', __PACKAGE__ . '::decode: fail to decode: got result as %s', ref($data));
	$data = undef;
    }
    else {
	log_it('debug', __PACKAGE__ . '::decode: successfully decoded data');
    }

    return $data;
}

1;
