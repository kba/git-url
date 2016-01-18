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
    return {
        location => {
            name     => 'location',
            synopsis => 'Location',
            required => 0,
            tag      => 'common',
            default  => '.',
            %args,
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
        name => 'default_platform',
        synopsis => 'Plugin to use for default_platform',
        tag => 'common',
        enum => [],
        default => 'github',
    );

    $app->add_option(
        name => 'fuzzy',
        synopsis => 'Level of fuzziness for finding repos',
        tag => 'common',
        default => 1,
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
        tag => 'common',
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
        tag => 'common',
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
            my $path = $argv->[0] ? $argv->[0] : $this->get_argument('location')->default;
            $self->app->config->{interactive} = 1;
            my $loc = GitUrl::Location->parse( $argv->[0] );
            $loc->delete_remote()
        },
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
        name => 'shell',
        synopsis => 'Show browse URL',
        tag => 'common',
        arguments => [ _common_arguments()->{location} ],
        exec => sub {
            my ($this, $argv) = @_;
            my $loc = GitUrl::Location->parse( $argv->[0] );
            $loc->clone();
            $self->app->utils->{file}->chdir($loc->path_to_repo);
            $self->app->utils->{file}->system('zsh');
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
            my @sessions = @{ $tmux_utils->list_sessions };
            unless (scalar @{ $argv }) {
                for (@sessions) {
                    print $self->style('cli', 'option', "  * %s (%s)\n", $_->{repo_name}, $_->path_to_repo);
                }
                return;
            }
            my $matching_session = $string_utils->fuzzy_match($argv->[0], map {$_->get_shortcut} @sessions );
            if (! $matching_session) {
                my $loc = GitUrl::Location->parse( $argv->[0] );
                $loc->clone();
                if ($loc->path_to_repo) {
                    $tmux_utils->create_session( $loc );
                }
            } elsif (! ref $matching_session) {
                $tmux_utils->attach( $matching_session );
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
