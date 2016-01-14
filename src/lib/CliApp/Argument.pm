package CliApp::Argument;
use strict;
use warnings;
use parent 'CliApp::SelfDocumenting';

sub new {
    my ($cls, %self) = @_;

    if ($self{required}) {
        if (exists $self{default}) {
            LogUtils->log_die("A required argument cannot have a default: %s", \%self);
        }
        $self{default} = undef;
    }
    $self{repeatable} //= undef;

    return $cls->SUPER::new($cls, [qw(required default repeatable)], %self);
}

1;
