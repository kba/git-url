package GitUrl::Utils::Tmux;
use Data::Dumper;
use Clapp::Utils::File;
use GitUrl::Location;

use parent 'Clapp::Utils';

sub list_sessions {
    my $output = Clapp::Utils::File->qx("tmux ls -F '#{session_name}'");
    my @sessions =
        grep { $_->path_to_repo }
            map { GitUrl::Location->parse( $_ ) }
                split(/\n/mx, $output);
    return \@sessions;
}

sub attach {
    my ($self, $sess) = @_;
    $self->app->utils->{file}->system("tmux attach-session -t '$sess'");
}
sub create_session {
    my ($self, $loc) = @_;
    $self->app->utils->{file}->chdir( $loc->path_to_repo );
    $self->app->utils->{file}->system("tmux new-session -s '%s'", $loc->get_shortcut);
}

1;
