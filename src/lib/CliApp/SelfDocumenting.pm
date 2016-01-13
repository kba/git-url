package CliApp::SelfDocumenting;
use StringUtils;
use ObjectUtils;
use LogUtils;

my @_required = qw(name synopsis tag parent);
my @_modes = qw(ini man cli);

sub new {
    my ($class, $subclass, $subclass_required, %_self) = @_;

    $_self{description} //= $_self{synopsis};
    # $_self{parent} //= undef;

    ObjectUtils->validate_required_args( $subclass, [@_required, @{ $subclass_required }],  %_self );

    for my $var (keys %_self) {
        no strict 'refs';
        next if $var eq 'validate';
        *{ sprintf "%s::%s", $subclass, $var } = sub {
            # LogUtils->trace("%s->{%s} = %s", $_[0], $var, $_[0]->{$var});
            return $_[0]->{$var};
        };
    }
    my $self = bless \%_self, $subclass;
    # LogUtils->debug("self->{name}: '%s'", $self->{name});
    # LogUtils->debug("Can 'name': '%s' [%s]", $self->can('name'), $self->name);
    return $self;
}

sub app {
    my ($self) = @_;
    return $self->parent ? $self->parent->app : $self;
}

sub full_name {
    my ($self) = @_;
    return '' unless $self->parent;
    @parents = ($self->name);
    while ($self = $self->parent) {
        last unless $self->parent;
        unshift @parents, $self->name;
    }
    return join('.', @parents);
}

sub validate {
    my ($self, @args) = @_;
    if ($self->{validate}) {
        return $self->{validate}->( $self, @args );
    } elsif ($self->{enum}) {
        for $val (@args) {
            grep { $val eq $_ } @{ $self->{enum} } or return [
                "Invalid value '%s' for option '%s'. Allowed: %s", $val, $self->name, $self->enum
            ];
        }
    }
    return;
}

sub doc_usage {
    my ($self) = @_;

    my $s = '';

    $s .= $self->name;

    return $s;
}

sub doc_help {
    my ($self, $mode) = @_;
    LogUtils->log_die("Mode '%s' not one of [%s]", $mode, \@_modes) unless (
        $mode || !grep { $_ eq $mode } @_modes
    );

    my $s = '';
    $s .= $self->name;
    return $s;
}

1;
