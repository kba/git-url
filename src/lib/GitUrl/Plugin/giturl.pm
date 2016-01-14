package GitUrl::Plugin::giturl;

my $log = 'LogUtils';

use parent 'CliApp::Plugin';

sub new {
    my ($class, %self) = @_;

    return $class->SUPER::new(
        %self,
        synopsis => 'Core plugin for GitUrl',
        tag => 'giturl',
    );
}

sub inject {
    my ($self, $app) = @_;
    $app->add_command(
        name => 'tmux',
        synopsis => 'Open/attach tmux',
        tag => 'common',
        exec => sub {
        }
    )
}

sub on_configure {
    my ($self, $app) = @_;
}

1;
