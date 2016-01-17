package Clapp::Plugin::core;
use strict;
use warnings;

use Clapp::Utils::SimpleLogger;
use Clapp::Utils::String;

use parent 'Clapp::Plugin';

my $options = {
    mode => {
        name => 'mode',
        synopsis => 'Output mode',
        tag => 'common',
        enum => [@Clapp::SelfDocumenting::_modes],
        default => 'cli',
    },
};

sub new {
    my ($class, %self) = @_;

    return $class->SUPER::new(
        %self,
        synopsis => 'Core plugin for Clapp',
        tag => 'core',
    );

}

sub inject {
    my ($self, $app) = @_;

    $app->add_option(
        name => 'log',
        synopsis => 'Logging level',
        tag => 'common',
        default => $ENV{LOGLEVEL} || Clapp::Utils::SimpleLogger->get->loglevel,
        env => 'LOGLEVEL',
        enum => Clapp::Utils::SimpleLogger->get->levels,
    );

    $app->add_option(
        name => 'ini',
        synopsis => 'Configuration file to use',
        tag => 'common',
        default => sub { return $_[0]->app->{default_ini}; },
        env => 'foo',
    );

    $app->add_option(
        name => 'dry_run',
        synopsis => "Print commands instead of executing them",
        tag => 'common',
        boolean => 1,
        default => 0,
    );


    $app->add_command(
        name => 'version',
        synopsis => 'Show version information',
        tag => 'core',
        options => [ $options->{mode} ],
        exec => sub {
            my ($this, $argv) = @_;
            $self->log->debug("%s", $this->config);
            print $this->app->doc_version(%{ $this->config });
        }
    );

    $app->add_command(
        name => 'help',
        synopsis => 'Show help',
        tag => 'core',
        options => [
            $options->{mode},
            {
                name => 'group',
                synopsis => 'Group options/commands',
                tag => 'common',
                boolean => 1,
                default => 0,
            },
            {
                name => 'verbosity',
                synopsis => 'Verbosity of help output',
                tag => 'common',
                enum => [0..4],
                default => 1,
            },
        ],
        exec => sub {
            my ($this, $argv) = @_;
            my $it = $this->app;
            for (@{$argv}) {
                $self->log->debug("%s -> %s", ref $it, $_);
                $it = $it->get_by_name($_);
            }
            return print $it->doc_help(%{ $this->config });
        },
        arguments => [
            {
                name => 'topic',
                synopsis => 'cmd, option etc.',
                tag => 'common',
                required => 0,
                default => '',
            },
        ],
    );

}

sub on_configure {
    my ($self, $app) = @_;
    # logging
    $app->get_option('log')->{enum} = Clapp::Utils::SimpleLogger->get->levels;
    Clapp::Utils::SimpleLogger->get->loglevel( $app->config->{log} );
    # dry-run
    if ($app->config->{dry_run}) {
        $ENV{DRY_RUN} = 1;
    } else {
        delete $ENV{DRY_RUN};
    }
}

1;
