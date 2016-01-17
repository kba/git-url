package Clapp::Utils;

sub new {
    my ($class, %args) = @_;
    Clapp::Utils::Object->validate_required_args( $class, [qw(app)],  %args );
    my $self = bless \%args, $class;
    return $self;
}

sub app {
    my ($self) = @_;
    return $self->{app};
}

sub utils {
    my ($self) = @_;
    return $self->{app}->{utils};
}

sub log {
    return Clapp::Utils::SimpleLogger->get;
}

1;
