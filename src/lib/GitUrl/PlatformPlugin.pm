package GitUrl::PlatformPlugin;
use CliApp::ObjectUtils;

use parent 'CliApp::Plugin';

sub new {
    my ($class, %args) = @_;

    CliApp::ObjectUtils->validate_required_methods($class, 'to_url');

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
