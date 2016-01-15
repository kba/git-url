package CliApp::App;
use strict;
use warnings;
use ObjectUtils;
use parent 'CliApp::Command';

use CliApp::Plugin::cliapp;

sub new {
    my ($class, %args) = @_;

    $args{plugins} //= [qw(CliApp::Plugin::cliapp)];
    my @plugins = @{ delete $args{plugins} };
    $args{plugins} = {};
    $args{exec} = sub {};
    $args{default_command} //= 'help';

    ObjectUtils->validate_required_args( $class, [qw(version build_date)],  %args );

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
    unless (scalar @{ $argv }) {
        if ($self->{default_command}) {
            push @{ $argv }, $self->{default_command}
        } else {
            return print $self->doc_help( 'cli', error => "Expected command!" );
        }
    }
    my $cmd_name = shift @{ $argv };
    unless ( $self->get_command($cmd_name) ) {
        return print $self->doc_help( 'cli',
            error => sprintf( "No such command '%s' in %s", $cmd_name, $self->name ) );
    }
    my $cmd = $self->get_command( $cmd_name );
    $self->log->trace("%s->exec(%s)", $self->name, $cmd->full_name);
    $cmd->exec( $argv );
}

sub doc_version {
    my ($self, $mode) = @_;
    $self->_require_mode($mode);
    my $app = $self->app;
    my $ret = '';
    $ret .= $self->doc_usage($mode);
    $ret .= "\n";
    $ret .= sprintf( "%s %s\n",
        $self->style($mode, 'heading', 'Version:'),
        $self->style($mode, 'value',   $app->version));
    $ret .= sprintf( "%s %s\n",
        $self->style($mode, 'heading', 'Build Date:'),
        $self->style($mode, 'value',   $app->build_date));
    $ret .= sprintf( "%s %s\n",
        $self->style( $mode, 'heading', 'Plugins:' ),
        $self->style( $mode, 'value', "%s", StringUtils->dump( [ keys %{ $app->plugins } ] ))
    );
    $ret .= sprintf( "%s %s\n",
        $self->style($mode, 'heading', 'Configuration file:'),
        $self->style($mode, 'value',   $app->{default_ini}));
    $ret .= $self->style( $mode, 'heading', "Configuration:\n" );
    $ret .= sprintf( "  %s : %s\n",
        $self->style($mode, 'command', $self->name),
        $self->style($mode, 'config', StringUtils->dump($self->config)));
    for (@{$self->commands}) {
        $ret .= sprintf( "  %s : %s\n",
            $self->style($mode, 'command', $_->full_name),
            $self->style($mode, 'config', StringUtils->dump($_->config)));
    }
    return $ret;
}

1;
