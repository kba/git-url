package HELPER;
use strict;
use warnings;
use Term::ANSIColor;
use File::Path qw(make_path);
use File::Basename qw(dirname);
use Data::Dumper;
$Data::Dumper::Terse = 1;
our $SCRIPT_NAME = "__SCRIPT_NAME__";
our $VERSION     = "__VERSION__";
our $BUILD_DATE  = "__BUILD_DATE__";
our $LAST_COMMIT = "__LAST_COMMIT__";

sub require_config
{
    my ($config, @keys) = @_;
    my $die_flag;
    for my $key (@keys) {
        unless (defined $config->{$key}) {
            log_error("This feature requires the '$key' config setting to be set.");
            $die_flag = 1;
        }
    }
    if ($die_flag) {
        log_die("Unmet config requirements at" . join(' ', caller));
    }
    return;
}

sub require_location
{
    my ($location, @keys) = @_;
    my $die_flag;
    for my $key (@keys) {
        unless (defined $location->{$key}) {
            log_error("This feature requires the '$key' location information but it wasn't detected.");
            $die_flag = 1;
        }
    }
    if($die_flag) {
        log_die("Unmet location requirements at " . join(' ', caller)) ;
    }
    return;
}



1;
