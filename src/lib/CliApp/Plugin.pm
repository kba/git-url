package CliApp::Plugin;
use CliApp::ObjectUtils;

use parent 'CliApp::SelfDocumenting';

sub new {
    my ($class, %self) = @_;

    $name = lc $class;
    $name =~ s/^.*://mx;
    $self{name} //= $name;

    CliApp::ObjectUtils->validate_required_methods($class, 'inject', 'on_configure');

    return $class->SUPER::new($class, [], %self);
}

1;
