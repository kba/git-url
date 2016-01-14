package CliApp::SelfDocumenting;
use StringUtils;
use ObjectUtils;
use List::Util qw(first);
use LogUtils;

my @_required = qw(name synopsis tag parent);
our @_modes = qw(ini man cli);

sub _require_mode {
    my ($self, $mode) = @_;
    LogUtils->error("Mode '%s' not one of %s", $mode, \@_modes) unless (
        $mode && first { $_ eq $mode } @_modes
    );
}

sub style {
    my ($self, $mode, $style, $str, @args) = @_;
    if (scalar @_ == 1) {
        my $ret = lc ref $self;
        $ret =~ s/^.*:://;
        return $ret;
    }
    $self->_require_mode($mode);
    if ($mode eq 'cli') {
        return StringUtils->style($style, $str, @args);
    } else {
        return sprintf($str, @args);
    }
}

sub new {
    my ($class, $subclass, $subclass_required, %_self) = @_;

    $_self{description} //= $_self{synopsis};
    # $_self{parent} //= undef;

    ObjectUtils->validate_required_args( $subclass, [@_required, @{ $subclass_required }],  %_self );

    for my $var (keys %_self) {
        no strict 'refs';
        next if $var eq 'validate';
        next if $var eq 'exec';
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
    @parents = ($self->name);
    while ($self = $self->parent) {
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

sub doc_name {
    my ($self, $mode) = @_;
    $self->_require_mode($mode);
    return $self->style($mode, $self->style, $self->name);
}

sub doc_usage {
    my ($self, $mode) = @_;
    $self->_require_mode($mode);
    my $ret = '';
    $ret .= $self->doc_name($mode);
    if ($self->can('count_options') && $self->count_options) {
        $ret .= sprintf " [%s]", join(' ', map { $_->doc_name($mode) } @{ $self->options });
    }
    if ($self->can('count_commands') && $self->count_commands) {
        $ret .= sprintf " %s", join('|', map { $_->doc_name($mode) } @{ $self->commands });
    }
    if ($self->can('count_arguments') && $self->count_arguments) {
        $ret .= sprintf " %s", join('|', map { $_->doc_name($mode) } @{ $self->arguments });
    }
    return $ret;
}

sub doc_help {
    my ($self, $mode, $indent) = @_;
    $self->_require_mode($mode);
    $indent //= '';
    my $s = '';
    $s .= sprintf("%s  %s\n", $self->doc_usage($mode), $self->description);
    if ($self->can('count_options') && $self->count_options) {
        $s .= "\n";
        for my $opt (@{$self->options}) {
            $s .= sprintf "  %s  %s\n", $opt->doc_usage($mode), $opt->synopsis;
        }
    }
    if ($self->can('count_commands') && $self->count_commands) {
        $s .= "\n";
        for my $cmd (@{$self->commands}) {
            $s .= $cmd->doc_help($mode, "$indent  ");
        }
    }
    if ($self->can('count_arguments') && $self->count_arguments) {
        $s .= "\n";
        for my $arg (@{$self->arguments}) {
            $s .= $arg->doc_help($mode, "$indent  ");
        }
    }
    $s .= "\n";
    $s =~ s/^/$indent/gmx;
    return $s;
}

sub doc_version {
    my ($self, $mode) = @_;
    $self->_require_mode($mode);
    my $app = $self->app;
    my $ret = '';
    $ret .= $self->doc_usage($mode);
    $ret .= "\n";
    $ret .= sprintf(
        "%s %s\n",
        $self->style($mode, 'heading', 'Version:'),
        $self->style($mode, 'value',   $app->version));
    $ret .= sprintf(
        "%s %s\n",
        $self->style($mode, 'heading', 'Build Date:'),
        $self->style($mode, 'value',   $app->build_date));
    $ret .= sprintf(
        "%s %s\n",
        $self->style($mode, 'heading', 'Configuration file:'),
        $self->style($mode, 'value',   $app->{default_ini}));
    return $ret;
}


1;
