package CliApp::Config;
use ObjectUtils;

my $log = 'LogUtils';
sub log { return $log; }

sub new {
    my ($class, %args) = @_;

    ObjectUtils->validate_required_args( $class, [qw(app argv)],  %args );

    my $app = delete $args{app};
    my $self = bless \%args, $class;

    $self->{_config} = {};

    $self->parse_options($app, @{$self->{argv}});

    delete $self->{app};
    return $self;
}


sub parse_options {
    my ($self, $cmd, @argv) = @_;
    $log->debug("%s", \@argv);
    while (my $arg = shift @argv) {
        warn $arg;
        if ($arg !~ m/^--/mx) {
            unshift @argv, $arg;
            return;
        }
        $self->_parse_kv( $self->{_config}, $cmd, $arg );
    }
}

sub parse_cli {
    my ($self, $str) = @_;
}

sub _parse_kv {
    my ($self, $config, $cmd, @kvpairs) = @_;
    for (@kvpairs) {
        s/^\s+|\s+$//gmx;
        s/^-*//mx;
        my ($k, $v) = split /\s*=\s*/mx, $_, 2;
        $k =~ s/[^a-zA-Z0-9]/_/mxg;
        # XXX
        $v //= 1;
        unless ($cmd->get_option($k)) {
            $self->log->log_die("No such option '%s' for cmd '%s'", $k, $cmd->name);
        }
        my $opt = $cmd->get_option($k);
        if ($opt->{ref}) {
            my @split_values;
            for (split(/\s*,\s*/mx, $v)) {
                # resolve tilde ~ to HOME
                s/\A~/$ENV{HOME}/mx;
                s/([,:]\s*)~/$1$ENV{HOME}/mxg;
                # remove trailing slashes
                s/\/$//mx;
                s/\/(\s*[,:])/$1/mx;
                push @split_values, $_;
            }
            if ($opt->{ref} eq 'ARRAY') {
                $v = \@split_values;
            } elsif ($opt->{ref} eq 'HASH') {
                my %hash = map { split /:/mx } @split_values;
                $config->{$k} //= {};
                $config->{$k} = { %{$config->{$k}}, %hash };
                next;
            }
        }
        $config->{$k} = $v;
    }
    return $config;
}
1;
