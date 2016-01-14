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
        enum => LogUtils->list_levels,
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
        options => [ $options->{mode}, ],
        exec => sub {
            my ($this, $argv) = @_;
            print $this->app->doc_version($this->config->{mode});
        }
    );

    $app->add_command(
        name => 'help',
        synopsis => 'Show help',
        tag => 'core',
        options => [
            $options->{mode},
            {
                name => 'full',
                synopsis => 'show full help',
                tag => 'common',
                boolean => 1,
                default => 0,
            },
        ],
        exec => sub {
            my ($this, $argv) = @_;
            my @path;
            while (my $arg = shift @{ $argv }) {
                if ($arg =~ m/^-/mx) {
                    $arg =~ s/^-*//mx;
                    $arg =~ s/-/_/gmx;
                    push @path, ['get_option', $arg];
                } else {
                    push @path, ['get_command', $arg];
                }
            }
            if (scalar @path) {
                my $it = $this->app;
                for (@path) {
                    ($method, $arg) = @{ $_ };
                    $it = $it->$method($arg);
                }
                return print $it->doc_help( $this->config->{mode}, full => $this->config->{full});
            }
            print $this->app->doc_help( $this->config->{mode}, full => $this->config->{full});
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
    $app->get_option('loglevel')->{enum} = LogUtils->list_levels;
    LogUtils->set_level( $app->config->{loglevel} );
}

1;
