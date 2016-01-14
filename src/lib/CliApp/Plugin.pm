package CliApp::Plugin;
use ObjectUtils;

use parent 'CliApp::SelfDocumenting';

sub new {
    my ($class, %self) = @_;

    $name = __PACKAGE__;
    $name =~ s/^.*://mx;
    $self{name} //= $name;

    ObjectUtils->validate_required_methods($class, 'inject', 'on_configure');

    return $class->SUPER::new($class, [], %self);
}

1;
