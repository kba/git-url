use Cwd qw(realpath);
use File::Basename qw(dirname);
use lib realpath(dirname(realpath $0) . '/../lib');

use Test::More;

use CliApp::Option;
use CliApp::Command;
use CliApp::Argument;

my $log = LogUtils;

sub test_option {
    my $opt = CliApp::Option->new(
        name => 'foo',
        synopsis => 'set foo opt',
        tag => 'common',
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
    );
    isa_ok $opt, 'CliApp::Argument';
}

sub test_command {
    my $cmd = CliApp::Command->new(
        name => 'foo',
        synopsis => 'a foo-arg cmd',
        tag => 'common',
        parent => undef,
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
    $log->debug("%s", $cmd);
    isa_ok $cmd, 'CliApp::Command';
    isa_ok $cmd->commands->{ls}, 'CliApp::Command';
    isa_ok $cmd->options->{bar}, 'CliApp::Option';
    is $cmd->commands->{ls}->parent, $cmd, 'parent';
    is $cmd->commands->{ls}->root, $cmd, 'root';
}

sub test_command_plugin {
    my $cmd = CliApp::Command->new(
        name => 'foo',
        synopsis => 'a foo-arg cmd',
        tag => 'common',
        parent => undef,
        plugins => [qw(
            CliApp::Plugin::Core
        )],
    );
    $log->debug("%s", $cmd);
    isa_ok $cmd, 'CliApp::Command';
    isa_ok $cmd->plugins->{CliApp::Plugin::Core}, 'CliApp::Plugin';
}

sub test_logging {
    $log->debug("foobar %s %s", {foo=>42}, [qw(bar)]);
}

test_logging();
test_option();
test_argument();
test_command();
test_command_plugin();

done_testing(3);
