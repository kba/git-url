package Clapp::Utils::File;
use strict;
use warnings;

use parent 'Clapp::Utils';

use Clapp::Utils::SimpleLogger;
my $log = Clapp::Utils::SimpleLogger->new;

#---------
#
# HELPER
#
#---------

sub chdir
{
    my ($self, $dir) = @_;
    $self->log->debug("cd $dir");
    return chdir $dir;
}

sub system
{
    my ($self, $cmd) = @_;
    $self->log->debug("$cmd");
    return system($cmd);
}

sub qx
{
    my ($self, $cmd) = @_;
    $self->log->debug("$cmd");
    return qx($cmd);
}

sub mkdirp
{
    my ($self, $dir) = @_;
    $self->log->trace("mkdir -p $dir");
    return make_path($dir);
}

sub slurp
{
    my ($self, $filename) = @_;
    $self->log->trace("cat $filename");
    if (!-r $filename) {
        $self->log->die("File '$filename' doesn't exist or isn't readable.");
    }
    open my $handle, '<', $filename or $self->log->log_die("Failed to open '$filename' for reading.");
    chomp(my @lines = <$handle>);
    close $handle;
    return \@lines;
}


1;
