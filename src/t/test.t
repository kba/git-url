use Cwd qw(realpath);
use File::Basename qw(dirname);
use lib realpath(dirname(realpath $0) . '/../lib');

use Test::More;

use CliApp::Config;
use CliApp::Option;
use CliApp::Command;
use CliApp::App;
use CliApp::Argument;

my $log = LogUtils;

sub test_option {
    my $opt = CliApp::Option->new(
        name => 'foo',
        synopsis => 'set foo opt',
        tag => 'common',
        parent => 'dummy',
        default => 0,
    );
    isa_ok $opt, 'CliApp::Option';
}

sub test_argument {
    my $opt = CliApp::Argument->new(
        name => 'foo-arg',
        synopsis => 'a foo-arg arg',
        tag => 'common',
        required => 0,
        default => 0,
        parent => 'dummy',
    );
    isa_ok $opt, 'CliApp::Argument';
}

sub test_command {
    my $cmd = CliApp::Command->new(
        name => 'foo',
        synopsis => 'a foo-arg cmd',
        tag => 'common',
        parent => undef,
        do => sub {},
        options => [
            {
                name => 'bar',
                synopsis => 'bar all the foos',
                default => '23',
                tag => 'common',
            }
        ],
        arguments => [],
        commands => [
            {
                name=> 'ls',
                synopsis => 'ls something',
                tag => 'common',
                options => [],
                arguments => [],
                commands => [],
                do => sub {
                    my ($self) = @_;
                }
            },
        ],
        required => 0,
    );
    isa_ok $cmd, 'CliApp::Command';
    isa_ok $cmd->get_command('ls'), 'CliApp::Command';
    isa_ok $cmd->get_option('bar'), 'CliApp::Option';
    is $cmd->get_command('ls')->parent, $cmd, '->parent';
    is $cmd->get_command('ls')->app, $cmd, '->app';
}

sub test_logging {
    $log->debug("foobar %s %s", {foo=>42}, [qw(bar)]);
}

sub test_app {
    my $cmd = CliApp::App->new(
        name => 'foo',
        synopsis => 'a foo cmd',
        tag => 'common',
        arguments => [
            {
                name => 'blork-arg',
                synopsis => 'blork-arg',
                required => 1,
                tag => 'common',
            }
        ],
        plugins => [qw(
            CliApp::Plugin::cliapp
        )],
    );
    isa_ok $cmd, 'CliApp::Command';
    isa_ok $cmd, 'CliApp::App';
    isa_ok $cmd->plugins->{cliapp}, 'CliApp::Plugin';
    # $log->info("%s", $cmd);
}

sub test_config {
    my $cmd = CliApp::App->new(
        name => 'foo',
        synopsis => 'a foo cmd',
        tag => 'common',
        arguments => [
            {
                name => 'blork-arg',
                synopsis => 'blork-arg',
                required => 1,
                tag => 'common',
            }
        ],
        plugins => [qw(
            CliApp::Plugin::cliapp
        )],
    );
    my $config = CliApp::Config->new(app => $cmd, argv => ['--log-level=foo']);
    isa_ok $config, 'CliApp::Config';
    $log->info("%s", $config);
}

test_logging();
test_option();
test_argument();
test_command();
test_app();
test_config();

done_testing(10);
