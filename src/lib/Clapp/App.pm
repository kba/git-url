package Clapp::App;
use strict;
use warnings;
use Clapp::Utils::Object;
use parent 'Clapp::Command';

use Clapp::Plugin::core;

sub new {
    my ($class, %args) = @_;

    $args{plugins} //= [];
    unshift @{ $args{plugins} }, qw(Clapp::Plugin::core);
    my @plugins = @{ delete $args{plugins} };
    $args{plugins} = {};

    $args{utils} //= [];
    unshift @{ $args{utils} }, qw(Clapp::Utils::File Clapp::Utils::String);
    my @utils = @{ delete $args{utils} };

    $args{exec} = sub {};
    $args{default_command} //= 'help';

    Clapp::Utils::Object->validate_required_args( $class, [qw(version build_date)],  %args );

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
    $self->{utils} = {};
    for my $util (@utils) {
        my $util_name = $util;
        $util_name =~ s/^.*://mx;
        $util_name = lc $util_name;
        $self->log->info("Util: %s -> %s", $util_name, $util);
        $self->{utils}->{$util_name} = $util->new(app => $self);
    }

    if ($self->count_arguments || ! $self->count_commands) {
        $self->log->log_die("self must have commands and cannot have arguments");
    }

    return $self;
}

sub get_utils {
    my ($self, $name) = @_;
    $self->exit_error("No such utils $name") if ! $name || ! exists $self->{utils}->{$name};
    return $self->{utils}->{$name};
}

sub configure {
    my ($self, $argv, $inis) = @_;

    $self->SUPER::configure(
        argv => $argv,
        inis => $inis,
        on_configure => sub {
            for my $plugin (values %{ $self->plugins }) {
                $plugin->on_configure($self);
            }
        });

}

sub exec {
    my ($self, $argv) = @_;
    $self->configure( $argv, [] );
    if ($self->count_commands && ! scalar @{ $argv }) {
        print $self->doc_help(
            mode => 'cli',
            verbosity => 1
        );
        exit 0;
    }
    my $cmd_name = shift @{ $argv };
    unless ( $self->get_command($cmd_name) ) {
        $self->exit_error("No such command '%s' in %s", $cmd_name, $self->name );
    }
    my $cmd = $self->get_command( $cmd_name );
    $self->log->trace("exec(%s)", $cmd->full_name);
    $cmd->exec( $argv );
}

1;
