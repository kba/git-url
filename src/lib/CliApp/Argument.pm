package CliApp::Argument;
use strict;
use warnings;
use parent 'CliApp::SelfDocumenting';

sub new {
    my ($cls, %self) = @_;

    return $cls->SUPER::new($cls, [qw(required default)], %self);
}

1;
