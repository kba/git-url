package GitUrl::Utils::Git;
use strict;
use warnings;
use File::Basename qw(dirname);
use Clapp::Utils::SimpleLogger;

my $log = Clapp::Utils::SimpleLogger->get;

sub git_basedir
{
    my ($self, $path) = @_;
    $log->trace("git_dir_for_filename $path");

    if (!-d $path) {
        Clapp::Utils::File->chdir(dirname($path));
    }
    else {
        Clapp::Utils::File->chdir($path);
    }
    my $dir = Clapp::Utils::File->qx('git rev-parse --show-toplevel 2>/dev/null');
    chomp($dir);
    if ($? > 0) {
        $log->trace("git rev-parse failed");
    }
    return $dir;
}

sub git_config
{
    my ($self, $path) = @_;
    $path = sprintf("%s/.git/config", $self->git_basedir($path));
    return $self->_parse_git_config(@{Clapp::Utils::File->slurp($path)});
}

sub git_current_branch
{
    my ($self, $path) = @_;
    Clapp::Utils::File->chdir($self->git_basedir($path));
    return Clapp::Utils::File->qx("git rev-parse --abbrev-ref HEAD");
}

sub git_remote_for_branch
{
    my ($self, $path, $branch) = @_;
    Clapp::Utils::File->chdir($self->git_basedir($path));
    $branch //= $self->git_current_branch($path);
    return Clapp::Utils::File->qx("git config branch.$branch.remote");
}

sub git_remote_url
{
    my ($self, $path, $remote) = @_;
    Clapp::Utils::File->chdir($self->git_basedir($path));
    $remote //= $self->git_remote_for_branch($path);
    return Clapp::Utils::File->qx("git config remote.$remote.url");
}

sub _parse_git_config
{
    my ($self, @lines) = @_;
    my $ret = {};
    my $cur = undef;
    for (@lines) {
        s/^\s*//gmx;
        s/\s*$//gmx;
        if (/\s*\[/) {
            my ($section) = m/\[\s*(.*?)\s*\]/gmx;
            if ($section =~ m/"/gmx) {
                my ($subsection, $name) = m/\[(.*?)\s*"(.*?)"\]/gmx;
                $ret->{$subsection} //= {};
                $cur = $ret->{$subsection}->{$name} = {};
            } else {
                $cur = $ret->{$section} = {};
            }
        } else {
            my ($k, $v) = split(/\s*=\s*/mx);
            $cur->{$k} = $v;
        }
    }
    return $ret;
}

1;
