#!/usr/bin/perl
use strict;
use warnings;

our $SCRIPT_NAME = "__SCRIPT_NAME__";
our $VERSION     = "__VERSION__";
our $BUILD_DATE  = "__BUILD_DATE__";
our $LAST_COMMIT = "__LAST_COMMIT__";

package HELPER;
use strict;
use warnings;
use Term::ANSIColor;
use File::Path qw(make_path);
use File::Basename qw(dirname);
our $DEBUG = 0;

#---------
#
# Logging
#
#---------

my $__log_levels = {
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
    if ($HELPER::DEBUG >= $minLevel) {
        printf("[%s] %s\n", colored($levelName, $color), sprintf(shift(@msgs), @msgs));
    }
    return;
}
sub log_trace { return _log(\@_, "TRACE", 3, 'bold yellow'); }
sub log_debug { return _log(\@_, "DEBUG", 2, 'bold blue'); }
sub log_info  { return _log(\@_, "INFO",  1, 'bold green'); }
sub log_error { return _log(\@_, "ERROR", 0, 'bold red'); }
sub log_die { $_[1] .= join(' ', caller); log_error(@_); return exit 70; }

sub require_config
{
    my ($config, @keys) = @_;
    my $die_flag;
    for my $key (@keys) {
        unless (defined $config->{$key}) {
            log_error("This feature requires the '$key' config setting to be set.");
            $die_flag = 1;
        }
    }
    if ($die_flag) {
        log_die("Unmet config requirements at" . join(' ', caller));
    }
    return;
}

sub require_location
{
    my ($location, @keys) = @_;
    my $die_flag;
    for my $key (@keys) {
        unless (defined $location->{$key}) {
            log_error("This feature requires the '$key' location information but it wasn't detected.");
            $die_flag = 1;
        }
    }
    if($die_flag) {
        log_die("Unmet location requirements at " . join(' ', caller)) ;
    }
    return;
}

#---------
#
# HELPER
#
#---------

sub _chdir
{
    my $dir = shift;
    log_debug("cd $dir");
    return chdir $dir;
}

sub _system
{
    my $cmd = shift;
    log_debug("$cmd");
    return system($cmd);
}

sub _qx
{
    my $cmd = shift;
    log_debug("$cmd");
    return qx($cmd);
}

sub _mkdirp
{
    my $dir = shift;
    log_trace("mkdir -p $dir");
    return make_path($dir);
}

sub _slurp
{
    my ($filename) = shift;
    log_trace("cat $filename");
    if (!-r $filename) {
        log_die("File '$filename' doesn't exist or isn't readable.");
    }
    open my $handle, '<', $filename;
    chomp(my @lines = <$handle>);
    close $handle;
    return \@lines;
}

sub _git_dir_for_filename
{
    my $path = shift;
    if (!-d $path) {
        HELPER::_chdir(dirname($path));
    }
    else {
        HELPER::_chdir($path);
    }
    my $dir = _qx('git rev-parse --show-toplevel 2>&1');
    chomp($dir);
    if ($? > 0) {
        log_error($dir);
    }
    return $dir;
}

sub unindent
{
    my ($amount, $str) = @_;
    $str =~ s/\n*$//mx;
    $str =~ s/^\n*//mx;
    $str =~ s/^\s{$amount}//mgx;
    return $str;
}

sub human_readable_default
{
    my ($val) = @_;
    return !defined $val
      ? 'NONE'
      : ref $val ? ref $val eq 'ARRAY'
          ? sprintf("[%s]", join(",", @{$val}))
          : HELPER::log_die 'Unsupported ref type ' . ref $val
      : $val =~ /^1$/mx ? 'true'
      : $val =~ /^0$/mx ? 'false'
      :                 sprintf('"%s"', $val);
}

package RepoLocator::Plugin::Github;
use strict;
use warnings;

