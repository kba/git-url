package CliApp::Plugin;
use strict;
use warnings;
use HELPER;

sub new {
    my ($cls, %_self) = @_;

    HELPER::validate_required_methods($cls, qw(setup_options setup_commands));

    return bless \%_self, $cls;
}

1;
