package GitUrl::Plugin::giturl;
use strict;
use warnings;
use Data::Dumper;
use GitUrl::Utils::Tmux;
use Cwd qw(getcwd realpath);

use parent 'Clapp::Plugin';

use GitUrl::Location;

sub new {
    my ($class, %self) = @_;

    return $class->SUPER::new(
        synopsis => 'Core plugin for GitUrl',
        tag => 'giturl',
        %self,
    );
}

sub _common_arguments {
    return {
        location => {
            name     => 'location',
            synopsis => 'Location',
            required => 0,
            tag      => 'common',
            default  => '.',
        },
    };
}

sub inject {
    my ($self, $app) = @_;

    my $tmux_utils = new GitUrl::Utils::Tmux(app => $app);
    my $git_utils = new GitUrl::Utils::Git(app => $app);
    my $string_utils = new Clapp::Utils::String(app => $app);
    my $file_utils = new Clapp::Utils::File(app => $app);

    $app->add_option(
        name => 'clone_from',
        synopsis => 'Plugin to use for clone_from',
        tag => 'common',
        enum => [],
        default => 'bitbucket.org',
    );

    $app->add_option(
        name => 'repo_dirs',
        synopsis => 'Base directories to scan for repos',
        tag => 'common',
        default => [$ENV{HOME} . '/build', $ENV{HOME} . '/dotfiles/repo'],
    );

    $app->add_option(
        name => 'repo_dir_patterns',
        synopsis => 'Patterns for finding subdirectories in repo dirs',
        tag => 'common',
        default => ["%host/%owner/%repo_name", "%repo_name"],
    );

    $app->add_option(
        name => 'host_aliases',
        synopsis => 'Aliases for hosts',
        tag => 'common',
        default => {},
    );

    $app->add_option(
        name => 'browser',
        synopsis => 'Browser to use',
        tag => 'common',
        env => 'BROWSER',
        default => $ENV{BROWSER} || 'chromium',
    );

    $app->add_command(
        name => 'parse',
        synopsis => 'Test parsing',
        tag => 'common',
        arguments => [ _common_arguments->{location} ],
        exec => sub {
            my ($this, $argv) = @_;
            my $path = $argv->[0] ? $argv->[0] : $this->get_argument('location')->default;
            print sprintf( "%s: %s\n",
                $self->style( 'cli', 'heading', 'Repo' ),
                $string_utils->dump(GitUrl::Location->parse( $path ))
            );
        },
    );

    $app->add_command(
        name => 'www',
        synopsis => 'Open in browser',
        tag => 'common',
        arguments => [ _common_arguments->{location} ],
        exec => sub {
            my ($this, $argv) = @_;
            my $path = $argv->[0] ? $argv->[0] : $this->get_argument('location')->default;
            my $loc = GitUrl::Location->parse( $path );
            $file_utils->system( sprintf("%s %s", $app->config->{browser}, $loc->browse_url) );
        }
    );

    $app->add_command(
        name => 'info',
        synopsis => 'Show info about location',
        tag => 'common',
        arguments => [ _common_arguments->{location} ],
        exec => sub {
            my ($this, $argv) = @_;
            my $path = $argv->[0] ? $argv->[0] : $this->get_argument('location')->default;
            print sprintf( "%s: %s\n",
                $self->style( 'cli', 'heading', 'Current Branch' ),
                $git_utils->git_current_branch($path)
            );
            print sprintf( "%s: %s\n",
                $self->style( 'cli', 'heading', 'Basedir' ),
                $git_utils->git_basedir($path)
            );
            print sprintf( "%s: %s\n",
                $self->style( 'cli', 'heading', 'Config' ),
                $string_utils->dump($git_utils->git_config($path))
            );
        }
    );

    $app->add_command(
        name => 'url',
        synopsis => 'Show browse URL',
        tag => 'common',
        arguments => [ _common_arguments->{location} ],
        exec => sub {
            my ($this, $argv) = @_;
            my $path = $argv->[0] ? $argv->[0] : $this->get_argument('location')->default;
            my $loc = GitUrl::Location->parse( $path );
            printf "Full Path: %s\n", $loc->full_path;
            printf "Browse URL: %s\n", $loc->browse_url;
            $loc->clone();
        }
    );

    $app->add_command(
        name => 'tmux',
        synopsis => 'Open/attach tmux',
        tag => 'common',
        exec => sub {
            my ($this, $argv) = @_;
            for my $sess (@{ $tmux_utils->list_sessions }) {
                print $self->style('cli', 'option', "  * %s\n", $sess);
            }
        }
    );

}

sub on_configure {
    my ($self, $app) = @_;
    $app->get_option('clone_from')->{enum} = [
        grep { $app->plugins->{$_}->isa('GitUrl::PlatformPlugin') }
          keys %{ $app->plugins }
      ];
      $app->get_option('clone_from')->{default} = $app->get_option('clone_from')->{enum}->[0];
}

1;
