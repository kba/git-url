package CliApp::App;
use parent 'CliApp::Command';

use CliApp::Plugin::cliapp;

my $log = 'LogUtils';

sub new {
    my ($class, %args) = @_;

    $args{plugins} //= [qw(CliApp::Plugin::cliapp)];
    @plugins = @{ delete $args{plugins} };
    $args{plugins} = {};

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
    return $app;
}

sub do {
    my ($self) = @_;

}

1;
