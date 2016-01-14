package CliApp::App;
use strict;
use warnings;
use parent 'CliApp::Command';

use CliApp::Plugin::cliapp;

my $log = 'LogUtils';

sub new {
    my ($class, %args) = @_;

    $args{plugins} //= [qw(CliApp::Plugin::cliapp)];
    my @plugins = @{ delete $args{plugins} };
    $args{plugins} = {};
    $args{exec} = sub {};
    $args{default_command} //= 'help';

    ObjectUtils->validate_required_args( $class, [qw(version build_date)],  %args );

    my $app = $class->SUPER::new(%args,
        parent => undef);

    for my $plugin (@plugins) {
        my $plugin_name = ref($plugin) ? ref($plugin) : $plugin;
        $plugin_name =~ s/^.*://mx;
        $plugin_name = lc $plugin_name;
        $app->plugins->{$plugin_name} = ref($plugin)
            ? $plugin
            : $plugin->new(parent => $app);
        # $log->debug("%s", $app);
        $app->plugins->{$plugin_name}->inject($app);
    }

    if ($app->count_arguments || ! $app->count_commands) {
        $log->log_die("App must have commands and cannot have arguments");
    }

    return $app;
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
            error =>
              sprintf( "No such command '%s' in %s", $cmd_name, $self->name ) );
    }
    my $cmd = $self->get_command( $cmd_name );
    $log->trace("%s->exec(%s)", $self->name, $cmd->full_name);
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
