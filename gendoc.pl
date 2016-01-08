#!/usr/bin/perl
use Data::Dumper;
use strict;
use warnings;
no warnings 'uninitialized';
$Data::Dumper::Terse = 1;

map {delete $ENV{$_}} keys(%ENV);
$ENV{HOME} = '$HOME';
$ENV{GIT_URL_SKIP_MAIN} = 1;
require './git-url';

sub _clean_string {
    my ($hash, $key) = @_;
    (my $man_desc = $hash->{$key}) =~ s/^ {12}//mg;
    $man_desc =~ s/^\n*//;
    $man_desc =~ s/\s*$//g;
    $man_desc =~ s/\n*$//;
    return $man_desc;
}

sub gen_command {
    my $tokens = shift;
    $tokens->{__COMMANDS__} //= '';
    my $out = \ $tokens->{__COMMANDS__};
    for (sort keys %RepoLocator::command_doc) {
        my $cmd = $RepoLocator::command_doc{$_};
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
                $$out .= sprintf "* *%s* %s %s\n",
                $arg->{name},
                ($arg->{required} ? '**REQUIRED**' : '*OPTIONAL*'),
                $arg->{cli_desc};
                if ($arg->{man_desc}) {
                    $$out .= _clean_string($arg, 'man_desc');
                }
            }
            $$out .= "\n";
        }
        if ($cmd->{man_desc}) {
            $$out .= _clean_string($cmd, 'man_desc');
        } else {
            $$out .= $cmd->{cli_desc};
        }
        $$out .= "\n";
    }
}

sub gen_options {
    my $tokens = shift;
    for (sort keys %RepoLocator::option_doc) {
        my $opt = $RepoLocator::option_doc{$_};
        my $token = sprintf("__OPTIONS_%s__", uc $opt->{tag});
        unless ($tokens->{$token}) {
            $tokens->{$token} = '';
        }
        my $out = \$tokens->{$token};
        # if (ref $opt->{default}) {
        #     warn Dumper sprintf("[%s]", join(",", @{$opt->{default}}))
        # }
        $$out .= "\n\n";
        $$out .= sprintf "%s, ENV:*%s*, DEFAULT:*%s*\n",
            $opt->{man_usage} || $opt->{cli_usage},
            $opt->{env} || '--',
            ! defined $opt->{default}
                ? '**NONE**'
                : ref $opt->{default}
                    ? sprintf("[%s]", join(",", @{$opt->{default}}))
                    : $opt->{default} =~ /^1$/
                        ? 'true'
                        : $opt->{default} =~ /^0$/
                            ? 'false'
                            : sprintf('"%s"', $opt->{default})
            ;
        my $desc = $opt->{cli_desc};
        if ($opt->{man_desc}) {
            $desc = _clean_string($opt, 'man_desc');
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

my %tokens;
gen_command(\%tokens);
gen_options(\%tokens);

while (<STDIN>) {
    while (my ($k, $v) = each(%tokens)) {
        s/$k/$v/e;
    }
    print $_;
}
