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
    my (%args) = @_;
    my %location_base =  (
        name     => 'location',
        synopsis => 'Location',
        tag      => 'common',
    );
    return {
        location_optional => {
            %location_base,
            required => 0,
            default  => '.',
            %args,
        },
        location => {
            %location_base,
            required => 1,
            %args,
        },
    };
}

sub inject {
    my ($self, $app) = @_;

    # my $tmux_utils = new GitUrl::Utils::Tmux(app => $app);
    # my $git_utils = new GitUrl::Utils::Git(app => $app);
    # my $string_utils = new Clapp::Utils::String(app => $app);
    # my $file_utils = new Clapp::Utils::File(app => $app);

    $app->add_option(
        name => 'default_platform',
        synopsis => 'Plugin to use for default_platform',
        tag => 'prefs',
        enum => [],
        default => 'github',
    );

    $app->add_option(
        name => 'fuzzy',
        synopsis => 'Level of fuzziness for finding repos',
        tag => 'prefs',
        default => 1,
    );

    $app->add_option(
        name => 'repo_dirs',
        synopsis => 'Base directories to scan for repos',
        tag => 'prefs',
        default => [$ENV{HOME} . '/build', $ENV{HOME} . '/dotfiles/repo'],
    );

    $app->add_option(
        name => 'repo_dir_patterns',
        synopsis => 'Patterns for finding subdirectories in repo dirs',
        tag => 'prefs',
        default => ["%host/%owner/%repo_name", "%repo_name"],
    );

    $app->add_option(
        name => 'private',
        synopsis => 'Create new repositories private',
        tag => 'common',
        boolean => 1,
        default => 0,
    );

    $app->add_option(
        name => 'create',
        synopsis => 'Create repository unless found',
        tag => 'common',
        boolean => 1,
        default => 0,
    );

    $app->add_option(
        name => 'prefer_ssh',
        synopsis => 'prefer ssh',
        tag => 'prefs',
        boolean => 1,
        default => 1,
    );

    $app->add_option(
        name => 'force',
        synopsis => 'Force operation',
        tag => 'common',
        boolean => 1,
        default => 0,
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
        tag => 'prefs',
        env => 'BROWSER',
        default => $ENV{BROWSER} || 'chromium',
    );

    $app->add_command(
        name => 'delete',
        synopsis => 'Delete a remote repository',
        tag => 'common',
        arguments => [ _common_arguments->{location} ],
        exec => sub {
            my ($this, $argv) = @_;
            my $path = $argv->[0];
            $self->app->{config}->{"interactive"} = 1;
            my $loc = GitUrl::Location->parse( $argv->[0] );
            $loc->delete_remote()
        },
    );

    $app->add_command(
        name => 'parse',
        synopsis => 'Test parsing',
        tag => 'common',
        arguments => [ _common_arguments->{location_optional} ],
        exec => sub {
            my ($this, $argv) = @_;
            my $path = $argv->[0] ? $argv->[0] : $this->get_argument('location')->default;
            print sprintf( "%s: %s\n",
                $self->style( 'cli', 'heading', 'Repo' ),
                $self->app->get_utils('string')->dump(GitUrl::Location->parse( $path ))
            );
        },
    );

    $app->add_command(
        name => 'www',
        synopsis => 'Open in browser',
        tag => 'common',
        arguments => [ _common_arguments->{location_optional} ],
        exec => sub {
            my ($this, $argv) = @_;
            my $path = $argv->[0] ? $argv->[0] : $this->get_argument('location')->default;
            my $loc = GitUrl::Location->parse( $path );
            $self->app->get_utils('file')->system( sprintf("%s %s", $app->get_config("browser"), $loc->browse_url) );
        }
    );

    $app->add_command(
        name => 'info',
        synopsis => 'Show info about location',
        tag => 'common',
        arguments => [ _common_arguments->{location_optional} ],
        exec => sub {
            my ($this, $argv) = @_;
            my $path = $argv->[0] ? $argv->[0] : $this->get_argument('location')->default;
            print sprintf( "%s: %s\n",
                $self->style( 'cli', 'heading', 'Current Branch' ),
                $self->app->get_utils('git')->git_current_branch($path)
            );
            print sprintf( "%s: %s\n",
                $self->style( 'cli', 'heading', 'Basedir' ),
                $self->app->get_utils('git')->git_basedir($path)
            );
            print sprintf( "%s: %s\n",
                $self->style( 'cli', 'heading', 'Config' ),
                $self->app->get_utils('string')->dump($self->app->get_utils('git')->git_config($path))
            );
        }
    );

    $app->add_command(
        name => 'shell',
        synopsis => 'Show browse URL',
        tag => 'common',
        arguments => [ _common_arguments()->{location_optional} ],
        exec => sub {
            my ($this, $argv) = @_;
            my $loc = GitUrl::Location->parse( $argv->[0] );
            $loc->clone();
            $self->app->get_utils("file")->chdir($loc->path_to_repo);
            $self->app->get_utils("file")->system('zsh');
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
        arguments => [ _common_arguments->{location} ],
        exec => sub {
            my ($this, $argv) = @_;
            my @sessions = @{ $self->app->get_utils('tmux')->list_sessions };
            unless (scalar @{ $argv }) {
                for (@sessions) {
                    print $self->style('cli', 'option', "  * %s (%s)\n", $_->{repo_name}, $_->path_to_repo);
                }
                return;
            }
            my $path = $argv->[0] ? $argv->[0] : $this->get_argument('location')->default;
            my $matching_session = $self->app->get_utils('string')->fuzzy_match($argv->[0], map {$_->get_shortcut} @sessions );
            if (! $matching_session) {
                my $loc = GitUrl::Location->parse( $argv->[0] );
                $loc->clone();
                if ($loc->path_to_repo) {
                    $self->app->get_utils('tmux')->create_session( $loc );
                }
            } elsif (! ref $matching_session) {
                $self->app->get_utils('tmux')->attach( $matching_session );
            } else {
                for (@{ $matching_session }) {
                    print $self->style('cli', 'option', "  * %s (%s)\n", $_->{repo_name}, $_->path_to_repo);
                }
            }
        }
    );

}

sub on_configure {
    my ($self, $app) = @_;
    $app->get_option('default_platform')->{enum} = [ map { $_->name } @{ $app->platform_plugins}  ];
    # $app->get_option('default_platform')->{default} = 'github';
    # $app->get_option('default_platform')->{default} = $app->get_option('default_platform')->{enum}->[0];
}

1;
