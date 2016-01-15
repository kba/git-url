package LogUtils;
use strict;
use warnings;
use Term::ANSIColor;

sub __stack_trace {
    my $s = shift;
    my $i = 10;
    while ($i > 1) {
        my @stack = caller $i--;
        last unless @stack;
        $s .= sprintf("\n\t in %s +%s", $stack[1], $stack[2]);
    }
    return $s;
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

sub list_levels
{
    my ($class) = @_;
    return [sort { $LOGLEVELS->{$b} <=> $LOGLEVELS->{$a} } keys %{ $LOGLEVELS }];
}

sub _log
{
    my ($levelName, $class, $fmt, @msgs) = @_;
    if ($LOGLEVELS->{$levelName} >= $LOGLEVELS->{warn}) {
        $fmt = __stack_trace($fmt);
    }
    return if ($LOGLEVELS->{$LOGLEVEL} < $LOGLEVELS->{$levelName});
    return sprintf( "[%s] %s\n",
        colored( uc($levelName), $LOGCOLORS->{$levelName} ),
        sprintf( $fmt, map { StringUtils->dump($_) } @msgs ) );
}
sub set_level { $LOGLEVEL = $_[1]; }
sub trace { printf _log( "trace", @_ ) }
sub debug { printf _log( "debug", @_ ) }
sub info  { printf _log( "info",  @_ ) }
sub warn  { printf _log( "warn",  @_ ) }
sub error { printf _log( "error", @_ ) }
sub log_die { die _log( "error", @_ ); }

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
