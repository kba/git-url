package CliApp::FileUtils;
use strict;
use warnings;

use CliApp::SimpleLogger;
my $log = CliApp::SimpleLogger->new;

#---------
#
# HELPER
#
#---------

sub chdir
{
    my ($class, $dir) = @_;
    $log->debug("cd $dir");
    return chdir $dir;
}

sub system
{
    my ($class, $cmd) = @_;
    $log->debug("$cmd");
    return system($cmd);
}

sub qx
{
    my ($class, $cmd) = @_;
    $log->debug("$cmd");
    return qx($cmd);
}

sub mkdirp
{
    my ($class, $dir) = @_;
    $log->trace("mkdir -p $dir");
    return make_path($dir);
}

sub slurp
{
    my ($class, $filename) = @_;
    $log->trace("cat $filename");
    if (!-r $filename) {
        $log->die("File '$filename' doesn't exist or isn't readable.");
    }
    open my $handle, '<', $filename or $log->die("Failed to open '$filename' for reading.");
    chomp(my @lines = <$handle>);
    close $handle;
    return \@lines;
}

sub git_dir_for_filename
{
    my ($class, $path) = @_;
    if (!-d $path) {
        $log->chdir(dirname($path));
    }
    else {
        $log->chdir($path);
    }
    my $dir = _qx('git rev-parse --show-toplevel 2>&1');
    chomp($dir);
    if ($? > 0) {
        $log->error($dir);
    }
    return $dir;
}

1;
