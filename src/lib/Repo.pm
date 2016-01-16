package Repo;

use Clapp::Utils::Object;

my @_required = qw(repo_org repo_name);

sub new {
    my ($class, %args) = @_;

    Clapp::Utils::Object->validate_required_args( $class, [@_required],  %args );

    return bless \%args, $class;
}

1;
