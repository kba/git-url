package GitUrl::Plugin::giturl;
use strict;
use warnings;
use GitUrl::Utils::Tmux;

use parent 'Clapp::Plugin';

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

    $app->add_option(
        name => 'clone',
        synopsis => 'Plugin to use for clone',
        tag => 'common',
        enum => [],
        default => 'github',
    );

    $app->add_command(
        name => 'tmux',
        synopsis => 'Open/attach tmux',
        tag => 'common',
        exec => sub {
            my ($this, $argv) = @_;
            for my $sess (@{ GitUrl::Utils::Tmux->list_sessions }) {
                print $self->style('cli', 'option', "  * %s\n", $sess);
            }
        }
    )

}

sub on_configure {
    my ($self, $app) = @_;
    $app->get_option('clone')->{enum} = [ grep {
        $app->plugins->{$_}->isa('GitUrl::PlatformPlugin')
        } keys %{ $app->plugins }
    ];
}

1;
