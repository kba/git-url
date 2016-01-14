use Cwd qw(realpath);
use File::Basename qw(dirname);
my $SCRIPT_DIR;
BEGIN { $SCRIPT_DIR = realpath(dirname(realpath $0)) };
use lib $SCRIPT_DIR . '/../lib';

use Test::More;

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
        name => 'git-url',
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
    # $log->warn($cmd->get_command('help')->get_option('all')->full_name);
    $log->error("LEVEL now: '%s'", $LogUtils::LOGLEVEL);
    $log->info("Default config: %s", $cmd->default_config);
    $cmd->configure([qw(--loglevel=trace)],  $SCRIPT_DIR . "/assets/config.ini");
    $log->info("Parsed config: %s", $cmd->config);
    $log->error("LEVEL now: '%s'", $LogUtils::LOGLEVEL);

    $ENV{LOGLEVEL} = 'info';
    $cmd->configure();
    $log->error("LEVEL now: '%s'", $LogUtils::LOGLEVEL);
}

sub test_subcmd {
    my $cmd = CliApp::App->new(
        name => 'git-url',
        synopsis => 'do gitty stuff',
        tag => 'common',
        version => '0.0.1',
        build_date => qx(date),
        plugins => [qw(
            CliApp::Plugin::cliapp
        )],
    );
    # my $argv = [qw(--loglevel=trace help -- --fo)];
    my $argv = [qw(--loglevel=debug help)];
    # $log->info("Before optparse: %s", $argv);
    $cmd->exec($argv);
    #
    # $log->info("After optparse: %s", $argv);
    # # $cmd->do(qw(--loglevel=trace help));
    # $log->info("Parsed config: %s", $cmd->config);
    # $log->info("Parsed config: %s", $cmd->get_command('help')->config);
}

# test_logging();
# test_option();
# test_argument();
# test_command();
# test_app();
# test_config();
test_subcmd();

done_testing(10);
