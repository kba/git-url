package GitUrl::Utils::Git;
use strict;
use warnings;
use parent 'Clapp::Utils';
use File::Basename qw(dirname);

sub git_basedir
{
    my ($self, $path) = @_;
    $self->log->trace("git_dir_for_filename $path");

    if (!-d $path) {
        $self->app->get_utils("file")->chdir(dirname($path));
    }
    else {
        $self->app->get_utils("file")->chdir($path);
    }
    my $dir = $self->app->get_utils("file")->qx('git rev-parse --show-toplevel 2>/dev/null');
    chomp($dir);
    if ($? > 0) {
        $self->log->trace("git rev-parse failed");
    }
    return $dir;
}

sub git_config
{
    my ($self, $path) = @_;
    $path = sprintf("%s/.git/config", $self->git_basedir($path));
    return $self->_parse_git_config(@{$self->app->get_utils("file")->slurp($path)});
}

sub git_current_branch
{
    my ($self, $path) = @_;
    $self->app->get_utils("file")->chdir($self->git_basedir($path));
    return $self->app->get_utils("file")->qx("git rev-parse --abbrev-ref HEAD");
}

sub git_remote_for_branch
{
    my ($self, $path, $branch) = @_;
    $self->app->get_utils("file")->chdir($self->git_basedir($path));
    $branch //= $self->git_current_branch($path);
    return $self->app->get_utils("file")->qx("git config branch.$branch.remote");
}

sub git_remote_url
{
    my ($self, $path, $remote) = @_;
    $self->app->get_utils("file")->chdir($self->git_basedir($path));
    $remote //= $self->git_remote_for_branch($path);
    return $self->app->get_utils("file")->qx("git config remote.$remote.url");
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
