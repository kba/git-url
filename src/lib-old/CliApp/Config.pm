package CliApp::Config;
use strict;
use warnings;
use HELPER;
use CliApp::Config::Option;
use Hash::Util qw(lock_hash);
use Data::Dumper;

sub new {
    my ($cls, %args) = @_;

    $args{files} ||= [];
    $args{merge} ||= {};
    my $self = bless {}, $cls;

    for ($cls->list_options()) {
        $self->{$_} = $cls->get_option($_)->{default};
    }
    for (@{ $args{files} }) {
        $self->parse_ini($_);
    }
    $self->_merge($args{merge});

    for my $k (keys %{ $self }) {
        no strict 'refs';
        *{__PACKAGE__ . '::' . $k} = sub { return $self->{$k} }
    }

    lock_hash %{$self};

    return $self;
}

sub _merge {
    my ($self, $config) = @_;
    while (my ($k, $v) = each(%{$config})) {
        my $opt = CliApp::Config->get_option($k);
        unless ($opt) {
            HELPER::log_die("No such option '%s'", $k);
        }
        if ($opt->{ref} and $opt->{ref} eq 'HASH') {
            $self->{$k} = {%{$self->{$k}}, %{$v}};
        } else {
            $self->{$k} = $v;
        }
    }
}

sub parse_kv {
    my ($class, $config, @kvpairs) = @_;
    for (@kvpairs) {
        s/^\s+|\s+$//gmx;
        s/^-*//mx;
        my ($k, $v) = split /\s*=\s*/mx, $_, 2;
        $k =~ s/[^a-zA-Z0-9]/_/mxg;
        # XXX
        $v //= 1;
        unless (CliApp::Config->has_option($k)) {
            HELPER::log_die("No such option '%s'", $k);
        }
        my $opt = CliApp::Config->get_option($k);
        if ($opt->{ref}) {
            my @split_values;
            for (split(/\s*,\s*/mx, $v)) {
                # resolve tilde ~ to HOME
                s/\A~/$ENV{HOME}/mx;
                s/([,:]\s*)~/$1$ENV{HOME}/mxg;
                # remove trailing slashes
                s/\/$//mx;
                s/\/(\s*[,:])/$1/mx;
                push @split_values, $_;
            }
            if ($opt->{ref} eq 'ARRAY') {
                $v = \@split_values;
            } elsif ($opt->{ref} eq 'HASH') {
                my %hash = map { split /:/mx } @split_values;
                $config->{$k} //= {};
                $config->{$k} = { %{$config->{$k}}, %hash };
                next;
            }
        }
        $config->{$k} = $v;
    }
    return $config;
}

sub parse_ini {
    my ($self, $filename) = @_;
    return unless (-r $filename);
    my @lines = @{ HELPER::_slurp($filename) };
    CliApp::Config->parse_kv( $self,
        grep { !( /^\s*$/mx || /^\s*[#;]/mx ) } @lines );
    return $self;
}

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

sub has_option
{
    my ($cls, $opt_name) = @_;
    return exists $option_doc{$opt_name};
}

sub add_option
{
    my ($cls, %opt_args) = @_;
    my $opt = CliApp::Config::Option->new(%opt_args);
    return $option_doc{$opt->{name}} = $opt;
}

#
# add options
#
sub setup_options {
    __PACKAGE__->add_option(
        name => 'base_dir',
        env       => 'GITDIR',
        synopsis  => 'The base directory to clone repos to and look for them.',
        usage     => '--base-dir=<path>',
        default   => $ENV{GITDIR} || $ENV{HOME} . '/build',
        tag       => 'prefs',
    );
    __PACKAGE__->add_option(
        name => 'repo_dirs',
        ref     => ref [],
        usage => '--repo-dirs=<comma separated dirs>',
        synopsis  => 'The directories to search for repositories.',
        default   => $ENV{GITDIR_PATH} || [],
        env       => 'GITDIR_PATH',
        tag       => 'prefs',
    );
    __PACKAGE__->add_option(
        name => 'editor',
        synopsis  => 'The editor to open files with.',
        usage => '--editor=<path to editor>',
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
        name => 'shell',
        env       => 'SHELL',
        usage => '--shell=<path to shell>',
        man_usage => '--shell=*SHELL*',
        synopsis  => 'The shell to use',
        tag       => 'prefs',
        default   => $ENV{SHELL} || 'bash',
    );
    __PACKAGE__->add_option(
        name => 'clone_opts',
        synopsis  => 'Additional arguments to pass to "git clone"',
        usage => '--clone-opts=<arg1 arg2...>',
        default   => '--depth 1',
        long_desc  => 'Additional command line arguments to pass to *git-clone(1)*',
        tag       => 'prefs',
    );
    __PACKAGE__->add_option(
        name => 'prefer_ssh',
        synopsis  => 'Whether to prefer "git@" over "https:" URL',
        usage => '--prefer-ssh',
        default   => 1,
        long_desc  => HELPER::unindent(
            12, q(
            Whether to prefer SSH URL over HTTP URL if the remote repository is owned
            by the user. If set to a true value, use *git@host:owner/repo_name* URL over
            *https://host/owner/repo_usage* URL.
            )
        ),
        tag => 'prefs',
    );
    __PACKAGE__->add_option(
        name => 'fork',
        synopsis  => 'Whether to fork the repository before cloning.',
        usage => '--fork',
        default   => 0,
        tag       => 'common',
    );
    __PACKAGE__->add_option(
        name => 'clone',
        synopsis  => 'Clone repo from this service.',
        usage => '--clone',
        default   => 'github.com',
        tag       => 'common',
    );
    __PACKAGE__->add_option(
        name => 'create',
        synopsis  => 'Create a new repo if it could not be found',
        usage => '--create',
        default   => 0,
        tag       => 'common',
    );
    __PACKAGE__->add_option(
        name => 'create_private',
        synopsis  => 'If a new repository is created, it should be non-public.',
        usage => '--create-private=<0|1>',
        default   => 0,
        tag       => 'common',
    );
    __PACKAGE__->add_option(
        name => 'no_local',
        synopsis  => "Don't look for the repo in the directories",
        usage => '--no-local',
        default   => 0,
        tag       => 'common',
    );

    return;
}

setup_options();
1;