sub init
{
    my ($cls, $self) = @_;
    $self->add_option(
        github_api => {
            cli_usage => '--github_api=<API URL>',
            cli_desc  => 'Base URL of the Github API to use.',
            man_desc => 'Base URL of the Github API to use. Meaningful only for Github Enterprise users.',
            default => 'https://api.github.com',
            tag     => 'github',
        });
    $self->add_option(
        github_user => {
            cli_usage => '--github-user=<user name>',
            cli_desc  => 'Your github user name.',
            env       => 'GITHUB_USER',
            default   => $ENV{GITHUB_USER},
            tag       => 'github',
        });
    $self->add_option(
        github_token => {
            cli_usage => '--github_token=<token>',
            cli_desc  => 'Your private github token.',
            man_desc  => HELPER::unindent(
                16, q(
                Your private github token. the best place to set this is in a shell
                startup file. Make sure to keep this private.  For a guide on how
                to set up a private access token, please refer to

                <https://help.github.com/articles/creating-an-access-token-for-command-line-use/>
            )
            ),
            env     => 'GITHUB_TOKEN',
            default => $ENV{GITHUB_TOKEN},
            tag     => 'github',
        });
    return;
}

sub to_url
{
    my ($cls, $self, $path) = @_;
    if (index($path, '/') == -1) {
        HELPER::require_config($self->{config}, 'github_user');
        HELPER::log_debug("Prepending " . $self->{config}->{github_user});
        $path = join('/', $self->{config}->{github_user}, $path);
    }
    return "https://github.com/$path";
}

sub create_repo
{
    my ($cls, $self) = @_;
    HELPER::require_config($self->{config}, 'github_user', 'github_token');
    HELPER::require_location($self, 'repo_name');
    if ($self->{owner} ne $self->{config}->{github_user}) {
        return HELPER::log_info(
            sprintf(
                "Can only create repos for %s, not %s",
                $self->{owner},
                $self->{config}->{github_user}));
    }
    my $api_url = join('/', $self->{config}->{github_api}, 'user', 'repos');
    my $user    = $self->{config}->{github_user};
    my $token   = $self->{config}->{github_token};
    my $forkCmd = join(
        ' ', 'curl', '-i', '-s',
        "-u $user:$token",
        '-d ', sprintf(q('{"name": "%s"}'), $self->{repo_name}),
        '-XPOST',
        $api_url
    );
    my $resp = HELPER::_qx($forkCmd);
    if ([ split("\n", $resp) ]->[0] !~ 201) {
        HELPER::log_die("Failed to create the repo: $resp");
    }
    $self->{owner} = $user;
    return;
}

sub fork_repo
{
    my ($cls, $self) = @_;
    HELPER::require_config($self->{config}, 'github_user', 'github_token');
    if ($self->{owner} eq $self->{config}->{github_user}) {
        HELPER::log_info("Not forking an owned repository");
        return;
    }
    my $api_url = join(
        '/', $self->{config}->{github_api}, 'repos', $self->{owner}, $self->{repo_name},
        'forks'
    );
    my $user    = $self->{config}->{github_user};
    my $token   = $self->{config}->{github_token};
    my $forkCmd = join(
        ' ', 'curl', '-i', '-s',
        "-u $user:$token",
        '-XPOST',
        $api_url
    );
    my $resp = HELPER::_qx($forkCmd);
    if ([ split("\n", $resp) ]->[0] !~ 202) {
        HELPER::log_die("Failed to fork the repo: $resp");
    }
    $self->{owner} = $user;
    return;
}

package RepoLocator::Plugin::Gitlab;
use strict;
use warnings;

sub init
{
    my ($cls, $self) = @_;
    $self->add_option(
        gitlab_api => {
            cli_desc  => 'Base URL of the Gitlab API to use.',
            cli_usage => '--gitlab_api=<API URL>',
            default   => 'https://gitlab.com/api/v3',
            tag       => 'gitlab',
        });
    $self->add_option(
        gitlab_user => {
            cli_usage => '--gitlab-user=<user>',
            cli_desc  => 'Your Gitlab user name.',
            env       => 'GITLAB_USER',
            default   => $ENV{GITLAB_USER},
            tag       => 'gitlab',
        });
    $self->add_option(
        gitlab_token => {
            cli_usage => '--gitlab-token=<token>',
            cli_desc  => 'Your private Gitlab token.',
            man_desc  => HELPER::unindent(
                16, q(
                Your private Gitlab token. The best place to set this is in a
                shell startup file. Make sure to keep this private.

                You can find your personal access token by browsing to
                ```
                <https://gitlab.com/profile/account>
                ```)
            ),
            env     => 'GITLAB_TOKEN',
            default => $ENV{GITLAB_TOKEN},
            tag     => 'gitlab',
        });
    return;
}

