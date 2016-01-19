package Clapp::Utils;
use strict;
use warnings;
use Data::Dumper;
use Clapp::Utils::Object;

sub new {
    my ($class, %args) = @_;
    Clapp::Utils::Object->validate_required_args( $class, [qw(app)],  %args );
    my $self = bless \%args, $class;
    return $self;
}

sub app {
    my ($self) = @_;
    die "Must set 'app'" if ! ref $self || ! $self->{app};
    return $self->{app};
}

sub utils {
    my ($self) = @_;
    die "Must set 'app'" if ! ref $self || ! $self->{app};
    return $self->{app}->{utils};
}

sub log {
    return Clapp::Utils::SimpleLogger->get;
}

1;
