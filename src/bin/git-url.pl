#!/usr/bin/perl
use strict;
use warnings;
use Carp qw(croak carp);
use Cwd qw(realpath);
use File::Basename qw(dirname);

use lib realpath(dirname(realpath $0) . '/../lib');
use RepoLocator;
use HELPER;
use Data::Dumper;
$Data::Dumper::Terse = 1;

my @ARGV_PROCESSED;
my $cli_config = {};
while (my $arg = shift(@ARGV)) {
    if ($arg =~ '^-') {
        $arg =~ s/^-*//mx;
        my ($k, $v) = split('=', $arg);
        $v //= 1;
        if ($k =~ /^no-/) {
            $k =~ s/^no-//;
            $v = 0;
        }
        OPTION_LOOP:
        for (RepoLocator->list_options()) {
            my $opt = RepoLocator->get_option($_);
            if (exists $opt->{shortcut}->{$k}) {
                $v = $opt->{shortcut}->{$k};
                $k = $opt->{name};
                last;
            }
        }
        if ($v) {
            $v =~ s/~/$ENV{HOME}/mx;
        }
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
    RepoLocator->usage(error => "Not enough arguments for $cmd_name", tags => ['common'], cmd => $cmd_name);
    exit 1;
}
my $self = RepoLocator->new(\@ARGV_PROCESSED, $cli_config);
$cmd->{do}->($self);
