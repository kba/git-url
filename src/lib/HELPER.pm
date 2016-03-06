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

#---------
#
# Logging
#
#---------
our $LOGLEVEL = 0;
our $PROMPT   = 0;
our $STYLING_ENABLED    = 1;

our $log_levels = {
    'trace' => 3,
    'debug' => 2,
    'info'  => 1,
    'error' => 0,
    'off'   => -1
};

sub _log
{
    my ($_msgs, $levelName, $minLevel, $color) = @_;
    my @msgs = @{$_msgs};
    if ($LOGLEVEL >= $minLevel) {
        printf("[%s] %s\n", colored($levelName, $color), sprintf(shift(@msgs), @msgs));
    }
    return;
}
sub log_trace { return _log(\@_, "TRACE", 3, 'bold yellow'); }
sub log_debug { return _log(\@_, "DEBUG", 2, 'bold blue'); }
sub log_info  { return _log(\@_, "INFO",  1, 'bold green'); }
sub log_error { return _log(\@_, "ERROR", 0, 'bold red'); }
sub log_die { $_[1] .= join( ' ', caller ); log_error(@_); return exit 70; }

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

#---------
#
# HELPER
#
#---------

sub _chdir
{
    my $dir = shift;
    log_debug("cd $dir");
    return chdir $dir;
}

sub _system
{
    my $cmd = shift;
    if ($_[0]) {
        printf("About to execute '%s'\n<Enter> to continue, <Ctrl-C> to stop\n");
        <>;
    } else {
        log_debug("$cmd");
    }
    return system($cmd);
}

sub _qx
{
    my $cmd = shift;
    log_debug("$cmd");
    return qx($cmd);
}

sub _mkdirp
{
    my $dir = shift;
    log_trace("mkdir -p $dir");
    return make_path($dir);
}

sub _slurp
{
    my ($filename) = shift;
    log_trace("cat $filename");
    if (!-r $filename) {
        log_die("File '$filename' doesn't exist or isn't readable.");
    }
    open my $handle, '<', $filename or log_die("Failed to open '$filename' for reading.");
    chomp(my @lines = <$handle>);
    close $handle;
    return \@lines;
}

sub _git_dir_for_filename
{
    my $path = shift;
    if (!-d $path) {
        HELPER::_chdir(dirname($path));
    }
    else {
        HELPER::_chdir($path);
    }
    my $dir = _qx('git rev-parse --show-toplevel 2>&1');
    chomp($dir);
    if ($? > 0) {
        log_error($dir);
    }
    return $dir;
}

#----------------
#
# String helpers
#
#----------------

sub unindent
{
    my ($amount, $str) = @_;
    # $str =~ s/\n*\z//mx;
    # $str =~ s/\A\n+//mx;
    $str =~ s/^\x20{$amount}//mxg;
    return $str;
}

sub human_readable_default
{
    my ($val) = @_;
    return !defined $val
      ? 'NONE'
      : ref $val ? ref $val eq 'ARRAY'
          ? sprintf("[%s]", join(",", @{$val}))
          : HELPER::log_die 'Unsupported ref type ' . ref $val
      : $val =~ /^1$/mx ? 'true'
      : $val =~ /^0$/mx ? 'false'
      :                 sprintf('"%s"', $val);
}

our $styles = {
    'option'      => 'magenta bold',
    'default'     => 'black bold',
    'command'     => 'green bold',
    'arg'         => 'yellow bold',
    'optarg'      => 'yellow italic',
    'script-name' => 'blue bold',
    'heading'     => 'underline',
    'error'       => 'bold red',
};

sub style
{
    my ($style, $str, @args) = @_;
    my $out = sprintf($str, @args);
    if ($STYLING_ENABLED) {
        unless ($styles->{$style}) {
            log_die("Unknown style '$style' at " . join(' ', caller));
        }
        $out = colored($out, $styles->{$style});
    }
    return $out;
}

#-------------
#
# OOP Helpers
#
#-------------

sub validate_required_methods
{
    my ($cls, @required_methods) =@_;
    my @missing_methods;
    for (@required_methods) {
        unless ($cls->can($_)) {
            push @missing_methods, $_;
        }
    }
    if ($missing_methods[0]) {
        HELPER::log_die(sprintf("Class '%s' is missing methods [%s]", $cls, join(',', @missing_methods)));
    }
    return;
}

sub validate_required_args
{
    my ($cls, $required_attrs, %_self) = @_;
    my @missing;
    for (@{$required_attrs}) {
        unless (exists $_self{$_}) {
            push @missing, $_;
        }
    }
    if ($missing[0]) {
        HELPER::log_die(
            sprintf(
                "Missing args [%s] for '%s' constructor: %s",
                join(',', @missing), $cls, Dumper(\%_self)));
    }
    return;
}

sub validate_known_args
{
    my ($cls, $known_attrs, %_self) = @_;
    my @unknown;
    my %known = map {$_ => $_} @{$known_attrs};
    for (keys %_self) {
        unless (defined $known{$_}) {
            push @unknown, $_;
        }
    }
    if ($unknown[0]) {
        HELPER::log_die(
            sprintf(
                "Unknown args [%s] for '%s' constructor: %s",
                join(',', @unknown), $cls, Dumper(\%_self)));
    }
    return;
}

1;