sub to_url
{
    my ($cls, $self, $path) = @_;
    if (index($path, '/') == -1) {
        HELPER::require_config($self->{config}, 'gitlab_user');
        HELPER::log_debug("Prepending " . $self->{config}->{gitlab_user});
        $path = join('/', $self->{config}->{gitlab_user}, $path);
    }
    return "https://gitlab.com/$path";
}

sub create_repo
{
    my ($cls, $self) = @_;
    HELPER::require_config($self->{config}, 'gitlab_token');
    HELPER::require_location($self, 'repo_name');
    my $api_url = join('/', $self->{config}->{gitlab_api}, 'projects');
    my $user    = $self->{config}->{gitlab_user};
    my $token   = $self->{config}->{gitlab_token};
    my $forkCmd = join(
        ' ',
        'curl',
        '-i',
        '-s',
        '-H', join(':', 'PRIVATE-TOKEN', $token),
        '-X', 'POST',
        '-F', join('=', 'name',          $self->{repo_name}),
        $api_url,
    );
    my $resp = HELPER::_qx($forkCmd);

    if ($resp !~ /201 Created/mx) {
        HELPER::log_die("Failed to create the repo: $resp");
    }
    $self->{owner} = $user;
    return;
}

package RepoLocator;
use strict;
use warnings;
use Data::Dumper;
use File::Spec;
use Carp qw(croak carp);
use Term::ANSIColor;
$Data::Dumper::Terse = 1;
our $CONFIG_FILE = join('/', $ENV{HOME}, '.config', $SCRIPT_NAME, 'config.ini');

#=========
# Options
#=========
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
    my ($cls, $opt_name, $opt) = @_;
    return $option_doc{$opt_name} = $opt;
}

#==========
# Commands
#==========
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
    my ($cls, $opt_name, $opt) = @_;
    return $command_doc{$opt_name} = $opt;
}

#=========
# Plugins
#=========
my %plugin_doc = ();

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
    my ($cls, $plugin_name, $plugin) = @_;
    $plugin->init($cls);
    return $plugin_doc{$plugin_name} = $plugin;
}

#======
# Tags
#======

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

#==================
# Initialize class
#==================

#
# add plugins
#
__PACKAGE__->add_plugin('github.com' => 'RepoLocator::Plugin::Github');
__PACKAGE__->add_plugin('gitlab.com' => 'RepoLocator::Plugin::Gitlab');

#
# add options
#
__PACKAGE__->add_option(
    base_dir => {
        env       => 'GITDIR',
        cli_desc  => 'The base directory to clone repos to and look for them.',
        cli_usage => '--base-dir=<path>',
        default   => $ENV{GITDIR} || $ENV{HOME} . '/build',
        tag       => 'prefs',
    });
__PACKAGE__->add_option(
    repo_dirs => {
        array     => 1,
        cli_usage => '--repo-dirs=<comma separated dirs>',
        cli_desc  => 'The directories to search for repositories.',
        default   => $ENV{GITDIR_PATH} || [],
        env       => 'GITDIR_PATH',
        tag       => 'prefs',
    });
__PACKAGE__->add_option(
    editor => {
        cli_desc  => 'The editor to open files with.',
        cli_usage => '--editor=<path to editor>',
        default   => $ENV{EDITOR} || 'vim',
        env       => 'EDITOR',
        man_usage => '--editor=*BINARY*',
        tag       => 'prefs',
    });
__PACKAGE__->add_option(
    browser => {
        env       => 'BROWSER',
        cli_desc  => 'The web browser to open URL with.',
        man_usage => '--browser=*BINARY*',
        cli_usage => '--browser=<binary>',
        default   => $ENV{BROWSER} || 'chromium',
        tag       => 'prefs',
    });
__PACKAGE__->add_option(
    shell => {
        env       => 'SHELL',
        cli_usage => '--shell=<path to shell>',
        man_usage => '--shell=*SHELL*',
        cli_desc  => 'The shell to use',
        tag       => 'prefs',
        default   => $ENV{SHELL} || 'bash',
    });
