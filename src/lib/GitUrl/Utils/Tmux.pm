package GitUrl::Utils::Tmux;
use Data::Dumper;
use Clapp::Utils::File;

sub list_sessions {
    my $output = Clapp::Utils::File->qx("tmux ls -F '#{session_name}'");
    return [split /\n/mx, $output];
}

1;
