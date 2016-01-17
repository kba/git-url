package GitUrl::PlatformPlugin;
use Clapp::Utils::Object;

use parent 'Clapp::Plugin';

sub new {
    my ($class, %args) = @_;

    Clapp::Utils::Object->validate_required_args($class, ['hosts'], %args);
    Clapp::Utils::Object->validate_required_methods($class, 'browse_url');

    return $class->SUPER::new(
        host_aliases => {},
        %args
    );
}

sub inject {
    my ($self, $app) = @_;

    my $host_aliases = $app->get_option('host_aliases');
    $host_aliases->{default} = { %{ $host_aliases->{default} }, %{ $self->host_aliases } };

    my $make_opt = sub {
        my ($opt, %args) = @_;
        $app->add_option(
            name => sprintf('%s_%s', $self->name, $opt),
            synopsis => sprintf('%s API %s', ucfirst $self->name, $opt),
            env => sprintf('%s_%s', uc $self->name, uc $opt),
            tag => $self->name,
            %args,
        );
    };

    $make_opt->('user', default =>
        $ENV{ sprintf( '%s_%s', uc $self->name, uc $opt ) } || sprintf( 'no-%s-user', $self->name ));
    $make_opt->('token', default => undef);
    $make_opt->('api', default => undef);
    $make_opt->('orgs', default => sub {
            my %temp;
            my $user = $ENV{sprintf("%s_USER", uc $self->name)};
            if ($user) {
                $temp{$user} = 1;
            }
            my $orgs = $ENV{sprintf("%s_ORGS", uc $self->name)};
            if ($orgs) {
                $temp{$_} = 1 for (split(/\s*,\s*/mx, $orgs));
            }
            return [keys %temp];
        }
    );
}

sub on_configure {
    my ($self, $app) = @_;

    # TODO
}

1;
