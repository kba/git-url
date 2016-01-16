package GitUrl::App;
use strict;
use warnings;
use parent 'CliApp::App';

use Cwd qw(getcwd realpath);
use File::Basename qw(dirname);

use GitUrl::Plugin::giturl;
use GitUrl::Plugin::bitbucket;

sub new {
    my ($class, %self) = @_;

    my $self = $class->SUPER::new(
        version => '__VERSION__',
        build_date => '__BUILD_DATE__',
        name => 'git-url',
        synopsis => 'Work with Git platforms',
        tag => 'app',
        plugins => [
            'CliApp::Plugin::cliapp',
            'GitUrl::Plugin::giturl',
            'GitUrl::Plugin::bitbucket',
        ],
        %self,
    );

    return $self;
}

sub parse_location {
    my ($self, $loc) = @_;
    unless ($loc) {
        $loc = realpath getcwd;
    }
    if ($loc =~ /^(https?:|git@)/mx) {
        $self->_parse_url($loc);
    }
    else {
        $self->_parse_filename($loc);
    }
    $self->_reset_urls();
}

sub _parse_filename
{
    my ($self, $path) = @_;
    $self->log->trace("Parsing filename $path");
    my $loc = {};

    # split path into filename:line:column
    ($path, $loc->{line}, $loc->{column}) = split(':', $path);
    if (!-e $path) {
        $self->log->info("No such file/directory: $path");
        $self->log->info(sprintf("Interpreting '%s' as '%s' shortcut", $path, $self->config->{clone}));
        return $self->_parse_url($self->get_plugin($self->config->{clone})->to_url($self, $path));
    }
    $path = File::Spec->rel2abs($path);
    my $dir = HELPER::_git_dir_for_filename($path);
    unless ($dir) {
        $self->log->log_die("Not in a Git dir: '$path'");
    }
    $self->{path_to_repo} = $dir;
    $self->{path_within_repo} = substr($path, length($dir)) || '.';
    $self->{path_within_repo} =~ s,^/,,mx;

    my $gitconfig = join('/', $self->{path_to_repo}, '.git', 'config');
    my @lines = @{ HELPER::_slurp $gitconfig};
    my $baseURL;
    OUTER:
    while (my $line = shift(@lines)) {
        if ($line =~ /\[remote\s+.origin.\]/mx) {
            while (my $line = shift(@lines)) {
                if ($line =~ /^\s*url/mx) {
                    ($baseURL) = $line =~ / = (.*)/mx;
                    last OUTER;
                }
            }
        }
    }
    if (!$baseURL) {
        $self->log->log_die("Couldn't find a remote");
    }
    $self->_parse_url($baseURL);
    return;
}

# my $app = GitUrl::App->new();
# use Data::Dumper;
# print Dumper \@ARGV;
# $app->exec(\@ARGV);

1;
