package CliApp::Argument;
use parent 'CliApp::SelfDocumenting';

sub new {
    my ($cls, %_self) = @_;

    $self{required} //= 0;

    return bless $cls->SUPER::new(@_), $cls;
}

1;
