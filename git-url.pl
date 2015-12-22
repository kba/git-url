#!/usr/bin/perl
use File::Basename qw(basename);

our $SCRIPT_NAME = "__SCRIPT_NAME__";
our $VERSION = "__VERSION__";
our $BUILD_DATE = "__BUILD_DATE__";

package RepoLocator;
use strict;
use warnings;
use Data::Dumper;
$Data::Dumper::Terse = 1;
use File::Path qw(make_path);
use Term::ANSIColor;
use File::Basename qw(dirname);
use File::Spec::Functions qw(rel2abs);

our $DEBUG = 1;
our $CONFIG_FILE = join('/', $ENV{HOME}, '.config', $SCRIPT_NAME, 'config.ini');

#---------
#
# Logging
#
#---------

sub __log {
    my ($msg, $levelName, $minLevel, $color) = @_;
    if ($DEBUG >= $minLevel) {
        printf("[" . color($color) . $levelName . color('reset') . "] $msg\n");
    }
}
sub _log_trace { __log(shift, "TRACE", 3, 'bold yellow'); }
sub _log_debug { __log(shift, "DEBUG", 2, 'bold blue'); }
sub _log_info  { __log(shift, "INFO", 1, 'bold blue'); }
sub _log_error { __log(shift, "ERROR", 0, 'bold red'); }
sub _log_die   { _log_error(shift); exit 70; }
sub _require_config {
    my ($config, @keys) = @_;
    my $die_flag;
    for my $key (@keys) {
        unless (defined $config->{$key}) {
            _log_error("This feature requires the '$key' config setting to be set.");
            $die_flag = 1;
        }
    }
    _log_die("Unmet config requirements") if $die_flag;
}
sub _require_location {
    my ($location, @keys) = @_;
    my $die_flag;
    for my $key (@keys) {
        unless (defined $location->{$key}) {
            _log_die("This feature requires the '$key' location information but it wasn't detected.");
            $die_flag = 1;
        }
    }
    _log_die("Unmet location requirements") if $die_flag;
}

#---------
#
# Helpers
#
#---------

sub _chdir {
    my $dir = shift;
    _log_debug("cd $dir");
    chdir $dir;
}

sub _system {
    my $cmd = shift;
    _log_debug("$cmd");
    return system($cmd);
}
sub _qx {
    my $cmd = shift;
    _log_debug("$cmd");
    return qx($cmd);
}
sub _mkdirp {
    my $dir = shift;
    _log_trace("mkdir -p $dir");
    make_path($dir);
}

sub _slurp {
    my $filename = shift;
    _log_trace("cat $filename");
    if (! -r $filename) {
        _log_die("File '$filename' doesn't exist or isn't readable.");
    }
    open my $handle, '<', $filename;
    chomp(my @lines = <$handle>);
    close $handle;
    return \@lines;
}

#--------
#
# Config
#
#--------

my $default_config = {
    baseDir     => $ENV{GITDIR}  || $ENV{HOME} . '/build',
    editor      => $ENV{EDITOR}  || 'vim',
    browser     => $ENV{BROWSER} || 'chromium',
    shell       => $ENV{SHELL}   || 'bash',
    github_user => $ENV{GITHUB_USER}
};