__PACKAGE__->add_option(
    debug => {
        env       => 'LOGLEVEL',
        cli_usage => '--debug[=trace|debug|info|error]',
        cli_desc  => 'Log level',
        man_usage => '--debug[=*LEVEL*]',
        man_desc  => HELPER::unindent(
            12, q(
            Specify logging level. Can be one of `trace`, `debug`, `info`
            or `error`. If no level is specified, defaults to `debug`. If
            the option is omitted, only errors will be logged.
        )
        ),
        tag     => 'common',
        default => $ENV{LOGLEVEL} || 'error',
    });
__PACKAGE__->add_option(
    clone_opts => {
        cli_desc  => 'Additional arguments to pass to "git clone"',
        cli_usage => '--clone-opts=<arg1 arg2...>',
        default   => '--depth 1',
        man_desc  => 'Additional command line arguments to pass to *git-clone(1)*',
        tag       => 'prefs',
    });
__PACKAGE__->add_option(
    prefer_ssh => {
        cli_desc  => 'Whether to prefer "git@" over "https:" URL',
        cli_usage => '--prefer-ssh',
        default   => 1,
        man_desc  => HELPER::unindent(
            12, q(
            Whether to prefer SSH URL over HTTP URL if the remote repository is owned
            by the user. If set to a true value, use *git@host:owner/repo_name* URL over
            *https://host/owner/repo_name* URL.
        )
        ),
        tag => 'prefs',
    });
__PACKAGE__->add_option(
    fork => {
        cli_desc  => 'Whether to fork the repository before cloning.',
        cli_usage => '--fork',
        default   => 0,
        tag       => 'common',
    });
__PACKAGE__->add_option(
    clone => {
        cli_desc  => 'Clone repo from this service.',
        cli_usage => '--clone',
        default   => 'github.com',
        tag       => 'common',
    });
__PACKAGE__->add_option(
    create => {
        cli_desc  => 'Create a new repo if it could not be found',
        cli_usage => '--create',
        default   => 0,
        tag       => 'common',
    });
__PACKAGE__->add_option(
    no_local => {
        cli_desc  => "Don't look for the repo in the directories",
        cli_usage => '--no-local',
        default   => 0,
        tag       => 'common',
    });

