package GitUrlApp;
use strict;
use warnings;
use HELPER;
use Data::Dumper; $Data::Dumper::Terse = 1;
use File::Spec;
use Carp qw(croak carp);
use Term::ANSIColor;

use CliApp::Plugin::Core;
use GitUrlApp::Plugin::Bitbucket;
use GitUrlApp::Plugin::Github;
use GitUrlApp::Plugin::Gitlab;

use parent 'CliApp';

our $CONFIG_FILE = join('/', $ENV{HOME}, '.config', "__SCRIPT_NAME__", 'config.ini');

BEGIN {
    no strict 'refs';
    #=========
    # Getters
    #=========
    for my $k (qw(config host)) {
        *{__PACKAGE__ . '::' . $k} = sub { return $_[0]->{$k}; };
    }
}

#-------------
#
# Constructor
#
#-------------

sub new
{
    my ($class, %_self) =  @_;

    my $self = $class->SUPER::new(
        name => $HELPER::SCRIPT_NAME,
        synopsis => 'do git stuff',
    );

    # set log level
    $HELPER::LOGLEVEL = $HELPER::log_levels->{ $self->config->loglevel };
    # set log level
    $HELPER::styles = $self->config->color_theme;
    # make sure base_dir exists
    HELPER::_mkdirp($self->config->{base_dir});

    for my $key ('create', 'clone', 'fork') {
        if ($key eq 'create' && $self->config->{$key} && $self->config->{$key} == 1) {
            $self->config->{$key} = $self->config->{clone};
        }
        if (   $key eq 'fork'
            && $self->config->{$key}
            && $self->config->{fork} ne $self->config->{clone})
        {
            HELPER::log_die(
                "Can only fork within a service. Conflicting clone<->fork: ",
                join('<->', $self->config->clone, $self->config->fork));
        }
        my $val = $self->config->{$key};
        if ($val && !$self->get_plugin($val)) {
            HELPER::log_die(
                sprintf(
                    "Config: '%s': invalid value '%s'. Allowed: [%s]",
                    $key, $val, join(', ', $self->list_plugins())));
        }
    }
    $self->{path_within_repo} = '.';
    $self->{branch}           = 'master';
    if ($self->{args}->[0]) {
        if ($self->{args}->[0] =~ /^(https?:|git@)/mx) {
            $self->_parse_url($self->{args}->[0]);
        }
        else {
            $self->_parse_filename($self->{args}->[0]);
        }
        $self->_reset_urls();
    }
    else {
        HELPER::log_info("No path or URL given");
    }
    HELPER::log_trace("Parsed as: " . Dumper $self) if ($HELPER::LOGLEVEL > 1);
    return $self;
}


#==================
# Initialize class
#==================

#
# add plugins
#
sub setup_plugins {
    __PACKAGE__->add_plugin('CliApp::Plugin::Bitbucket');
    __PACKAGE__->add_plugin('CliApp::Plugin::Github');
    __PACKAGE__->add_plugin('CliApp::Plugin::Gitlab');
    return;
}

