#!/usr/bin/perl
use strict;
use warnings;
use Carp qw(croak carp);
use Cwd qw(realpath);
use File::Basename qw(dirname);

use lib realpath(dirname(realpath $0) . '/../lib');
use CliApp;

my @ARGV_PROCESSED;
my $cli_config = {};
my $in_args    = 0;
while (my $arg = shift(@ARGV)) {
    if ($arg =~ '^-' && !$in_args) {
        CliApp::Config->parse_kv($cli_config, $arg);
    }
    else {
        $in_args = 1;
        push @ARGV_PROCESSED, $arg;
    }
}
my $cmd_name = shift(@ARGV_PROCESSED) || 'usage';
$cmd_name =~ s/[^a-z0-9]/_/gimx;
my $cmd = CliApp->get_command($cmd_name) or do {
    CliApp->usage(error => "Unknown command: '$cmd_name'\n");
    exit 1;
};
if (scalar(grep { $_->{required} } @{ $cmd->{args} }) > scalar(@ARGV_PROCESSED)) {
    print colored("Error: ", 'bold red') . "Not enough arguments\n\n";
    __PACKAGE__->usage_cmd_opt($cmd);
    exit 1;
}
my $self = CliApp->new(
    subcommand => $cmd_name,
    args => \@ARGV_PROCESSED,
    opts => $cli_config
);
$cmd->{do}->($self);
