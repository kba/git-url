package CliApp::Plugin::cliapp;

use LogUtils;
use StringUtils;
use ObjectUtils;

my $log = 'LogUtils';

use parent 'CliApp::Plugin';

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
        name => 'log_level',
        synopsis => 'Logging level',
        tag => 'common',
        default => 'error'
    );

    $app->add_command(
        name => 'version',
        synopsis => 'Show version information',
        tag => 'core',
    );

}

1;
