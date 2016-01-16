package Repo;

use CliApp::ObjectUtils;

my @_required = qw(repo_org repo_name);

sub new {
    my ($class, %args) = @_;

    CliApp::ObjectUtils->validate_required_args( $class, [@_required],  %args );

    return bless \%args, $class;
}

1;
