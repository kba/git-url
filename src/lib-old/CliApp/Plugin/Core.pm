package CliApp::Plugin::Core;
use strict;
use warnings;
use parent 'CliApp::Plugin';

sub setup_options {
    my ($config_class) = @_;
    $config_class->add_option(
        name => 'color_theme',
        synopsis  => "Don't look for the repo in the directories",
        usage => '--color-theme=<k:v,k:v...>',
        ref => ref {},
        default   => $HELPER::styles,
        tag       => 'prefs',
    );
    $config_class->add_option(
        name => 'loglevel',
        env       => 'LOGLEVEL',
        usage => '--debug[=trace|debug|info|error]',
        synopsis  => 'Log level',
        man_usage => '--debug[=*LEVEL*]',
        long_desc  => HELPER::unindent(
            12, q(
            Specify logging level. Can be one of `trace`, `debug`, `info`
                or `error`. If no level is specified, defaults to `debug`. If
            the option is omitted, only errors will be logged.
            )
        ),
        tag     => 'common',
        default => $ENV{LOGLEVEL} || 'error',
    );
}

sub setup_commands {
    my ($app_class) = @_;

    $app_class->add_command(
        name     => 'help',
        synopsis => 'Open help for command, option, plugin or option group',
        tag      => 'common',
        args => [
            {
                name =>
                  sprintf( 'cmd, opt, plugin or optgroup' ),
                synopsis => 'Command to look up',
                required => 0
            }
        ],
        do       => sub {
            my ($self) = @_;
            $_ = $self->{args}->[0];
            if ($_ && /^-/mx) {
                s/^-*//mx;
                s/-/_/gmx;
                my $opt = CliApp::Config->get_option($_);
                if ($opt) {
                    $opt->print_help()
                }
                else {
                    $self->print_help(error => "No such option: " . $self->{args}->[0]);
                }
            } elsif ($_) {
                s/-/_/gmx;
                my $cmd = $app_class->get_command($_);
                if ($cmd) {
                    $cmd->print_help()
                } else {
                    $self->print_help(tags => $self->{args}->[0]);
                }
            } else {
                $self->print_help();
            }
        }
    );

    $app_class->add_command(
        name     => 'version',
        synopsis => 'Show version information and such',
        tag      => 'common',
        do       => sub {
            my ( $self, $cli_config ) = @_;
            print colored( $HELPER::SCRIPT_NAME, 'bold blue' );
            print colored( " v$HELPER::VERSION\n", "bold green" );
            print colored( 'Build date: ', 'white bold' );
            print "$HELPER::BUILD_DATE\n";
            print colored( 'Last commit: ', 'white bold' );
            printf 'https://github.com/kba/%s/commit/%s\n', $HELPER::SCRIPT_NAME, $HELPER::LAST_COMMIT;
        }
    );

    $app_class->add_command(
        name     => 'usage',
        synopsis => 'Show usage',
        tag      => 'common',
        args     => [
            {
                name     => $app_class->all_tags(),
                synopsis => 'Tags to display',
                required => 0
            }
        ],
        do => sub {
            my ($self) = @_;
            my @tags = split( ',', $self->{args}->[0] // 'common' );
            $self->print_usage( tags => \@tags );
        }
    );
    return;
}

1;
