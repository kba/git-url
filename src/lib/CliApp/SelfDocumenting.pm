package CliApp::SelfDocumenting;
use ObjectUtils;
use LogUtils;

my @_required = qw(name synopsis tag default);

sub new {
    my ($cls, %_self) = @_;

    ObjectUtils->validate_required_args( \@_required, %_self );

    $_self{description} //= $_self{synopsis};

    return bless \%_self, $cls;
}

sub doc_usage {
    my ($self) = @_;

    my $s = $self->{name};

    return $s;
}

1;
