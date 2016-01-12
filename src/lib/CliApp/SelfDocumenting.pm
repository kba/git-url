package CliApp::SelfDocumenting;
use StringUtils;
use ObjectUtils;
use LogUtils;

my @_required = qw(name synopsis tag);
my @_modes = qw(ini man cli);

sub new {
    my ($class, $subclass, $subclass_required, %_self) = @_;

    $_self{description} //= $_self{synopsis};

    ObjectUtils->validate_required_args( $subclass, [@_required, @{ $subclass_required }],  %_self );

    # create accessors
    for my $var (keys %_self) {
        no strict 'refs';
        *{ sprintf "%s::%s", $subclass, $var } = sub {
            # LogUtils->trace("%s->{%s} = %s", $_[0], $var, $_[0]->{$var});
            return $_[0]->{$var};
        };
        if (ref $_self{$var}) {
            *{ sprintf "%s::count_%s", $subclass, $var } = sub { 
               if( ref $_[0]->{$var} eq 'ARRAY') {
                   return scalar @{$_[0]->{$var}};
               } elsif( ref $_[0]->{$var} eq 'HASH') {
                   return scalar keys %{$_[0]->{$var}};
               }
            };
        }
    }
    my $self = bless \%_self, $subclass;
    # LogUtils->debug("self->{name}: '%s'", $self->{name});
    # LogUtils->debug("Can 'name': '%s' [%s]", $self->can('name'), $self->name);
    return $self;
}

sub root {
    my ($self) = @_;
    return $self->parent ? $self->parent->root : $self;
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