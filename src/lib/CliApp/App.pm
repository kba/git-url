package CliApp::App;
use parent 'CliApp::Command';

use CliApp::Plugin::cliapp;

my $log = 'LogUtils';

sub new {
    my ($class, %args) = @_;

    $args{plugins} //= [qw(CliApp::Plugin::cliapp)];
    @plugins = @{ delete $args{plugins} };
    $args{plugins} = {};
    $args{exec} = sub {};

    ObjectUtils->validate_required_args( $class, [qw(version build_date)],  %args );

    my $app = $class->SUPER::new(%args, parent => undef);

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
        $log->log_die("Expected command!");
    }
    my $cmd_name = shift @{ $argv };
    unless($self->get_command( $cmd_name )) {
        $log->log_die("No such command '%s' in %s", $cmd_name, $self->name);
    }
    my $cmd = $self->get_command( $cmd_name );
    $log->trace("%s->exec(%s)", $self->name, $cmd->full_name);
    $cmd->exec( $argv );
}
1;
