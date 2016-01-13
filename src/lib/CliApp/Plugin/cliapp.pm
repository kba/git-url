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
        name => 'loglevel',
        synopsis => 'Logging level',
        tag => 'common',
        default => $LogUtils::LOGLEVEL,
        env => 'LOGLEVEL',
        enum => [keys %{ $LogUtils::LOGLEVELS }],
    );

    # $app->add_command(
        # name => 'version',
        # synopsis => 'Show version information',
        # tag => 'core',
    # );
    $app->add_command(
        name => 'help',
        synopsis => 'Show help',
        tag => 'core',
        do => sub {
            my ($this) = @_;
            $log->debug("YAYAYAYAYAYA");
        },
        options => [
            {
                name => 'all',
                synopsis => 'Show full help',
                boolean => 1,
                tag => 'common',
                default => 'false',
            }
        ],
    );

}

sub on_configure {
    my ($self, $app) = @_;
    $app->get_option('loglevel')->{enum} = [keys %{ $LogUtils::LOGLEVELS }];
    LogUtils->set_level( $app->config->{loglevel} );
}

1;
