#!/usr/bin/perl
use strict; use warnings;

my $libpath;
BEGIN {
    use Cwd qw(realpath);
    use File::Basename qw(dirname);
    $libpath = realpath(dirname(realpath($0)) . "/../lib");
}
use lib $libpath;
use GitUrl::App;

GitUrl::App->new()->exec(\@ARGV);
