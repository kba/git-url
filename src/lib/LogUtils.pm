package LogUtils;
use Term::ANSIColor;
use Data::Dumper;
$Data::Dumper::Terse = 1;

sub __caller_source {
    my @cpy = @_;
    my $i = 10;
    my $args = [];
    while (!@{$args[0]} && $i > 1) {
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
our $LOGLEVEL    = 3;

our $LOGLEVELS = {
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
    shift @msgs;
    if ($LOGLEVEL >= $minLevel) {
        printf("[%s] %s\n", colored($levelName, $color), sprintf(shift(@msgs), @msgs));
    }
    return;
}
sub log_trace { return _log(\@_, "TRACE", 3, 'bold yellow'); }
sub log_debug { return _log(\@_, "DEBUG", 2, 'bold blue'); }
sub log_info  { return _log(\@_, "INFO",  1, 'bold green'); }
sub log_error { return _log(__caller_source(@_), "ERROR", 0, 'bold red' ); }
sub log_die { log_error(@{__caller_source(@_)}); return exit 70; }
sub dump { shift; return Dumper(@_); }


#---------
#
# HELPER
#
#---------

sub log_chdir
{
    my ($cls, $dir) = @_;
    LogUtils->log_debug("cd $dir");
    return chdir $dir;
}

sub log_system
{
    my ($cls, $cmd) = @_;
    LogUtils->log_debug("$cmd");
    return system($cmd);
}

sub log_qx
{
    my ($cls, $cmd) = @_;
    LogUtils->log_debug("$cmd");
    return qx($cmd);
}

sub log_mkdirp
{
    my ($cls, $dir) = @_;
    LogUtils->log_trace("mkdir -p $dir");
    return make_path($dir);
}

sub log_slurp
{
    my ($cls, $filename) = @_;
    LogUtils->log_trace("cat $filename");
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
    my ($cls, $path) = @_;
    if (!-d $path) {
        LogUtils->log_chdir(dirname($path));
    }
    else {
        LogUtils->log_chdir($path);
    }
    my $dir = _qx('git rev-parse --show-toplevel 2>&1');
    chomp($dir);
    if ($? > 0) {
        LogUtils->log_error($dir);
    }
    return $dir;
}