sub _load_config {
    my $self = shift;
    my $config = $default_config;
    if (-r $CONFIG_FILE) {
        my @lines = @{_slurp $CONFIG_FILE};
        for (@lines) {
            s/^\s+|\s+$//g;
            next if /^$/;
            next if /^[#;]/;
            my ($k, $v) = split /\s*=\s*/;
            $config->{$k} = $v;
        }
    }
    # make sure baseDir exists
    _mkdirp($config->{baseDir});
    return $config;
}

sub _parse_config_file {
    my $self = shift;
    my $config = shift;
}

sub _clone_command {
    my ($self) = @_;
    if ($self->{host} =~ /git/) {
        return join('',
            'git clone --depth 1 ',
            'https://',
            join('/',
                $self->{host},
                $self->{owner},
                $self->{repo_name}
            ));
    } else {
        die 'Unknown repository type for ' . Dumper($self->{host});
    }
}

sub _edit_command {
    my ($self) = @_;
    my $cmd = join(' ',
        $self->{config}->{editor},
        $self->{path_within_repo});
    if ($self->{line}) {
        my ($line) = $self->{line} =~ /(\d+)/;
        if ($self->{config}->{editor} =~ 'vi') {
            $cmd .= " +$line";
        }
    }
    return $cmd;
}

sub _parse_github {
    my ($self, $location, $path) = @_;
    _log_info("Interpreting '$path' as Github shortcut");
    if (index($path, '/') == -1) {
        _log_debug("Prepending " . $self->{config}->{github_user});
        _require_config($self->{config}, 'github_user');
        $path = $self->{config}->{github_user} . '/' . $path;
    }
    return $self->_parse_url($location, "https://github.com/$path");
}

sub _parse_filename {
    my ($self, $location, $path) = @_;
    unless ($path) {
        _log_die("No path given");
    }
    # split path into filename:line:column
    ($path, $location->{line}, $location->{column}) = split(':', $path);
    if (! -e $path) {
        _log_info("No such file/directory: $path");
        return $self->_parse_github($location, $path);
    }
    $path = rel2abs($path);
    if (! -d $path) {
        _chdir(dirname($path));
    } else {
        _chdir($path);
    }
    my $dir = _qx('git rev-parse --show-toplevel 2>&1');
    chomp($dir);
    if ($? > 0) {
        _log_die($dir);
    }
    $location->{path_to_repo} = $dir;
    $location->{path_within_repo} = substr($path, length($dir)) || '.';
    $location->{path_within_repo} =~ s@^/@@;

    my $gitconfig = join('/', $location->{path_to_repo}, '.git', 'config');
    my @lines = @{_slurp $gitconfig};
    my $baseURL;
    OUTER:
    while (my $line = shift(@lines)) {
        if ($line =~ /\[remote .origin.\]/) {
            while (my $line = shift(@lines)) {
                if ($line =~ '^\s*url') {
                    ($baseURL) = $line =~ / = (.*)/;
                    last OUTER;
                }
            }
        }
    }
    if (! $baseURL) {
        _log_die("Couldn't find a remote");
    }
    $self->_parse_url($location, $baseURL);
}

sub _parse_url {
    my ($self, $location, $url) = @_;
    _log_debug("Parsing URL: $url");
    $location->{url} = $url;
    $url =~ s,^(https?://|git@),,;
    $url =~ s,:,/,;
    my @url_parts = split(/\//, $url);
    $location->{host} = $url_parts[0];
    $location->{owner} = $url_parts[1];
    $location->{repo_name} = $url_parts[2];
    $location->{repo_name} =~  s/\.git$//;
    ($url_parts[$#url_parts], $location->{line}) = split('#', $url_parts[$#url_parts]);
    if ($url_parts[3] && $url_parts[3] eq 'blob') {
        $location->{branch} = $url_parts[4];
        $location->{path_within_repo} = join('/', @url_parts[5..$#url_parts]);
    }
    return $location;
}

sub _deparse_url {
    my ($self, $location) = @_;
    $location->{browse_url} = 'https://' .  join('/',
        $location->{host},
        $location->{owner},
        $location->{repo_name},
    );
    if ( $location->{path_within_repo} !~ '^\.?$') {
        $location->{browse_url} .= join('/',
            '',
            'blob',
            $location->{branch},
            $location->{path_within_repo});
    }
}


sub _clone_repo {
    my ($self) = @_;
    _require_location($self, 'host', 'owner', 'repo_name');
    my $ownerDir = join('/', $self->{config}->{baseDir}, $self->{host}, $self->{owner});
    _mkdirp($ownerDir);
    _chdir $ownerDir;
    my $repoDir = join('/', $ownerDir, $self->{repo_name});
    my $cloneCmd = $self->_clone_command();
    if (! -d $repoDir) {
        my $output = _system($cloneCmd . ' 2>&1');
        if ($? > 0) {
            _log_die("'$cloneCmd' failed with '$?': " . $output);
        }
    }
    if (! -d $repoDir) {
        warn "'$cloneCmd' failed silently for " . Dumper($self->{url});
        return;
    }
    $self->{path_to_repo} = $repoDir;
}


#-------------
#
# Constructor
#
#-------------

sub new {
    my $class = shift;
    my @args = @_;

    my $self = bless {}, $class;

    $self->{config} = $self->_load_config();
    my $location = {
        path_within_repo => '.',
        branch => 'master'
    };
    if ($args[0] =~ /^(https?:|git@)/) {
        $self->_parse_url($location, $args[0]);
    } else {
        $self->_parse_filename($location, $args[0]);
    }
    $self->_deparse_url($location);
    while (my ($k, $v) = each(%{$location})) {
        $self->{$k} = $v;
    }
    if ($DEBUG > 1) {
        _log_trace("Parsed as: ". Dumper $self);
    }

    return $self;
}

#=================
#
# Public API
#
#=================

sub edit {
    my ($self) = @_;
    $self->_clone_repo();
    _require_location($self, 'path_to_repo');
    _chdir($self->{path_to_repo});
    my $editCmd = $self->_edit_command();
    _system($editCmd);
}

sub url {
    my ($self) = @_;
    _require_location($self, 'browse_url');
    print $self->{browse_url} . "\n";
}

sub shell {
    my ($self) = @_;
    $self->_clone_repo();
    _require_location($self, 'path_to_repo');
    _chdir $self->{path_to_repo};
    _system $self->{config}->{shell};
}

sub tmux {
    my ($self) = @_;
    $self->_clone_repo();
    _require_location($self, 'path_to_repo');
    _chdir $self->{path_to_repo};
    _system "tmux attach -d " + $self->{repo_name};
    if ($?) {
        _system "tmux new -s " + $self->{repo_name};
    }
}

sub browse {
    my ($self) = @_;
    _require_location($self, 'browse_url');
    _system($self->{config}->{browser} . " " . $self->{browse_url});
}

package main;
use Data::Dumper;
local $Data::Dumper::Terse = 1;
use Term::ANSIColor;

sub about {
    print "Version: $VERSION\n";
    print "Build Date: $BUILD_DATE\n";
}

sub usage {
    print "Usage: ";
    print color('bold blue');
    print $SCRIPT_NAME;
    print color('bold magenta');
    print " [--debug]";
    print color('bold green');
    print " <command>";
    print color('bold yellow');
    print " <url|filename>";
    print "\n";
    print color('reset');

    print "\nOptions:";
    print "\n\t" . color('bold magenta') . '--debug[=<trace|debug|info|error>]' . color('reset');
    print " " . "Default: 'debug'";

    print "\nCommands:";
    print "\n\t" . color('bold green') . 'edit' . color('reset');
    print "\t" . 'Edit the file';
    print "\n\t" . color('bold green') . 'browse' . color('reset');
    print "\t" . 'Open the browser to this file';
    print "\n\t" . color('bold green') . 'url' . color('reset');
    print "\t" . 'Get the URL to this file in the online repository.';
    print "\n\t" . color('bold green') . 'shell' . color('reset');
    print "\t" . 'Open a shell in the local repository directory';
    print "\n\t" . color('bold green') . 'tmux' . color('reset');
    print "\t" . 'Attach to or create a tmux session named like the repository.';
    print "\n\t" . color('bold green') . 'about' . color('reset');
    print "\t" . 'Print about info.';
}

my @ARGV_PROCESSED;
while (my $arg = shift(@ARGV)) {
    if ($arg =~ '--debug') {
        my $minLevel = [split('=', $arg)]->[1] // 'debug';
        $minLevel =~ s/^trace$/3/;
        $minLevel =~ s/^debug$/2/;
        $minLevel =~ s/^info$/1/;
        $minLevel =~ s/^error$/0/;
        $RepoLocator::DEBUG = $minLevel;
    } else {
        push @ARGV_PROCESSED, $arg;
    }
}
my $command = shift(@ARGV_PROCESSED);
if (! $command)            { usage; exit 1; }
if ($command eq 'about')   { about; exit 0; }
if ( ! $ARGV_PROCESSED[0]) { usage; exit 1; }
my $loc = new RepoLocator(@ARGV_PROCESSED);
unless ($loc->can($command)) {
    print "Unknown command: '$command'\n";
    usage;
    exit 1;
}
$loc->$command();
