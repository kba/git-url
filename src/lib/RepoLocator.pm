package RepoLocator;
use strict;
use warnings;
use HELPER;
use Data::Dumper;
use File::Spec;
use List::MoreUtils qw(uniq);
use Carp qw(croak carp);
use Term::ANSIColor;
$Data::Dumper::Terse = 1;
our $CONFIG_FILE = join('/', $ENV{HOME}, '.config', $HELPER::SCRIPT_NAME, 'config.ini');

use RepoLocator::Command;
use RepoLocator::Option;
use RepoLocator::Plugin::Bitbucket;
use RepoLocator::Plugin::Github;
use RepoLocator::Plugin::Gitlab;

#====================================================
#{{{ Options

my %option_doc = ();

sub get_option
{
    my ($cls, $option) = @_;
    return $option_doc{$option};
}

sub list_options
{
    my @options = sort keys %option_doc;
    return wantarray ? @options : \@options;
}

sub add_option
{
    my ($cls, %opt_args) = @_;
    my $opt = RepoLocator::Option->new(%opt_args);
    return $option_doc{$opt->{name}} = $opt;
}

#}}}
#====================================================

#====================================================
#{{{ Commands

my %command_doc = ();

sub get_command
{
    my ($cls, $command) = @_;

    # TODO shortcuts
    return $command_doc{$command};
}

sub list_commands
{
    my @commands = sort keys %command_doc;
    return wantarray ? @commands : \@commands;
}

sub add_command
{
    my $cls = shift;
    my $cmd;
    if (! ref($_[0])) {
    my $pkg = shift;
    $cmd = $pkg->new();
    } else {
    my $hash = $_[0];
    my (%cmd_args) = %{ $hash };
    $cmd = RepoLocator::Command->new(%cmd_args);
    }
    return $command_doc{$cmd->{name}} = $cmd;
}

#}}}
#====================================================

#====================================================
#{{{ Plugins

my %plugin_doc;

sub get_plugin
{
    my ($cls, $plugin) = @_;
    return $plugin_doc{$plugin};
}

sub list_plugins
{
    my @plugins = sort keys %plugin_doc;
    return wantarray ? @plugins : \@plugins;
}

sub add_plugin
{
    my ($cls, $plugin_cls, @args) = @_;
    my $plugin = $plugin_cls->new(@args);
    $plugin->add_options($cls);
    for ($plugin->list_hosts) {
    $plugin_doc{$_} = $plugin;
    }
    return $plugin;
}
#}}}
#====================================================

#====================================================
#{{{ Tags

sub list_tags
{
    my ($cls) = @_;
    my %ret;
    for ($cls->list_options()) {
    $ret{ $cls->get_option($_)->{tag} } = 1;
    }
    my @tags = sort keys %ret;
    return wantarray ? @tags : \@tags;
}

#}}}
#====================================================

#====================================================
#{{{ Private API - Instance

