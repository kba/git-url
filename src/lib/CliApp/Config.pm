package CliApp::Config;
use ObjectUtils;

my $log = 'LogUtils';
sub log { return $log; }

sub new {
    my ($class, %args) = @_;

    ObjectUtils->validate_required_args( $class, [qw(app argv)],  %args );

    my $app = delete $args{app};
    my $self = bless \%args, $class;
    $self->{_config} = $self->_generate_default_config($app);
    $self->parse_options($app, $self->{argv});

    delete $self->{app};
    return $self;
}

sub _generate_default_config {
    my ($self, $cmd) = @_;
    my $ret = {};
    for $opt (@{ $cmd->options }) {
        $ret->{ $opt->name } = $opt->default;
    }
    return $ret;
}

1;
