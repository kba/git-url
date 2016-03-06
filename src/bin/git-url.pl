#!/usr/bin/perl
use strict;
use warnings;
use Carp qw(croak carp);
use Cwd qw(realpath);
use File::Basename qw(dirname);

use lib realpath(dirname(realpath $0) . '/../lib');
use RepoLocator;

my @ARGV_PROCESSED;
my $cli_config = {};
while (my $arg = shift(@ARGV)) {
    if ($arg =~ '^-') {
        $arg =~ s/^-*//mx;
        my ($k, $v) = split('=', $arg);
        $v //= 1;
        if ($k =~ /^no-/) {
            $k =~ s/^no-//;
            $v = undef;
        }
        OPTION_LOOP:
        for (RepoLocator->list_options()) {
            my $opt = RepoLocator->get_option($_);
            if (exists $opt->{shortcut}->{$k}) {
                $k = $opt->{name};
                $v = $opt->{shortcut}->{$k};
                last;
            }
        }
        $v =~ s/~/$ENV{HOME}/mx;
        $cli_config->{$k} = $v;
    } else {
        push @ARGV_PROCESSED, $arg;
    }
}
my $cmd_name = shift(@ARGV_PROCESSED) || 'usage';
$cmd_name =~ s/[^a-z0-9]/_/gimx;
my $cmd = RepoLocator->get_command($cmd_name) or do {
    RepoLocator->usage(error => "Unknown command: '$cmd_name'\n");
    exit 1;
};
if (scalar(grep { $_->{required} } @{ $cmd->{args} }) > scalar(@ARGV_PROCESSED)) {
    print colored("Error: ", 'bold red') . "Not enough arguments\n\n";
    __PACKAGE__->usage_cmd_opt($cmd);
    exit 1;
}
my $self = RepoLocator->new(\@ARGV_PROCESSED, $cli_config);
$cmd->{do}->($self);