#
# add commands
#
__PACKAGE__->add_command(
    edit => {
        name     => 'edit',
        cli_desc => 'Edit file at <location>',
        man_desc => HELPER::unindent(
            12, q{
            Open the location in an editor.

            Examples:

                git-url edit https://github.com/kba/git-url
                git-url edit https://github.com/kba/git-url/blob/master/git-url.1.md
                git-url edit https://github.com/kba/git-url/blob/master/git-url.1.md#L121
        }
        ),
        args => [ { name => 'location', cli_desc => 'Location to edit', required => 1 } ],
        tag  => 'common',
        do   => sub {
            my ($self) = @_;
            $self->_clone_repo();
            HELPER::require_location($self, 'path_to_repo');
            HELPER::_chdir $self->{path_to_repo};
            HELPER::_system $self->_edit_command();
          }
    },
);
__PACKAGE__->add_command(
    url => {
        name     => 'url',
        cli_desc => 'Get the URL to this file in the online repository.',
        tag      => 'common',
        do       => sub {
            my ($self) = @_;
            HELPER::require_location($self, 'browse_url');
            print $self->{browse_url} . "\n";
          }
    },
);
__PACKAGE__->add_command(
    shell => {
        name     => 'shell',
        cli_desc => 'Open a shell in the local repository directory',
        args     => [ { name => 'location', cli_desc => 'Location to edit', required => 1 } ],
        tag      => 'common',
        do       => sub {
            my ($self) = @_;
            $self->_clone_repo();
            HELPER::require_location($self, 'path_to_repo');
            HELPER::_chdir $self->{path_to_repo};
            HELPER::_system $self->{config}->{shell};
          }
    },
);
__PACKAGE__->add_command(
    tmux => {
        name     => 'tmux',
        cli_desc => 'Attach to or create a tmux session named like the repository.',
        tag      => 'common',
        do       => sub {
            my ($self) = @_;
            my $needle = $self->{args}->[0];
            unless ($needle) {
                print colored("Current tmux sessions:\n", "bold cyan");
                my $output = HELPER::_qx("tmux ls -F '#{session_name}'");
                chomp $output;
                for (split /\n/mx, $output) {
                    print "  * $_\n";
                }
                return;
            }
            my ($session) = grep /^$needle/mx, split("\n", HELPER::_qx("tmux ls -F '#{session_name}'"));
            if (!$session) {
                $self->_clone_repo();
                HELPER::require_location($self, 'path_to_repo');
                HELPER::_chdir $self->{path_to_repo};
                $session = $self->{repo_name};
            }
            HELPER::_system("tmux attach -d -t" . $session);
            if ($?) {
                HELPER::_system("tmux new -s " . $session);
            }
          }
    },
);
__PACKAGE__->add_command(
    show => {
        name     => 'show',
        cli_desc => 'Show the path of the local repository.',
        tag      => 'common',
        do       => sub {
            my ($self) = @_;
            HELPER::require_location($self, 'path_to_repo');
            print $self->{path_to_repo} . "\n";
          }
    },
);
__PACKAGE__->add_command(
    browse => {
        name     => 'browse',
        cli_desc => 'Open the browser to this file.',
        man_desc => 'Open the browser to this file. Defaults to the current working directory.',
        args     => [ { name => 'location', cli_desc => 'Location to browse', required => 0 } ],
        tag      => 'common',
        do       => sub {
            my ($self) = @_;
            HELPER::require_location($self, 'browse_url');
            HELPER::_system(join(' ', $self->{config}->{browser}, $self->{browse_url}));
          }
    },
);
__PACKAGE__->add_command(
    help => {
        name     => 'help',
        cli_desc => 'Open help for subcommand or man page',
        tag      => 'common',
        args     => [ { name => 'command or option', cli_desc => 'Command to look up', required => 0 } ],
        do       => sub {
            my ($self) = @_;
            $_ = $self->{args}->[0];
            if ($_ && /^-/mx) {
                s/^-*//mx;
                s/-/_/gmx;
                my $opt = __PACKAGE__->get_option($_);
                if ($opt) {
                    $self->usage_cmd_opt($opt);
                }
                else {
                    $self->usage(error => "No such option: " . $self->{args}->[0]);
                }
            }
            elsif ($_) {
                s/-/_/gmx;
                my $cmd = __PACKAGE__->get_command($_);
                if ($cmd) {
                    $self->usage_cmd_opt($cmd);
                }
                else {
                    $self->usage(error => "No such option: " . $self->{args}->[0]);
                }
            }
            else {
                HELPER::_system("man __SCRIPT_NAME__");
            }
          }
    },
);
__PACKAGE__->add_command(
    version => {
        name     => 'version',
        cli_desc => 'Show version information and such',
        tag      => 'common',
        do       => sub {
            my ($self, $cli_config) = @_;
            print colored($SCRIPT_NAME, 'bold blue') . colored(" v$VERSION\n", "bold green");
            print colored('Build date: ',  'white bold') . "$BUILD_DATE\n";
            print colored('Last commit: ', 'white bold') . "https://github.com/kba/$SCRIPT_NAME/commit/$LAST_COMMIT\n";
          }
    },
);
__PACKAGE__->add_command(
    usage => {
        name     => 'usage',
        cli_desc => 'Show usage',
        tag      => 'common',
        args     => [
            {   name     => join('|', 'all', __PACKAGE__->list_tags()), cli_desc => 'Tags to display',
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

#=======================
# Private API - Instance
#=======================

sub _load_config
{
    my $self       = shift;
    my $cli_config = shift;
    my $config     = {};
    for (keys %option_doc) {
        $config->{$_} = $option_doc{$_}{default};
    }
    if (-r $CONFIG_FILE) {
        my @lines = @{ HELPER::_slurp($CONFIG_FILE) };
        for (@lines) {
            s/^\s+|\s+$//gmx;
            next if (/^$/mx || /^[#;]/mx);
            my ($k, $v) = split /\s*=\s*/mx;
            if ($option_doc{$k}->{array}) {
                $v = [
                    map {
                        my $path = $_;
                        $path =~ s/~/$ENV{HOME}/mx;
                        $path =~ s/\/$//mx;
                        $path;
                      }
                      split(/\s*,\s*/mx, $v)
                ];
            }
            $config->{$k} = $v;
        }
    }
    while (my ($k, $v) = each(%{$cli_config})) {
        $config->{$k} = $v;
    }

    # set log level
    $HELPER::DEBUG = $__log_levels->{ $config->{debug} };

    # make sure base_dir exists
    HELPER::_mkdirp($config->{base_dir});
    return $config;
}

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

sub _clone_command
{
    my ($self) = @_;
    return join(
        ' ',
        'git clone',
        $self->{config}->{clone_opts},
        $self->{clone_url});
}

sub _edit_command
{
    my ($self) = @_;
    my $cmd = join(
        ' ',
        $self->{config}->{editor},
        $self->{path_within_repo});
    if ($self->{line}) {
        my ($line) = $self->{line} =~ /(\d+)/mx;
        if ($self->{config}->{editor} =~ /vi/mx) {
            $cmd .= " +$line";
        }
    }
    return $cmd;
}

sub _parse_filename
{
    my ($self, $path) = @_;
    HELPER::log_trace("Parsing filename $path");
    unless ($path) {
        HELPER::log_die("No path given");
    }

    # split path into filename:line:column
    ($path, $self->{line}, $self->{column}) = split(':', $path);
    if (!-e $path) {
        HELPER::log_info("No such file/directory: $path");
        HELPER::log_info(sprintf("Interpreting '%s' as '%s' shortcut", $path, $self->{config}->{clone}));
        return $self->_parse_url($self->get_plugin($self->{config}->{clone})->to_url($self, $path));
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
        if ($line =~ /\[remote .origin.\]/mx) {
            while (my $line = shift(@lines)) {
                if ($line =~ /^\s*url/mx) {
                    ($baseURL) = $line =~ / = (.*)/mx;
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
    $self->{repo_name} = $url_parts[2];
    $self->{repo_name} =~ s/\.git$//mx;
    ($url_parts[$#url_parts], $self->{line}) = split('#', $url_parts[$#url_parts]);

    if ($url_parts[3] && $url_parts[3] eq 'blob') {
        $self->{branch} = $url_parts[4];
        $self->{path_within_repo} = join('/', @url_parts[ 5 .. $#url_parts ]);
    }
    return $self;
}

sub _set_clone_url
{
    my ($self) = @_;
    HELPER::log_trace("Setting clone URL");
    HELPER::require_location($self, 'host', 'owner', 'repo_name');
    if ($self->{host} =~ /github|gitlab/mx) {
        if ($self->{config}->{prefer_ssh}
            && (   $self->{owner} eq $self->{config}->{github_user}
                || $self->{owner} eq $self->{config}->{gitlab_user}))
        {
            $self->{clone_url} = $self->_get_clone_url_ssh_owner_reponame();
        }
        else {
            $self->{clone_url} = $self->_get_clone_url_https_owner_reponame();
        }
    }
    else {
        croak 'Unknown repository tag for ' . Dumper($self->{host});
    }
    return;
}

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
    return;
}

sub _find_in_repo_dirs
{
    my $self = shift;
    HELPER::log_trace("Looking for %s in repo_dirs", $self->{repo_name});
    for my $dir (@{ $self->{config}->{repo_dirs} }, $self->{config}->{base_dir}) {
        HELPER::log_trace("Checking repo_dir $dir");
        if (!-d $dir) {
            HELPER::log_error("Not a directory (in repo_dirs): $dir");
            carp Dumper $self->{config}->{repo_dirs};
        }
        my @candidates = (
            $self->{repo_name},
            join('/', $self->{owner}, $self->{repo_name}),
            join('/', $self->{host}, $self->{owner}, $self->{repo_name}));
        for my $candidate (@candidates) {
            $candidate = "$dir/$candidate";
            HELPER::log_trace("Trying candidate $candidate");
            if (-d $candidate && HELPER::_git_dir_for_filename($candidate) eq $candidate) {
                $self->{path_to_repo} = $candidate;
                return;
            }
        }
    }
    return;
}

sub _create_repo
{
    my ($self) = @_;
    HELPER::require_location($self, 'host', 'owner', 'repo_name');
    if ($self->get_plugin($self->{config}->{create})) {
        $self->get_plugin($self->{config}->{create})->create_repo($self);
    }
    else {
        HELPER::log_die(
            sprintf "Creating repos only supported for [%s] currently",
            join(', ', $self->list_plugins()));
    }
    $self->_reset_urls();
    return;
}

sub _fork_repo
{
    my ($self) = @_;
    HELPER::require_location($self, 'host', 'owner', 'repo_name');
    if ($self->get_plugin($self->{host})) {
        $self->get_plugin($self->{host})->fork_repo($self);
    }
    else {
        HELPER::log_die("Forking only supported for Github and Gitlab currently.");
    }
    $self->_reset_urls();
    return;
}

sub _clone_repo
{
    my ($self) = @_;
    HELPER::require_location($self, 'host', 'owner', 'repo_name');
    if ($self->{path_to_repo} && !$self->{config}->{no_local}) {
        HELPER::log_info(
            sprintf(
                "We already have a path to this one (%s), not cloning to base_dir",
                $self->{path_to_repo}));
        return;
    }
    if ($self->{config}->{fork}) {
        $self->_fork_repo();
    }
    my $ownerDir = join('/', $self->{config}->{base_dir}, $self->{host}, $self->{owner});
    HELPER::_mkdirp($ownerDir);
    HELPER::_chdir($ownerDir);
    my $repoDir = join('/', $ownerDir, $self->{repo_name});
    my $cloneCmd = $self->_clone_command();
    if (!-d $repoDir) {
        my $output = HELPER::_system($cloneCmd . ' 2>&1');
        if ($? > 0) {
            if ($self->{config}->{create}) {
                $self->_create_repo();
                $self->_clone_repo();
            }
            else {
                HELPER::log_die("'$cloneCmd' failed with '$?': " . $output);
            }
        }
    }
    if (!-d $repoDir) {
        carp "'$cloneCmd' failed silently for " . Dumper($self->{url});
        return;
    }
    $self->{path_to_repo} = $repoDir;
    return;
}

sub _reset_urls
{
    my $self = shift;
    $self->_set_browse_url();
    $self->_set_clone_url();
    unless ($self->{config}->{no_local}) {
        $self->_find_in_repo_dirs();
    }
    return;
}

#-------------
#
# Constructor
#
#-------------

sub new
{
    my ($class, @args) =  @_;
    shift @args; # remove command
    my $cli_config = shift @args;

    my $self = bless {}, $class;
    $self->{args}   = \@args;
    $self->{config} = $self->_load_config($cli_config);
    for my $key ('create', 'clone', 'fork') {
        if ($key eq 'create' && $self->{config}->{$key} && $self->{config}->{$key} == 1) {
            $self->{config}->{$key} = $self->{config}->{clone};
        }
        if (   $key eq 'fork'
            && $self->{config}->{$key}
            && $self->{config}->{fork} ne $self->{config}->{clone})
        {
            HELPER::log_die(
                "Can only fork within a service. Conflicting clone<->fork: ",
                join(
                    '<->',
                    $self->{config}->{clone},
                    $self->{config}->{fork}));
        }
        my $val = $self->{config}->{$key};
        if ($val && !$self->get_plugin($val)) {
            HELPER::log_die(
                sprintf(
                    "Config: '%s': invalid value '%s'. Allowed: [%s]",
                    $key, $val, join(', ', $self->list_plugins())));
        }
    }
    $self->{path_within_repo} = '.';
    $self->{branch}           = 'master';
    if ($args[0]) {
        if ($args[0] =~ /^(https?:|git@)/mx) {
            $self->_parse_url($args[0]);
        }
        else {
            $self->_parse_filename($args[0]);
        }
        $self->_reset_urls();
    }
    else {
        HELPER::log_info("No path or URL given");
    }
    if ($HELPER::DEBUG > 1) {
        HELPER::log_trace("Parsed as: " . Dumper $self);
    }

    return $self;
}

sub usage_cmd_opt
{
    my ($cls, $cmd, $brief) = @_;
    if ($brief) {
        print "\t";
    }
    else {
        print colored("Usage:\n\t", "underline");
        print colored($SCRIPT_NAME, 'bold blue');
        print " ";
    }
    if ($cmd->{name}) {
        print colored($cmd->{name}, 'bold green');
    }
    else {
        print colored($cmd->{cli_usage}, 'bold magenta');
    }
    print " ";
    if ($cmd->{args}) {
        print colored(
            join(
                ' ',
                map { sprintf $_->{required} ? "<%s>" : "[%s]", $_->{name} } @{ $cmd->{args} }
            ),
            'bold magenta'
        );
    }
    print " -- ";
    print $cmd->{cli_desc};
    print "\n";
    if ($brief) {
        return;
    }
    if ($cmd->{args}) {
        print colored("Arguments:\n", 'underline');
        for (@{ $cmd->{args} }) {
            print "\t";
            print colored($_->{name}, 'bold magenta');
            print " ";
            print $_->{cli_desc};
            if ($_->{required}) {
                print colored(" REQUIRED", 'bold red');
            }
            else {
                print colored(" OPTIONAL", 'bold green');
            }
        }
    }
    if ($cmd->{man_desc}) {
        my $man_desc = $cmd->{man_desc};
        $man_desc =~ s/^/\t/mgx;
        print colored("\nDescription:\n", 'underline');
        print $man_desc;
        print "\n";
    }
    return;
}

sub usage
{
    my ($cls, %args) = @_;
    $args{tags} ||= [ $cls->list_tags ];
    if ($args{error}) {
        print "\n";
        print colored('Error: ', 'bold red') . $args{error} . "\n";
        print "\n";
    }
    print colored("Usage:\n", 'underline');
    print "\t";
    print colored($SCRIPT_NAME, 'bold blue');
    print colored(" [options]", 'bold magenta');
    print colored(" <command>", 'bold green');
    print colored(" <args>",    'bold yellow');
    print "\n";

    my $args_joined = join(',', @{ $args{tags} });
    printf colored("Options:", "underline");
    printf " [%s]", colored($args_joined, 'bold black');
    for my $opt_name ($cls->list_options()) {
        my $opt = $cls->get_option($opt_name);
        unless ($opt->{tag}) {
            HELPER::log_die(sprintf("Option '%s' has no tag!", $opt_name));
        }
        unless (grep { $_ eq $opt->{tag} } @{ $args{tags} }) {
            next;
        }
        print "\n\t" . colored($opt->{cli_usage}, 'bold magenta');
        print "  " . $opt->{cli_desc};
        if (defined $opt->{default}) {
            print colored(sprintf(" [%s]", $opt->{default}), 'bold black');
        }
    }

    print colored("\nSubcommands:\n", 'underline');
    for my $cmd_name ($cls->list_commands()) {
        my $cmd = $cls->get_command($cmd_name);
        $cmd_name =~ s/_/-/gmx;
        $cls->usage_cmd_opt($cmd, brief => 1);
    }
    return;
}

package main;
use Carp qw(croak carp);

sub doMain
{
    my @ARGV_PROCESSED;
    my $cli_config = {};
    my $in_opts    = 0;
    while (my $arg = shift(@ARGV)) {
        if ($arg =~ '^-' && !$in_opts) {
            $arg =~ s/^-*//mx;
            my ($k, $v) = split('=', $arg);
            $cli_config->{$k} = $v // 1;
        }
        else {
            $in_opts = 1;
            push @ARGV_PROCESSED, $arg;
        }
    }
    my $cmd_name = shift(@ARGV_PROCESSED) || 'usage';
    $cmd_name =~ s/[^a-z0-9]/_/gimx;
    my $cmd = RepoLocator->get_command($cmd_name) or do {
        RepoLocator->usage(error => "Unknown command: '$cmd_name'\n");
        exit 1;
    };
    if (scalar(grep { $_->{required} } @{ $cmd->{args} }) > scalar(@ARGV_PROCESSED)) {
        print colored("Error: ", 'bold red') . "Not enough arguments\n\n";
        __PACKAGE__->usage_cmd_opt($cmd);
        exit 1;
    }
    my $self = RepoLocator->new(\@ARGV_PROCESSED, $cli_config);
    return $cmd->{do}->($self);
}

if ($ENV{GIT_URL_SKIP_MAIN}) {
    carp "Skipping execution of __SCRIPT_NAME__ script because GIT_URL_SKIP_MAIN envvar is set";
}
else {
    doMain();
}
