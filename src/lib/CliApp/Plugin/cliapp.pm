package CliApp::Plugin::cliapp;
use strict;
use warnings;

use SimpleLogger;
use StringUtils;
use ObjectUtils;

use parent 'CliApp::Plugin';

my $options = {
    mode => {
        name => 'mode',
        synopsis => 'Output mode',
        tag => 'core',
        enum => [@CliApp::SelfDocumenting::_modes],
        default => 'cli',
    },
};

sub new {
    my ($class, %self) = @_;

    return $class->SUPER::new(
        %self,
        synopsis => 'Core plugin for CliApp',
        tag => 'core',
    );

}

sub inject {
    my ($self, $app) = @_;

    $app->add_option(
        name => 'loglevel',
        synopsis => 'Logging level',
        tag => 'common',
        default => SimpleLogger->new->loglevel,
        env => 'LOGLEVEL',
        enum => SimpleLogger->new->levels,
    );

    $app->add_option(
        name => 'ini',
        synopsis => 'Configuration file to use',
        tag => 'common',
        default => sub { return $_[0]->app->{default_ini}; },
        env => 'foo',
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
    $app->get_option('loglevel')->{enum} = SimpleLogger->new->levels;
    SimpleLogger->new->loglevel( $app->config->{loglevel} );
}

1;
