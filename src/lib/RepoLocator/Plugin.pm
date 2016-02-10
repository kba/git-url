package RepoLocator::Plugin;
use strict;
use warnings;
use HELPER;

sub new {
    my ($cls, %_self) = @_;

    HELPER::validate_required_methods($cls, qw(add_options to_url list_hosts));

    return bless \%_self, $cls;
}

sub list_hosts {
    my ($self) = @_;
    return wantarray ? @{$self->{hosts}} : $self->{hosts};
}

sub matches_host {
    my ($self, $needle) = @_;
    for ($self->list_hosts) {
        if ($needle eq $_) {
            return 1
        }
    }
    return;
}

1;
