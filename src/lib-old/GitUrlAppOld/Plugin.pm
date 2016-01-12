package GitUrlApp::Plugin;
use strict;
use warnings;
use HELPER;
use parent 'CliApp::Plugin';

sub new {
    my ($cls, %_self) = @_;

    HELPER::validate_required_args($cls, [qw(hosts)], %_self);
    HELPER::validate_required_methods($cls, qw(to_url list_hosts));

    return $cls->SUPER::new(%_self);
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