#{{{ _load_config
sub _load_config
{
    my ($self, $cli_config) = @_;

    my $config     = {};
    for ($self->list_options()) {
        $config->{$_} = $self->get_option($_)->{default};
    }
    if (-r $CONFIG_FILE) {
        my @lines = @{ HELPER::_slurp($CONFIG_FILE) };
        for (@lines) {
            s/^\s+|\s+$//gmx;
            next if (/^$/mx || /^[#;]/mx);
            my ($k, $v) = split /\s*=\s*/mx;
            if ($option_doc{$k}->{csv}) {
                my @split_values;
                for (split(/\s*,\s*/mx, $v)) {
                    s/~/$ENV{HOME}/mx;
                    s/\/$//mx;
                    push @split_values, $_;
                }
                $v = \@split_values;
            }
            $config->{$k} = $v;
        }
    }
    while (my ($k, $v) = each(%{$cli_config})) {
    $config->{$k} = $v;
    }

    # set log level
    $HELPER::LOGLEVEL = $HELPER::log_levels->{ $config->{loglevel} };
    # set prompt behavior
    $HELPER::PROMPT = $config->{prompt};
    # set styling behavior
    $HELPER::STYLING_ENABLED = $config->{color};

    # make sure base_dir exists
    HELPER::_mkdirp($config->{base_dir});
    return $config;
}
#}}}

#{{{ _all_repo_dirs
sub _all_repo_dirs
{
    my $self = shift;
    # TODO this should not be necessary
    my @alldirs = @{$self->{config}->{repo_dirs}};
    push(@alldirs, $self->{config}->{base_dir});
    return [uniq @alldirs];
}
#}}}

#{{{ _get_clone_url_ssh_owner_reponame
sub _get_clone_url_ssh_owner_reponame
{
    my $self = shift;
    return
    'git@'
      . $self->{host} . ':'
      . join(
    '/',
    $self->{owner},
    $self->{repo_name});
}
#}}}

#{{{ _get_clone_url_https_owner_reponame
sub _get_clone_url_https_owner_reponame
{
    my $self = shift;
    return 'https://'
      . join(
    '/',
    $self->{host},
    $self->{owner},
    $self->{repo_name});
}
#}}}

#{{{ _clone_command
sub _clone_command
{
    my ($self) = @_;
    return join(
    ' ',
    'git clone',
    $self->{config}->{clone_opts},
    $self->{clone_url});
}
#}}}

#{{{ _edit_command
sub _edit_command
{
    my ($self) = @_;
    my $cmd = join(
    ' ',
    $self->{config}->{editor},
    $self->{path_within_repo});
    if ($self->{linenumber}) {
    my ($linenumber) = $self->{linenumber} =~ /(\d+)/mx;
    if ($self->{config}->{editor} =~ /vi/mx) {
        $cmd .= " +$linenumber";
    }
    }
    return $cmd;
}
#}}}

#{{{ shortcut_to_url
#
# Parses a string to a repository URL.
#
# String delimiter is '/' (slash).
#
sub shortcut_to_url
{
    my ($self, $path) = @_;
    my $platform_user = $self->{config}->{platform};
    $platform_user =~ s/[^a-zA-Z0-9_].*//xm;
    $platform_user .= '_user';

    my @slash_segments = split('/', $path);
    my $nr_of_slashes = scalar(@slash_segments) - 1;

    my ($repo_name, $org, $host, $path_within_repo);

    if ($nr_of_slashes == 0) {
        ($repo_name) = @slash_segments;
    } elsif ($nr_of_slashes == 1) {
        ($org, $repo_name) = @slash_segments;
    } elsif ($nr_of_slashes == 2 && $slash_segments[0] =~ m/git(hub|lab)/) {
        ($host, $org, $repo_name) = @slash_segments;
    } else {
        $org = shift(@slash_segments);
        $repo_name = shift(@slash_segments);
        $path_within_repo = join('/', @slash_segments);
    }

    if (! $org) {
        HELPER::log_debug("Prepending $platform_user " . $self->{config}->{$platform_user});
        HELPER::require_config($self->{config}, $platform_user);
        $org = $self->{config}->{$platform_user};
    }
    if (! $host) {
        $host = $self->{config}->{platform};
    }

    # XXX hard-coded
    HELPER::log_debug("Parsed as " . "https://$host/$org/$repo_name");
    return "https://$host/$org/$repo_name";
}
#}}}

#{{{ _parse_filename
sub _parse_filename
{
    my ($self, $path) = @_;
    HELPER::log_trace("Parsing filename $path");
    unless ($path) {
    HELPER::log_die("No path given");
    }

    # split path into filename:line:column
    ($path, $self->{linenumber}, $self->{column}) = split(':', $path);
    # XXX check too strict
    if (! -e $path) {
        HELPER::log_debug("No such file/directory: $path");
        HELPER::log_info("Parsing '%s' as a shortcut", $path);
        return $self->_parse_url($self->shortcut_to_url($path));
    }
    $path = File::Spec->rel2abs($path);
    my $dir = HELPER::_git_dir_for_filename($path);
    unless ($dir) {
        HELPER::log_die("Not in a Git dir: '$path'");
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
                ($baseURL) = $line =~ /=\s*([^\s]*)/mx;
                last OUTER;
            }
        }
    }
    }
    if (!$baseURL) {
        HELPER::log_die("Couldn't find a remote");
    }
    $self->_parse_url($baseURL);
    return;
}
#}}}

