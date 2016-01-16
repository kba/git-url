package Clapp::Utils;

sub new {
    my ($class, %args) = @_;
    Clapp::Utils::Object->validate_required_args( $class, [qw(app)],  %args );
    my $self = bless \%args, $class;
}

sub app {
    return $self->{app};
}

sub log {
    return Clapp::Utils::SimpleLogger->new;
}

1;
