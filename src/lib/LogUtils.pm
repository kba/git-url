package LogUtils;
use strict;
use warnings;
use Term::ANSIColor;

sub __caller_source {
    my @cpy = @_;
    my $i = 10;
    my $args = [];
    while (!$args->[0] && $i > 1) {
        $args = [caller $i--];
    }
    if (@{$args}) {
        $cpy[1] .= sprintf("\n\t in %s +%s", $args->[1], $args->[2]);
    }
    return [@cpy];
}

#---------
#
# Logging
#
#---------
our $LOGLEVEL = 'debug';
our $LOGLEVELS = {
    'off'   => -1,
    'error' => 0,
    'warn'  => 1,
    'info'  => 2,
    'debug' => 3,
    'trace' => 4,
};
our $LOGCOLORS = {
    'error' => 'bold red',
    'warn'  => 'bold yellow',
    'info'  => 'bold green',
    'debug' => 'bold blue',
    'trace' => 'blue',
};

sub _log
{
    my ($levelName, $_msgs) = @_;
    # warn StringUtils->dump( \@_ );
    my @msgs = @{$_msgs};
    shift @msgs;
    if ($LOGLEVELS->{$LOGLEVEL} >= $LOGLEVELS->{$levelName}) {
        my $fmt = shift @msgs;
        my @sprintf_values = map { StringUtils->dump($_) } @msgs;
        printf("[%s] %s\n", colored(uc($levelName), $LOGCOLORS->{$levelName}), sprintf($fmt, @sprintf_values));
    }
    return;
}
sub set_level { $LOGLEVEL = $_[1]; }
sub trace { return _log( "trace", \@_); }
sub debug { return _log( "debug", \@_); }
sub info  { return _log( "info" , \@_); }
sub warn  { return _log( "warn" , \@_); }
sub error { return _log( "error",  __caller_source(@_)); }
sub log_die { error(@{__caller_source(@_)}); return die 70; }


#---------
#
# HELPER
#
#---------

sub log_chdir
{
    my ($class, $dir) = @_;
    LogUtils->debug("cd $dir");
    return chdir $dir;
}

sub log_system
{
    my ($class, $cmd) = @_;
    LogUtils->debug("$cmd");
    return system($cmd);
}

sub log_qx
{
    my ($class, $cmd) = @_;
    LogUtils->debug("$cmd");
    return qx($cmd);
}

sub log_mkdirp
{
    my ($class, $dir) = @_;
    LogUtils->trace("mkdir -p $dir");
    return make_path($dir);
}

sub log_slurp
{
    my ($class, $filename) = @_;
    LogUtils->trace("cat $filename");
    if (!-r $filename) {
        LogUtils->log_die("File '$filename' doesn't exist or isn't readable.");
    }
    open my $handle, '<', $filename or LogUtils->log_die("Failed to open '$filename' for reading.");
    chomp(my @lines = <$handle>);
    close $handle;
    return \@lines;
}

sub log_git_dir_for_filename
{
    my ($class, $path) = @_;
    if (!-d $path) {
        LogUtils->log_chdir(dirname($path));
    }
    else {
        LogUtils->log_chdir($path);
    }
    my $dir = _qx('git rev-parse --show-toplevel 2>&1');
    chomp($dir);
    if ($? > 0) {
        LogUtils->error($dir);
    }
    return $dir;
}
