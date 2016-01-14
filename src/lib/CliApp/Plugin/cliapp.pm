package CliApp::Plugin::cliapp;

use LogUtils;
use StringUtils;
use ObjectUtils;

my $log = 'LogUtils';

use parent 'CliApp::Plugin';

$options = {
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
        default => $LogUtils::LOGLEVEL,
        env => 'LOGLEVEL',
        enum => [keys %{ $LogUtils::LOGLEVELS }],
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
            print $this->app->doc_version($this->config->{mode});
        }
    );

    $app->add_command(
        name => 'help',
        synopsis => 'Show help',
        tag => 'core',
        options => [ $options->{mode} ],
        exec => sub {
            my ($this, $argv) = @_;
            print $this->app->doc_help($this->config->{mode});
        },
        arguments => [
            {
                name => 'arg',
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
    $app->get_option('loglevel')->{enum} = [keys %{ $LogUtils::LOGLEVELS }];
    LogUtils->set_level( $app->config->{loglevel} );
}

1;