sub setup_commands {
    #
    # add commands
    #
    __PACKAGE__->add_command(
        name      => 'edit',
        synopsis  => 'Edit file at <location>',
        long_desc => HELPER::unindent(
            12, q{
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
            $self->_clone_repo();
            HELPER::require_location( $self, 'path_to_repo' );
            HELPER::_chdir $self->{path_to_repo};
            HELPER::_system $self->_edit_command();
        }
    );
    __PACKAGE__->add_command(
        name     => 'url',
        synopsis => 'Get the URL to this file in the online repository.',
        tag      => 'common',
        do       => sub {
            my ($self) = @_;
            HELPER::require_location($self, 'browse_url');
            print $self->{browse_url} . "\n";
        }
    );
    __PACKAGE__->add_command(
        name     => 'shell',
        synopsis => 'Open a shell in the local repository directory',
        args     => [ { name => 'location', synopsis => 'Location to edit', required => 1 } ],
        tag      => 'common',
        do       => sub {
            my ($self) = @_;
            $self->_clone_repo();
            HELPER::require_location($self, 'path_to_repo');
            HELPER::_chdir $self->{path_to_repo};
            HELPER::_system $self->config->{shell};
        }
    );
    __PACKAGE__->add_command(
        name     => 'tmux',
        synopsis => 'Attach to or create a tmux session named like the repo.',
        args     => [ { name => 'session', synopsis => 'Session to open or none to list all', required => 0 } ],
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
            my ($session) = grep {/^$needle/mx} split("\n", HELPER::_qx("tmux ls -F '#{session_name}'"));
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
    );
    __PACKAGE__->add_command(
        name     => 'show',
        synopsis => 'Show the path of the local repository for a URL',
        args     => [ { name => 'URL', synopsis => 'URL to show local path for', required => 1 } ],
        tag      => 'common',
        do       => sub {
            my ($self) = @_;
            HELPER::require_location($self, 'path_to_repo');
            print $self->{path_to_repo} . "\n";
        }
    );
    __PACKAGE__->add_command(
        name     => 'browse',
        synopsis => 'Open the browser to this file.',
        long_desc => 'Open the browser to this file. Defaults to the current working directory.',
        args     => [ { name => 'location', synopsis => 'Location to browse', required => 0 } ],
        tag      => 'common',
        do       => sub {
            my ($self) = @_;
            HELPER::require_location($self, 'browse_url');
            HELPER::_system(join(' ', $self->config->{browser}, $self->{browse_url}));
        }
    );
    __PACKAGE__->add_command(
        name     => 'help',
        synopsis => 'Open help for command, option, plugin or option group',
        tag      => 'common',
        args => [
            {
                name =>
                  sprintf( 'cmd, opt, plugin or optgroup' ),
                synopsis => 'Command to look up',
                required => 0
            }
        ],
        do       => sub {
            my ($self) = @_;
            $_ = $self->{args}->[0];
            if ($_ && /^-/mx) {
                s/^-*//mx;
                s/-/_/gmx;
                my $opt = CliApp::Config->get_option($_);
                if ($opt) {
                    $opt->print_help()
                }
                else {
                    $self->print_help(error => "No such option: " . $self->{args}->[0]);
                }
            }
            elsif ($_) {
                s/-/_/gmx;
                my $cmd = __PACKAGE__->get_command($_);
                if ($cmd) {
                    $cmd->print_help()
                }
                else {
                    $self->print_help(tags => $self->{args}->[0]);
                }
            }
            else {
                $self->print_help();
            }
        }
    );
    __PACKAGE__->add_command(
        name     => 'version',
        synopsis => 'Show version information and such',
        tag      => 'common',
        do       => sub {
            my ( $self, $cli_config ) = @_;
            print colored( $HELPER::SCRIPT_NAME, 'bold blue' );
            print colored( " v$HELPER::VERSION\n", "bold green" );
            print colored( 'Build date: ', 'white bold' );
            print "$HELPER::BUILD_DATE\n";
            print colored( 'Last commit: ', 'white bold' );
            printf 'https://github.com/kba/%s/commit/%s\n', $HELPER::SCRIPT_NAME, $HELPER::LAST_COMMIT;
        }
    );

    __PACKAGE__->add_command(
        name     => 'usage',
        synopsis => 'Show usage',
        tag      => 'common',
        args     => [
            {
                name     => __PACKAGE__->all_tags(),
                synopsis => 'Tags to display',
                required => 0
            }
        ],
        do => sub {
            my ($self) = @_;
            my @tags = split( ',', $self->{args}->[0] // 'common' );
            $self->print_usage( tags => \@tags );
        }
    );
    return;
}

setup_plugins();
setup_commands();



#=======================
# Private API - Instance
#=======================

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
        $self->config->{clone_opts},
        $self->{clone_url});
}

sub _edit_command
{
    my ($self) = @_;
    my $cmd = join(
        ' ',
        $self->config->{editor},
        $self->{path_within_repo});
    if ($self->{line}) {
        my ($line) = $self->{line} =~ /(\d+)/mx;
        if ($self->config->{editor} =~ /vi/mx) {
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
        HELPER::log_info(sprintf("Interpreting '%s' as '%s' shortcut", $path, $self->config->{clone}));
        return $self->_parse_url($self->get_plugin($self->config->{clone})->to_url($self, $path));
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
    }
    return $self;
}

sub _set_clone_url
{
    my ($self) = @_;
    HELPER::log_trace("Setting clone URL");
    HELPER::require_location($self, 'host', 'owner', 'repo_name');
    if ($self->{host} =~ /github|gitlab|bitbucket/mx) {
        # TODO move this out
        if ($self->config->{prefer_ssh}
            && (   $self->{owner} eq $self->config->{github_user}
                || $self->{owner} eq $self->config->{gitlab_user}))
        {
            $self->{clone_url} = $self->_get_clone_url_ssh_owner_reponame();
        }
        else {
            $self->{clone_url} = $self->_get_clone_url_https_owner_reponame();
        }
    }
    else {
        HELPER::log_die('Unknown repository tag for ' . Dumper($self->{host}));
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
    for my $dir (@{ $self->config->{repo_dirs} }, $self->config->{base_dir}) {
        HELPER::log_trace("Checking repo_dir $dir");
        if (!-d $dir) {
            HELPER::log_error("Not a directory (in repo_dirs): $dir");
            carp Dumper $self->config->{repo_dirs};
        }
        my @candidates = (
            $self->{repo_name},
            join('/', $self->{owner}, $self->{repo_name}),
            join('/', $self->{host}, $self->{owner}, $self->{repo_name}),
        );
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
    if ($self->get_plugin($self->config->{create})) {
        $self->get_plugin($self->config->{create})->create_repo($self);
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
    if ($self->{path_to_repo} && !$self->config->{no_local}) {
        HELPER::log_info(
            sprintf(
                "We already have a path to this one (%s), not cloning to base_dir",
                $self->{path_to_repo}));
        return;
    }
    if ($self->config->{fork}) {
        $self->_fork_repo();
    }
    my $ownerDir = join('/', $self->config->{base_dir}, $self->{host}, $self->{owner});
    HELPER::_mkdirp($ownerDir);
    HELPER::_chdir($ownerDir);
    my $repoDir = join('/', $ownerDir, $self->{repo_name});
    my $cloneCmd = $self->_clone_command();
    if (!-d $repoDir) {
        my $output = HELPER::_system($cloneCmd . ' 2>&1');
        if ($? > 0) {
            if ($self->config->{create}) {
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
    unless ($self->config->{no_local}) {
        $self->_find_in_repo_dirs();
    }
    return;
}

1;

