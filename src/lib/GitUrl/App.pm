package GitUrl::App;
use strict;
use warnings;
use parent 'Clapp::App';

use Cwd qw(getcwd realpath);
use File::Basename qw(dirname);
use List::Util;

use GitUrl::Utils::Tmux;
use GitUrl::Utils::Git;

use GitUrl::Plugin::giturl;
use GitUrl::Plugin::bitbucket;
use GitUrl::Plugin::github;

use GitUrl::Location;

sub new {
    my ($class, %self) = @_;

    my $self = $class->SUPER::new(
        version => '__VERSION__',
        build_date => '__BUILD_DATE__',
        name => 'git-url',
        synopsis => 'Work with Git platforms',
        tag => 'app',
        utils => [
            'GitUrl::Utils::Tmux',
            'GitUrl::Utils::Git',
        ],
        plugins => [
            'GitUrl::Plugin::giturl',
            'GitUrl::Plugin::bitbucket',
            'GitUrl::Plugin::github',
        ],
        %self,
    );

    GitUrl::Location->app( $self );

    return $self;
}

sub get_plugin_by_host
{
    my ($self, $needle) = @_;
    for my $plugin (values %{$self->plugins}) {
        next unless $plugin->isa('GitUrl::PlatformPlugin');
        next unless grep {$_ eq $needle} @{$plugin->{hosts}};
        return $plugin;
    }
}

1;
