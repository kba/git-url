package Clapp::Plugin;
use Clapp::Utils::Object;

use parent 'Clapp::SelfDocumenting';

sub new {
    my ($class, %self) = @_;

    $name = lc $class;
    $name =~ s/^.*://mx;
    $self{name} //= $name;

    Clapp::Utils::Object->validate_required_methods($class, 'inject', 'on_configure');

    return $class->SUPER::new($class, [], %self);
}

1;
