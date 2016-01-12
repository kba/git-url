package CliApp;
use strict;
use warnings;
use HELPER;
use Data::Dumper;
use File::Spec;
use Carp qw(croak carp);
use Term::ANSIColor;

use CliApp::Config;
use CliApp::Command;
use CliApp::Plugin::Core;

use parent 'CliApp::Command';

$Data::Dumper::Terse = 1;
our $CONFIG_FILE = join('/', $ENV{HOME}, '.config', "__SCRIPT_NAME__", 'config.ini');

BEGIN {
    no strict 'refs';
    #=========
    # Getters
    #=========
    for my $k (qw(config)) {
        *{__PACKAGE__ . '::' . $k} = sub { return $_[0]->{$k}; };
    }
}

my $is_setup;

sub setup {
    setup_plugins();
    setup_options();
    setup_commands();
    $is_setup = 1;
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
    my ($cls, %cmd_args) = @_;
    my $cmd = CliApp::Command->new(%cmd_args);
    return $command_doc{$cmd->{name}} = $cmd;
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
    my ($cls, $plugin_cls, @args) = @_;
    my $plugin = $plugin_cls->new(@args);
    $plugin->add_options($cls);
    for ($plugin->list_hosts) {
        $plugin_doc{$_} = $plugin;
    }
    return $plugin;
}

#======
# Tags
#======

sub all_tags
{
    my ($cls) = @_;
    my %ret;
    for (CliApp::Config->list_options()) {
        $ret{ CliApp::Config->get_option($_)->{tag} } = 1;
    }
    my @tags = sort keys %ret;
    return join(',', 'all', @tags);
}

#-------------
# Constructor
#
#-------------

sub new
{
    my ($class, %_self) =  @_;
    unless ($is_setup) {
        die "App is uninitialized. Must call __PACKAGE__->setup()";
    }

    @required_attrs = qw(name synopsis subcommand args);
    HELPER::validate_required_args($cls, \@_required_attrs, %_self);

    my $self = $class->SUPER::new(
        name => %_self{name},
        synopsis => %_self{synopsis},
        tag => '__root__',
        do => sub {
            my ($me) = @_;
            $me->get_command($me->{subcommand})->do($me);
        }
    );
    $self->{subcommand} = $_self{subcommand};
    $self->{args}   = $_self{args};

    # load config
    my @config_files = ($CONFIG_FILE);
    $self->{config} = CliApp::Config->new(
        files => \@config_files,
        merge => $_self{opts},
    );
    # set log level
    $HELPER::LOGLEVEL = $HELPER::log_levels->{ $self->config->loglevel };
    # set log level
    $HELPER::styles = $self->config->color_theme;

    return $self;
}

sub print_usage
{
    my ($self, %args) = @_;
    $args{tags} ||= 'common';
    if ($args{tags} =~ /\b(all|\*)\b/mx ) {
        $args{tags} = $self->all_tags;
    }
    print HELPER::style( 'script-name', $HELPER::SCRIPT_NAME );
    print " ";
    for my $opt_name ($self->config->list_options) {
        my $opt = $self->config->get_option($opt_name);
        next if (index($args{tags}, $opt->{tag}) == -1);
        print HELPER::style( 'option', $opt->{usage} );
        print " ";
    }
    print HELPER::style( 'command', "<%s>", join('|', $self->list_commands) );
    print HELPER::style( 'arg',     " [args]\n" );
}

sub print_help
{
    my ($self, %args) = @_;
    $args{tags} ||= 'common';
    if ($args{tags} =~ /\b(all|\*)\b/mx ) {
        $args{tags} = $self->all_tags;
    }
    print HELPER::style( 'error', "\nError: %s\n\n", $args{error} ) if ( $args{error} );
    print HELPER::style( 'heading',     "Usage:\n\t" );
    $self->print_usage(%args);
    print HELPER::style( 'heading',     "Options:" );
    print HELPER::style( 'default', " [%s]\n", $args{tags} );
    for my $opt_name (CliApp::Config->list_options()) {
        my $opt = CliApp::Config->get_option($opt_name);
        next if (index($args{tags}, $opt->{tag}) == -1);
        print "\t";
        $opt->print_usage();
    }

    print HELPER::style('heading', "Subcommands:\n");
    for my $cmd_name ($self->list_commands()) {
        my $cmd = $self->get_command($cmd_name);
        $cmd_name =~ s/_/-/gmx;
        print "\t";
        $cmd->print_usage(brief => 1);
    }
    return;
}

#==================
# Initialize class
#==================

#
# add plugins
#
sub setup_plugins {
    __PACKAGE__->add_plugin('CliApp::Plugin::Core');
    return;
}

1;
