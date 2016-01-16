package CliApp::App;
use strict;
use warnings;
use CliApp::ObjectUtils;
use parent 'CliApp::Command';

use CliApp::Plugin::cliapp;

sub new {
    my ($class, %args) = @_;

    $args{plugins} //= [qw(CliApp::Plugin::cliapp)];
    my @plugins = @{ delete $args{plugins} };
    $args{plugins} = {};
    $args{exec} = sub {};
    $args{default_command} //= 'help';

    CliApp::ObjectUtils->validate_required_args( $class, [qw(version build_date)],  %args );

    my $self = $class->SUPER::new(%args, parent => undef);

    for my $plugin (@plugins) {
        my $plugin_name = ref($plugin) ? ref($plugin) : $plugin;
        $plugin_name =~ s/^.*://mx;
        $plugin_name = lc $plugin_name;
        $self->plugins->{$plugin_name} = ref($plugin)
            ? $plugin
            : $plugin->new(parent => $self);
        # $self->log->debug("%s", $self);
        $self->plugins->{$plugin_name}->inject($self);
    }

    if ($self->count_arguments || ! $self->count_commands) {
        $self->log->log_die("self must have commands and cannot have arguments");
    }

    return $self;
}

sub configure {
    my ($self, $argv, @inis) = @_;

    $self->SUPER::configure($argv, @inis);

    for my $plugin (values %{ $self->plugins }) {
        $plugin->on_configure($self) ;
    }
}

sub exec {
    my ($self, $argv) = @_;
    $self->configure( $argv );
    if ($self->count_commands && ! scalar @{ $argv }) {
        return print $self->doc_help( mode => 'cli', error => "Expected command!", verbosity => 1 );
    }
    my $cmd_name = shift @{ $argv };
    unless ( $self->get_command($cmd_name) ) {
        return print $self->doc_help( mode => 'cli',
            error => sprintf( "No such command '%s' in %s", $cmd_name, $self->name ) );
    }
    my $cmd = $self->get_command( $cmd_name );
    $self->log->trace("exec(%s)", $cmd->full_name);
    $cmd->exec( $argv );
}

1;
