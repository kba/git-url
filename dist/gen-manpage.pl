#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
$Data::Dumper::Terse = 1;

BEGIN {
    map {delete $ENV{$_}} keys(%ENV);
    $ENV{HOME} = '$HOME';
}

use File::Basename qw(dirname);
use lib dirname($0) . '/../src/lib';
use RepoLocator;
use HELPER;

my @modes = qw(man ini);
my %tokens = map { $_ => {} } @modes;
my $mode = $ARGV[0];
unless ($mode) {
    printf('Must provide mode, one of [%s]', join ',', @modes);
    exit 1;
};
unless ($tokens{$mode}) {
    printf("Invalid mode '%s'. Valid modes: [%s]", $mode, join ',', @modes);
    exit 2;
}
my $method = "to_$mode";

sub gen_command {
    my $tokens = shift;
    return unless RepoLocator::Command->can($method);
    $tokens->{__COMMANDS__} //= '';
    my $out = \ $tokens->{__COMMANDS__};
    for (RepoLocator->list_commands()) {
        my $cmd = RepoLocator->get_command($_);
        $$out .= $cmd->$method;
    }
}

sub gen_options {
    my $tokens = shift;
    my $all_token = $tokens->{__OPTIONS__};
    $tokens->{__OPTIONS__} //= '';
    my $all_out = \$tokens->{__OPTIONS__};
    for (RepoLocator->list_options()) {
        my $opt = RepoLocator->get_option($_);
        my $token = sprintf("__OPTIONS_%s__", uc $opt->{tag});
        $tokens->{$token} //= '';
        my $out = \$tokens->{$token};
        my $str = $opt->$method;
        $$out .= $str;
        $$all_out .= $str;
    }
    return $tokens;
}

gen_command($tokens{$mode});
gen_options($tokens{$mode});

# warn Dumper \%tokens;

while (<STDIN>) {
    while (my ($k, $v) = each(%{$tokens{$mode}})) {
        s/$k/$v/e;
    }
    print $_;
}
