#!/usr/bin/perl
use Data::Dumper;
use strict;
use warnings;
$Data::Dumper::Terse = 1;
use File::Basename qw(dirname);
use lib dirname($0) . '/../lib';

map {delete $ENV{$_}} keys(%ENV);
$ENV{HOME} = '$HOME';
$ENV{GIT_URL_SKIP_MAIN} = 1;

use RepoLocator;
use HELPER;


sub man_command {
    my $tokens = shift;
    $tokens->{__COMMANDS__} //= '';
    my $out = \ $tokens->{__COMMANDS__};
    for (RepoLocator->list_commands()) {
        my $cmd = RepoLocator->get_command($_);
        $$out .= "\n";
        $$out .= sprintf '## %s %s',
            $cmd->{name},
            join(' ', map {
                $_->{required} 
                    ? "&lt;" . $_->{name} . "&gt;"
                    : "[" . $_->{name} . "]"
                } @{ $cmd->{args} });
        $$out .= "\n\n";
        if ($cmd->{args} && scalar(@{ $cmd->{args} }) > 0) {
            for my $arg (@{ $cmd->{args} }) {
                $$out .= sprintf("* *%s* %s %s\n",
                    $arg->{name},
                    ($arg->{required} ? '**REQUIRED**' : '*OPTIONAL*'),
                    $arg->{cli_desc}
                );
                if ($arg->{man_desc}) {
                    $$out .= $arg->{man_desc};
                }
            }
            $$out .= "\n";
        }
        if ($cmd->{man_desc}) {
            $$out .= $cmd->{man_desc};
        } else {
            $$out .= $cmd->{cli_desc};
        }
        $$out .= "\n";
    }
}

sub man_options {
    my $tokens = shift;
    for (RepoLocator->list_options()) {
        my $opt = RepoLocator->get_option($_);
        my $token = sprintf("__OPTIONS_%s__", uc $opt->{tag});
        unless ($tokens->{$token}) {
            $tokens->{$token} = '';
        }
        my $out = \$tokens->{$token};
        # if (ref $opt->{default}) {
        #     warn Dumper sprintf("[%s]", join(",", @{$opt->{default}}))
        # }
        $$out .= "\n\n";
        $$out .= sprintf "%s, ENV:*%s*, DEFAULT:%s\n",
            $opt->{man_usage} || $opt->{cli_usage},
            $opt->{env} || '--',
            HELPER::human_readable_default($opt->{default});
            ;
        my $desc = $opt->{cli_desc};
        if ($opt->{man_desc}) {
            $desc = $opt->{man_desc};
        }
        unless ($desc) {
            warn Dumper $opt;
        }
        $desc = ':   ' . $desc;
        $desc =  join("\n    ", split(/\n/, $desc));
        $$out .= $desc;
    }
    return $tokens;
}

sub ini_options {
    my $tokens = shift;
    for (RepoLocator->list_options()) {
        my $opt = RepoLocator->get_option($_);
        my $token = sprintf("__OPTIONS_%s__", uc $opt->{tag});
        unless ($tokens->{$token}) {
            $tokens->{$token} = '';
        }
        my $out = \$tokens->{$token};
        # if (ref $opt->{default}) {
        #     warn Dumper sprintf("[%s]", join(",", @{$opt->{default}}))
        # }
        $$out .= "\n\n";
        # ; base_dir: Base directory where projects are stored
        # ; ENV: $GITDIR
        # ; base_dir     = ~/git-projects
        $$out .= HELPER::unindent(16, sprintf(q(
            %s, ENV:*%s*, DEFAULT:%s\n",
            ),
            $opt->{man_usage} || $opt->{cli_usage},
            $opt->{env} || '--',
            HELPER::human_readable_default($opt->{default});
        ));
            ;
        my $desc = $opt->{cli_desc};
        if ($opt->{man_desc}) {
            $desc = $opt->{man_desc};
        }
        unless ($desc) {
            warn Dumper $opt;
        }
        $desc = ':   ' . $desc;
        $desc =  join("\n    ", split(/\n/, $desc));
        $$out .= $desc;
    }
    return $tokens;
}

my %tokens = {
    man => {},
    ini => {},
};
man_command($tokens{man});
man_options($tokens{man});

$mode = @ARGV[0];

unless ($tokens{$mode}) {
    printf "Invalid mode '%s'. Valid modes: [%s]", $mode, keys %tokens;
    exit 1;
}

while (<STDIN>) {
    while (my ($k, $v) = each(%tokens)) {
        s/$k/$v/e;
    }
    print $_;
}
