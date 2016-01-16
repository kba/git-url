package GitUrl::PlatformPlugin;
use Clapp::Utils::Object;

use parent 'Clapp::Plugin';

sub new {
    my ($class, %args) = @_;

    Clapp::Utils::Object->validate_required_methods($class, 'to_url');

    return $class->SUPER::new( %args );
}

sub inject {
    my ($self, $app) = @_;

    # TODO
}

sub on_configure {
    my ($self, $app) = @_;

    # TODO
}

1;