#{{{ _parse_url
#
# Parse a string as a URL-ish location.
#
sub _parse_url
{
    my ($self, $url) = @_;
    HELPER::log_trace("Parsing URL: $url");
    $self->{url} = $url;
    $url =~ s,^(https?://|git@),,mx;
    $url =~ s,:,/,mx;
    my @url_parts = split(/\//mx, $url);
    $self->{host}      = $url_parts[0];
    $self->{owner}     = $url_parts[1];

    if ($self->{host} =~ /@/mx) {
    my ($auth, $host) = split /@/mx, $self->{host};
    # my ($user, $pass) = split /:/mx, $auth;
    $self->{host} = $host;
    }

    $self->{repo_name} = $url_parts[2];
    $self->{repo_name} =~ s/\.git$//mx;
    ($url_parts[-1], $self->{line}) = split('#', $url_parts[-1]);

    if ($url_parts[3] && $url_parts[3] eq 'blob') {
        $self->{branch} = $url_parts[4];
        $self->{path_within_repo} = join('/', @url_parts[ 5 .. $#url_parts ]);
        HELPER::log_trace("Parsed URL '$url'");
    }
    return $self;
}
#}}}

#{{{ _should_use_ssh
sub _should_use_ssh
{
    my ($self) = @_;
    if (my $plugin = $self->get_plugin($self->{host})) {
        if ($self->{config}->{prefer_ssh}) {
            if ($self->{owner}) {
                return $self->{owner} eq $plugin->get_username($self);
            }
        }
    }
}
#}}}

#{{{ _set_clone_url
#
# Set the URL for cloning the repo.
#
sub _set_clone_url
{
    my ($self) = @_;
    HELPER::log_trace("Setting clone URL");
    HELPER::require_location($self, 'host', 'owner', 'repo_name');
    if ($self->{host} =~ /github|gitlab|bitbucket/mx) {
        # TODO move this out
        if ($self->_should_use_ssh)
        {
            $self->{clone_url} = $self->_get_clone_url_ssh_owner_reponame();
        } else {
            $self->{clone_url} = $self->_get_clone_url_https_owner_reponame();
        }
    } else {
        HELPER::log_die('Unknown repository tag for ' . Dumper($self->{host}));
    }
    HELPER::log_trace("Setting clone URL to " . $self->{clone_url});
    return;
}
#}}}

#{{{ _set_browse_url
#
# Set the URL for the WWW landing page of the repo.
#
sub _set_browse_url
{
    my ($self) = @_;
    HELPER::log_trace("Setting browse URL");
    HELPER::require_location($self, 'host', 'owner', 'repo_name', 'path_within_repo');
    $self->{browse_url} = 'https://'
      . join(
    '/',
    $self->{host},
    $self->{owner},
    $self->{repo_name},
      );

    if ($self->{path_within_repo} !~ '^\.?$') {
    $self->{browse_url} .= join(
        '/',
        '',
        'blob',
        $self->{branch},
        $self->{path_within_repo});
    }
    HELPER::log_trace("Setting browse URL to " . $self->{browse_url});
    return;
}
#}}}

#{{{ _find_in_repo_dirs
#
# Try to find the local repo in one of the directories.
#
# If found, the `path_to_repo` variable is set.
#
sub _find_in_repo_dirs
{
    my $self = shift;
    my $tocheck = shift || $self;
    my ($owner, $host, $repo_name) = @{$tocheck}{'owner', 'host', 'repo_name'};
    HELPER::log_trace("Looking for %s in repo_dirs %s",
        $self->{repo_name},
        Dumper $self->{config}->{repo_dirs}
    );
    for my $dir (@{ $self->{config}->{repo_dirs} }, $self->{config}->{base_dir}) {
        HELPER::log_trace("Checking repo_dir $dir");
        if (!-d $dir) {
            HELPER::log_error("Not a directory (in repo_dirs): $dir");
            carp Dumper $self->{config}->{repo_dirs};
        }
        my @candidates = ($repo_name);
        if ($owner) {
            push @candidates, join('/', $owner, $repo_name);
            if ($host) {
                push @candidates, join('/', $host, $owner, $repo_name);
            };
        };

        # XXX hard-coded
        for my $host (qw(github.com gitlab.com bitbucket.com)) {
            push @candidates, join('/', $host, $owner, $repo_name);
        }
        for my $candidate (@candidates) {
            $candidate = "$dir/$candidate";
            HELPER::log_trace("Trying candidate $candidate");
            if ((-l $candidate)
                ||
                (
                    (-d $candidate)
                    &&
                    HELPER::_git_dir_for_filename($candidate) eq $candidate)) {
                $tocheck->{path_to_repo} = $candidate;
                return;
            }
        }
    }
    return;
}
#}}}

#{{{ _create_repo
#
# Create a repository on the platform.
#
sub _create_repo
{
    my ($self) = @_;
    HELPER::require_location($self, 'host', 'owner', 'repo_name');
    HELPER::log_info("Creating repo %s/%s/%s", $self->{host}, $self->{owner}, $self->{repo_name});
    if ($self->get_plugin($self->{config}->{platform})) {
        $self->get_plugin($self->{config}->{platform})->create_repo($self);
    } else {
        HELPER::log_die(
            sprintf "Creating repos only supported for [%s] currently",
            join(', ', $self->list_plugins()));
    }
    $self->_reset_urls();
    return;
}
#}}}

#{{{
#
# Print host/owner/reponame repository if it exists
sub _find_repo_clone_location
{
    my $self = shift;
    my ($owner, $host, $repo_name) = @_;
    my $ret = $self->_find_in_repo_dirs({
        owner => $owner,
        host => $host,
        repo_name => $repo_name,
    });
    if ($ret) { return $ret->{repo_name}; }
}
#}}}

#{{{ _fork_repo
#
# Fork a repository on the platform before cloning.
#
sub _fork_repo
{
    my ($self) = @_;
    HELPER::require_location($self, 'host', 'owner', 'repo_name');
    my $host = $self->{host};
    if (my $plugin = $self->get_plugin($host)) {
        my $owner = $plugin->get_username($self);
        if (my $path_to_repo = $self->_find_repo_clone_location($owner, $host, $self->{repo_name})) {
            $self->{owner} = $owner;
            $self->_reset_urls();
            HELPER::log_info("Already cloned as $path_to_repo");
        } else {
            HELPER::log_info("Forking from %s@%s", $self->{owner}, $host);
            $plugin->fork_repo($self);
        }
    } else {
        HELPER::log_die("Forking only supported for Github and Gitlab currently, no plugin for $host");
    }
    $self->_reset_urls();
    return;
}
#}}}

#{{{ _obtain_repo
# 
# Get a local repository by any means necessary.
#
sub _obtain_repo
{
    my ($self) = @_;
    HELPER::require_location($self, 'host', 'owner', 'repo_name');
    if (!$self->{path_to_repo}) {
        $self->_find_in_repo_dirs();
    }
    if ($self->{path_to_repo}
        && !$self->{config}->{ignore_existing}
        && !$self->{config}->{fork}
    ) {
        return 1;
    }
    if ($self->{config}->{create}) {
        $self->_create_repo();
    } elsif ($self->{config}->{fork}) {
        $self->_fork_repo();
    }
    if ($self->{config}->{clone}) {
        $self->_clone_repo();
    }
    unless ($self->{path_to_repo}) {
        HELPER::log_die("No local repository found.");
    }
}
#}}}

#{{{ _clone_repo
#
# Clone a repository.
#
sub _clone_repo
{
    my ($self) = @_;
    HELPER::require_location($self, 'host', 'owner', 'repo_name');
    my $ownerDir = join('/', $self->{config}->{base_dir}, $self->{host}, $self->{owner});
    HELPER::_mkdirp($ownerDir);
    HELPER::_chdir($ownerDir);
    my $repoDir = join('/', $ownerDir, $self->{repo_name});
    if (! -d $repoDir) {
        my $cloneCmd = $self->_clone_command();
        HELPER::log_info(sprintf "Clone '%s' to '%s'.", $self->{clone_url}, $repoDir);
        my $output = HELPER::_system($cloneCmd . ' 2>&1');
        if ($? > 0) {
            unless ($self->{config}->{create}) {
                HELPER::log_die("'$cloneCmd' failed with '$?':\n " . $output);
            }
        }
        if (! -d $repoDir) {
            carp "'$cloneCmd' failed silently for " . Dumper($self->{url});
            return;
        }
    } else {
        HELPER::log_info("Repository already cloned: '$repoDir'")
    }
    $self->{path_to_repo} = $repoDir;
    return;
}
#}}}

#{{{ _reset_urls
sub _reset_urls
{
    my $self = shift;
    $self->_set_browse_url();
    $self->_set_clone_url();
    unless ($self->{config}->{ignore_existing}) {
        $self->_find_in_repo_dirs();
    }
    return;
}
#}}}

#}}}
#====================================================

#====================================================
#{{{ Constructor
#

sub new
{
    my ($class, $_args, $cli_config) =  @_;

    my $self = bless {}, $class;

    $self->{args}   = $_args;
    # unless (scalar(@{$self->{args}})) {
    #     $self->{args}   = ['.'];
    # }
    $self->{config} = $self->_load_config($cli_config);

    # sanity checks
    if ($self->{config}->{fork}) {
        HELPER::log_debug("--fork implies --clone");
        $self->{config}->{clone} = 1;
    }

    if ($self->{config}->{create} && $self->{config}->{fork}) {
        HELPER::log_die("--create conflicts with --fork");
    }

    if ($self->{config}->{platform} && ! $self->get_plugin($self->{config}->{platform})) {
    HELPER::log_die(
        sprintf("Config: No plugin supports platform '%s'. Supported: [%s]",
            $self->{config}->{platform}, join(', ', $self->list_plugins())));
    }

    $self->{path_within_repo} = '.';
    $self->{branch}           = 'master'; # TODO hard-coded

    if ($self->{args}->[0]) {
        if ($self->{args}->[0] =~ /^(https?:|git@)/mx) {
            $self->_parse_url($self->{args}->[0]);
        } else {
            $self->_parse_filename($self->{args}->[0]);
        }
        $self->_reset_urls();
    }
    else {
        HELPER::log_info("No path or URL given");
    }
    if ($HELPER::LOGLEVEL > 1) {
        HELPER::log_trace("Parsed as: " . Dumper $self);
    }

    return $self;
}
#}}}
#====================================================

#====================================================
#{{{ usage
sub usage
{
    my ($cls, %args) = @_;
    $args{tags} ||= [ $cls->list_tags ];
    $args{cmd} ||= undef;
    if ($args{error}) {
    print HELPER::style('error', "\nError: %s\n\n", $args{error});
    }
    print HELPER::style( 'heading',     "Usage:\n\t" );
    print HELPER::style( 'script-name', $HELPER::SCRIPT_NAME );
    print HELPER::style( 'option',      " [options]" );
    print HELPER::style( 'command',     " <command>" );
    print HELPER::style( 'arg',         " <args>\n" );
    print HELPER::style( 'heading', "Options:" );
    print HELPER::style( 'default', " [%s]\n", join( ',', @{ $args{tags} } ) );
    for my $opt_name ($cls->list_options()) {
    my $opt = $cls->get_option($opt_name);
    unless (grep { $_ eq $opt->{tag} } @{ $args{tags} }) {
        next;
    }
    print "\t";
    $opt->print_usage();
    }

    print HELPER::style('heading', "Subcommands:\n");
    for my $cmd_name ($cls->list_commands()) {
    if ($args{cmd} && $cmd_name ne $args{cmd}) {
        next;
    }
    my $cmd = $cls->get_command($cmd_name);
    $cmd_name =~ s/_/-/gmx;
    print "\t";
    $cmd->print_usage(brief => 1);
    }
    return;
}
#}}}
#====================================================

#====================================================
#{{{ Initialize class

#----------------------------------------------------
#{{{ add plugins

# XXX hard-coded
__PACKAGE__->add_plugin('RepoLocator::Plugin::Bitbucket');
__PACKAGE__->add_plugin('RepoLocator::Plugin::Github');
__PACKAGE__->add_plugin('RepoLocator::Plugin::Gitlab');

#}}}
#----------------------------------------------------

#----------------------------------------------------
#{{{ add options
#

__PACKAGE__->add_option(
    name     => 'color',
    synopsis => 'Whether to use colors',
    usage    => '--[no-]color',
    default  => 1,
    tag      => 'common',
);

__PACKAGE__->add_option(
    name     => 'base_dir',
    env      => 'GITDIR',
    synopsis => 'The base directory to clone repos to and look for them.',
    usage    => '--base-dir=<path>',
    default  => $ENV{GITDIR} || $ENV{HOME} . '/build',
    tag      => 'prefs',
);

# TODO fix this
__PACKAGE__->add_option(
    name     => 'repo_dirs',
    csv      => 1,
    usage    => '--repo-dirs=<comma separated dirs>',
    synopsis => 'The directories to search for repositories.',
    default  => $ENV{GITDIR_PATH} || [],
    env      => 'GITDIR_PATH',
    tag      => 'prefs',
);

__PACKAGE__->add_option(
    name      => 'editor',
    synopsis  => 'The editor to open files with.',
    usage     => '--editor=<path to editor>',
    default   => $ENV{EDITOR} || 'vim',
    env       => 'EDITOR',
    man_usage => '--editor=*BINARY*',
    tag       => 'prefs',
);

__PACKAGE__->add_option(
    name => 'browser',
    env       => 'BROWSER',
    synopsis  => 'The web browser to open URL with.',
    man_usage => '--browser=*BINARY*',
    usage => '--browser=<binary>',
    default   => $ENV{BROWSER} || 'chromium',
    tag       => 'prefs',
);

__PACKAGE__->add_option(
    name      => 'shell',
    env       => 'SHELL',
    usage     => '--shell=<path to shell>',
    man_usage => '--shell=*SHELL*',
    synopsis  => 'The shell to use',
    tag       => 'prefs',
    default   => $ENV{SHELL} || 'bash',
);

__PACKAGE__->add_option(
    name      => 'loglevel',
    shortcut  => { 'info' => 'info', 'debug' => 'debug', 'trace' => 'trace', 'error'=>'error' },
    env       => 'LOGLEVEL',
    usage     => '--loglevel=<trace|debug|info|error>',
    synopsis  => 'Log level',
    man_usage => '--loglevel=[*LEVEL*]',
    long_desc => HELPER::unindent(12, q(
    Specify logging level. Can be one of `trace`, `debug`, `info`
        or `error`. If no level is specified, defaults to `debug`. If
    the option is omitted, only errors will be logged.
    )
    ),
    tag     => 'common',
    default => $ENV{LOGLEVEL} || 'error',
);

__PACKAGE__->add_option(
    name      => 'clone_opts',
    synopsis  => 'Additional arguments to pass to "git clone"',
    usage     => '--clone-opts=<arg1 arg2...>',
    default   => '--depth 1',
    long_desc => 'Additional command line arguments to pass to *git-clone(1)*',
    tag       => 'prefs',
);

__PACKAGE__->add_option(
    name => 'prefer_ssh',
    synopsis  => 'Whether to prefer "git@" over "https:" URL',
    usage => '--prefer-ssh',
    default   => 1,
    long_desc  => HELPER::unindent(12, q(
    Whether to prefer SSH URL over HTTP URL if the remote repository is owned
    by the user. If set to a true value, use *git@host:owner/repo_name* URL over
    *https://host/owner/repo_usage* URL.
    )
    ),
    tag => 'prefs',
);

__PACKAGE__->add_option(
    name     => 'clone',
    synopsis => 'Whether to clone the repo locally.',
    usage    => '--[no-]clone',
    default  => 1,
    tag      => 'common',
);

__PACKAGE__->add_option(
    name     => 'fork',
    synopsis => 'Whether to fork the repository before cloning.',
    usage    => '--[no-]fork',
    default  => 0,
    tag      => 'common',
);

__PACKAGE__->add_option(
    name     => 'create',
    synopsis => 'Create a new repo if it could not be found',
    usage    => '--[no-]create',
    default  => 0,
    tag      => 'common',
);

__PACKAGE__->add_option(
    name     => 'platform',
    shortcut => { 'gh' => 'github.com', 'gl' => 'gitlab.org', 'bb' => 'bitbucket.org' },
    synopsis => 'Use this platform as a fallback for non-absolute URI.',
    usage    => '--platform=<plugin>',
    default  => 'github.com',
    tag      => 'common',
);

__PACKAGE__->add_option(
    name     => 'create_private',
    synopsis => 'If a new repository is created, it should be non-public.',
    usage    => '--[no-]create-private',
    default  => 0,
    tag      => 'common',
);

__PACKAGE__->add_option(
    name     => 'prompt',
    shortcut => {p => 1},
    synopsis => "Prompt before executing system commands.",
    usage    => '--[no-]prompt',
    default  => 0,
    tag      => 'common',
);

__PACKAGE__->add_option(
    name => 'ignore_existing',
    synopsis  => "Don't look for the repo in the directories",
    usage => '--[no-]ignore-existing',
    default   => 0,
    tag       => 'common',
);

#}}}
#----------------------------------------------------

#----------------------------------------------------
#{{{ add commands

#{{{ readme
__PACKAGE__->add_command({
    name     => 'readme',
    synopsis => 'Find a README for this repo',
    long_desc => 'Look for README in local dirs, otherwise print its URL',
    args     => [ { name => 'location', synopsis => 'Location to browse', required => 0 } ],
    tag      => 'common',
    do       => sub {
    my ($self) = @_;
    $self->{path_within_repo} = '/README.md';
    my $full_path = join('', $self->{path_to_repo}, $self->{path_within_repo});
    if (! $self->{config}->{color}) {
        print "$full_path";
    } else {
        HELPER::log_debug("Opening mdv for $full_path");
        HELPER::_system(join(' ',
                # XXX shellescape
                'cat', $full_path,
                '|', 'sed "/<!--/ d"',
                '|', 'mdv -u h -',
            ));
    }
    }
});
#}}}

#{{{ config
__PACKAGE__->add_command({
    name     => 'config',
    synopsis => 'Output information suitable for a zsh completion script',
    args     => [{ name => 'group', synopsis => 'What to complete', required => 0 } ],
    tag      => 'common',
    do       => sub {
        my ($self) = @_;
        my $highlighter = sub {
            my $v = HELPER::human_readable_default($_[0]);
            return HELPER::style(
                $v =~ /true|false/gmx ? $v : 'string', $v);
        };
        for my $k (__PACKAGE__->list_options()) {
            my $opt = __PACKAGE__->get_option($k);
            my $v = $self->{config}->{$k};
            printf "%s=%s",
            $k,
            $highlighter->($v);
            if ($v ne $opt->{default}) {
                printf "\t# default: %s", $highlighter->($opt->{default});
            }
            printf "\n";

        }
    }
 });
#}}}

#{{{ zsh_complete
__PACKAGE__->add_command({
    name     => 'zsh_complete',
    synopsis => 'Output information suitable for a zsh completion script',
    args     => [{ name => 'group', synopsis => 'What to complete', required => 0 } ],
    tag      => 'common',
    do       => sub {
        my ($self) = @_;
        my $group = $self->{args}->[0];
        my @complete;
        if ($group eq 'repos') {
            my @alldirs = @{$self->{config}->{repo_dirs}};
            push(@alldirs, $self->{config}->{base_dir});
            for my $dir (@alldirs) {
                for my $host (@{__PACKAGE__->list_plugins}) {
                    last unless (-d "$dir/$host");
                    my $_out = qx(find "$dir/$host" -maxdepth 2 -mindepth 2 -type d);
                    chomp $_out;
                    for (split("\n", $_out)) {
                        s,^$dir/,,;
                        # s,^(.*?)/([^/]*)/([^/]*)/([^/]*)$,$4:$2/$3/$4,gm;
                        push @complete, $_;
                    }
                }
            }
        } elsif ($group eq 'option_names') {
            push @complete, __PACKAGE__->list_options();
        } elsif ($group eq 'options') {
            for my $opt_name (__PACKAGE__->list_options()) {
                my $opt = __PACKAGE__->get_option($opt_name);
                my $x = $opt->to_zsh();
                chomp $x;
                push @complete, "- " . $opt->{tag} . "\n", split("\n", $x);
            }
        } elsif ($group eq 'command_names') {
            push @complete, __PACKAGE__->list_commands();
        } elsif ($group eq 'tags') {
            push @complete, 'all', __PACKAGE__->list_tags();
        } elsif ($group eq 'commands') {
            for my $cmd_name (__PACKAGE__->list_commands()) {
                my $cmd = __PACKAGE__->get_command($cmd_name);
                my $x = $cmd->to_zsh();
                chomp $x;
                push @complete, split("\n", $x);
            }
        } elsif ($group eq 'zsh-complete') {
            push @complete, qw(options option_names commands command_names repos zsh-complete);
        }
        print join("\n", @complete);
    }
 });
#}}}

#{{{ edit
__PACKAGE__->add_command({
    name      => 'edit',
    synopsis  => 'Edit file at <location>',
    long_desc => HELPER::unindent(12, q{
        Open the location in an editor.

        Examples:

        git-url edit https://github.com/kba/git-url
        git-url edit https://github.com/kba/git-url/blob/master/git-url.1.md
        git-url edit https://github.com/kba/git-url/blob/master/git-url.1.md#L121
        }
    ),
    args => [
        {
            name     => 'location',
            synopsis => 'Location to edit',
            required => 1
        }
    ],
    tag => 'common',
    do  => sub {
        my ($self) = @_;
        $self->_obtain_repo();
        HELPER::require_location( $self, 'path_to_repo' );
        HELPER::_chdir $self->{path_to_repo};
        HELPER::_system $self->_edit_command();
    }
 });
#}}}

#{{{ url
__PACKAGE__->add_command({
    name     => 'url',
    synopsis => 'Get the URL to this file in the online repository.',
    tag      => 'common',
    do       => sub {
        my ($self) = @_;
        if (! $self->{args}->[0]) {$self->_parse_filename('.');}
        $self->_reset_urls();
        HELPER::require_location($self, 'browse_url');
        print $self->{browse_url} . "\n";
    }
 });
#}}}

#{{{ ls
__PACKAGE__->add_command({
    name     => 'ls',
    synopsis => 'List all local repositories, list only repo names',
    args     => [],
    tag      => 'common',
    do       => sub {
        my ($self) = @_;

        my @alldirs = @{ $self->_all_repo_dirs() };

        for my $dir (@alldirs) {
            for my $host (@{__PACKAGE__->list_plugins}) {
                next unless (-d "$dir/$host");
                system("cd $dir;" . join('|',
                        "find '$host' -maxdepth 2 -mindepth 2 -type d",
                        "sed 's,[^/]*/,,'",
                        'sort',
                        'uniq'
                    ));
            }
        }
    }
 });
#}}}

#{{{ ls-abs
__PACKAGE__->add_command({
    name     => 'ls_abs',
    synopsis => 'List all local repositories, list full paths',
    args     => [],
    tag      => 'common',
    do       => sub {
        my ($self) = @_;

        my @alldirs = @{ $self->_all_repo_dirs() };

        my @lines;
        for my $dir (@alldirs) {
            for my $host (@{__PACKAGE__->list_plugins}) {
                next unless (-d "$dir/$host");
                my $shellcmd = "find '$dir/$host' -maxdepth 2 -mindepth 2 -type d";
                push(@lines, qx{$shellcmd});
            }
        }
        @lines = uniq(sort(@lines));

        for my $line (@lines) {
            if ($self->{config}->{color}) {
                my $reset = "\x1b[0m";
                my $neutral = "\x1b[38;5;8m";

                my @segments = split('/', $line);
                my $i = $#segments;
                for my $style ('38;5;196', '38;5;62', '38;5;172') {
                    last unless $segments[$i];
                    $segments[$i] =~ s,^,\x1b[${style}m,;
                    $segments[$i] =~ s,$,$reset,;
                    $i--;
                }
                my $joined = join('/', @segments);
                $joined =~ s,^([\x1b]*),$neutral$1,;
                $joined =~ s,/,$neutral/,g;
                print $joined;
            } else {
                print $line;
            }
        }
    }
 });
#}}}

#{{{ shell
__PACKAGE__->add_command({
    name     => 'shell',
    synopsis => 'Open a shell in the local repository directory',
    args     => [ { name => 'location', synopsis => 'Location to edit', required => 1 } ],
    tag      => 'common',
    do       => sub {
        my ($self) = @_;
        $self->_obtain_repo();
        HELPER::require_location($self, 'path_to_repo');
        HELPER::_chdir $self->{path_to_repo};
        HELPER::_system $self->{config}->{shell};
    }
 });
#}}}

#{{{ tmux
__PACKAGE__->add_command({
    name     => 'tmux',
    synopsis => 'Attach to or create a tmux session named like the repo.',
    args     => [ { name => 'session|location', synopsis => 'Session/URL/location to open or none to list all', required => 0 } ],
    tag      => 'common',
    do       => sub {
        my ($self) = @_;
        my @sessions = split /\n/mx, HELPER::_qx("tmux ls -F '#{session_name}'");;
        my $needle = $self->{args}->[0];
        unless ($needle) {
            print HELPER::style("heading", "Current tmux sessions:\n");
            my $i = 0;
            for (@sessions) {
                printf "%2d - %s\n", ++$i, $_;
            }
            if ($self->{config}->{prompt}) {
                printf "\n[1-%d] > ", scalar(@sessions);
                my $choice = <>;
                $choice =~ s/[^0-9]//g;
                if ($choice ne '' && $choice > 0 && $choice <= scalar @sessions) {
                    HELPER::_system("tmux attach -d -t" . $sessions[$choice-1]);
                }
            }
        } else {
            my ($session) = grep {/^$needle/mx} @sessions;
            if (!$session) {
                $self->_obtain_repo();
                HELPER::require_location($self, 'path_to_repo');
                HELPER::_chdir $self->{path_to_repo};
                $session = $self->{repo_name};
                $session =~ s/[^A-Za-z0-9_-]/-/g;
            }
            HELPER::_system("tmux attach -d -t" . $session);
            if ($?) {
                HELPER::_system("tmux new -s " . $session);
            }
        }
    }
 });
#}}}

#{{{ path
__PACKAGE__->add_command({
    name     => 'path',
    synopsis => 'Show the path of the local repository for a URL',
    args     => [ { name => 'URL', synopsis => 'URL to show local path for', required => 1 } ],
    tag      => 'common',
    do       => sub {
        my ($self) = @_;
        HELPER::require_location($self, 'path_to_repo');
        print $self->{path_to_repo} . "\n";
    }
 });
#}}}

#{{{ browse
__PACKAGE__->add_command({
    name     => 'browse',
    synopsis => 'Open the browser to this file.',
    long_desc => 'Open the browser to this file. Defaults to the current working directory.',
    args     => [ { name => 'location', synopsis => 'Location to browse', required => 0 } ],
    tag      => 'common',
    do       => sub {
        my ($self) = @_;
        if (! $self->{args}->[0]) {$self->_parse_filename('.');}
        $self->_reset_urls();
        HELPER::require_location($self, 'browse_url');
        HELPER::_system(join(' ', $self->{config}->{browser}, $self->{browse_url}));
    }
 });
#}}}

#{{{ help
__PACKAGE__->add_command({
    name     => 'help',
    synopsis => 'Open help for subcommand or man page',
    tag      => 'common',
    args     => [ { name => 'command or option', synopsis => 'Command to look up', required => 0 } ],
    do       => sub {
        my ($self) = @_;
        $_ = $self->{args}->[0];
        if ($_ && /^o$/) {
            $_ = $self->{args}->[1];
            s/^-*//mx;
            s/-/_/gmx;
            my $opt = __PACKAGE__->get_option($_);
            if ($opt) {
                $opt->print_help()
            }
            else {
                $self->usage(error => "No such option: " . $_, tags=>['common']);
            }
        }
        elsif ($_) {
            s/-/_/gmx;
            my $cmd = __PACKAGE__->get_command($_);
            if ($cmd) {
                $cmd->print_help()
            }
            else {
                $self->usage(error => "No such command " . $_);
            }
        }
        else {
            HELPER::_system("man $HELPER::SCRIPT_NAME");
        }
    }
 });
#}}}

#{{{ version
__PACKAGE__->add_command({
    name     => 'version',
    synopsis => 'Show version information and such',
    tag      => 'common',
    do       => sub {
        my ( $self, $cli_config ) = @_;
        print HELPER::style( 'heading', $HELPER::SCRIPT_NAME );
        print HELPER::style( 'command', " v$HELPER::VERSION\n" );
        print HELPER::style( 'arg', 'Build date: ' );
        print "$HELPER::BUILD_DATE\n";
        print HELPER::style( 'arg', 'Last commit: ' );
        printf "https://github.com/kba/%s/commit/%s\n", $HELPER::SCRIPT_NAME, $HELPER::LAST_COMMIT;
    }
 });
#}}}

#{{{ usage
__PACKAGE__->add_command({
    name     => 'usage',
    synopsis => 'Show usage',
    tag      => 'common',
    args     => [
        {   name     => join('|', 'all', __PACKAGE__->list_tags()), synopsis => 'Tags to display',
            required => 0
        }
    ],
    do => sub {
        my ($self) = @_;
        my @tags = split(',', $self->{args}->[0] // 'common');
        if (grep { $_ eq 'all' || $_ eq '*' } @tags) {
            @tags = $self->list_tags;
        }
        __PACKAGE__->usage(tags => \@tags);
    }
 });
#}}}

#}}}
#----------------------------------------------------

#}}}
#====================================================

1;
