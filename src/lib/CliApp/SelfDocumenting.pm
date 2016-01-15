package CliApp::SelfDocumenting;
use strict;
use warnings;
use StringUtils;
use ObjectUtils;
use List::Util qw(first);
use LogUtils;

my @_required = qw(name synopsis tag parent);
our @_modes = qw(ini man cli);

sub new {
    my ($class, $subclass, $subclass_required, %_self) = @_;

    $_self{description} //= $_self{synopsis};
    # $_self{parent} //= undef;

    ObjectUtils->validate_required_args( $subclass, [@_required, @{ $subclass_required }],  %_self );

    for my $var (keys %_self) {
        no strict 'refs';
        next if $var eq 'validate';
        next if $var eq 'exec';
        my $method = sprintf "%s::%s", $subclass, $var;
        next if __PACKAGE__->can($method);
        *{$method} = sub {
            # $self->log->trace("%s->{%s} = %s", $_[0], $var, $_[0]->{$var});
            return $_[0]->{$var};
        };
    }
    my $self = bless \%_self, $subclass;
    # $self->log->debug("self->{name}: '%s'", $self->{name});
    # $self->log->debug("Can 'name': '%s' [%s]", $self->can('name'), $self->name);
    return $self;
}


sub log { return 'LogUtils'; }

sub _require_mode {
    my ($self, $mode) = @_;
    $self->log->log_die("Mode '%s' not one of %s in %s", $mode, \@_modes, [caller]) unless (
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

sub app {
    my ($self) = @_;
    return $self->parent ? $self->parent->app : $self;
}

sub full_name {
    my ($self) = @_;
    my @parents = ($self->name);
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
        for my $val (@args) {
            grep { $val eq $_ } @{ $self->{enum} } or return [
                "Invalid value '%s' for option '%s'. Allowed: %s", $val, $self->name, $self->enum
            ];
        }
    }
    return;
}

#{{{ doc_* Methods for documentation
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
        $ret .= sprintf " <%s>", join('|', map { $_->doc_name($mode) } @{ $self->arguments });
    }
    return $ret;
}

sub doc_oneline {
    my ($self, $mode, %args) = @_;
    $self->_require_mode($mode);
    my $s = '';
    if ($args{parent_name}) {
        $s .= $self->doc_parent_name($mode);
    }
    $s .= sprintf("%s  %s\n", $self->doc_usage($mode), $self->synopsis);
    return $s;
}

sub doc_parent_name {
    my ($self, $mode, %args) = @_;
    $self->_require_mode($mode);
    my $parent = $self;
    my $s = '';
    while ($parent = $parent->parent) {
        $s .= sprintf "%s %s", $parent->doc_name($mode), $s;
    }
    return $s;
}

sub doc_help {
    my ($self, $mode, %args) = @_;
    $self->_require_mode($mode);
    my $indent = $args{indent} //= '  ';
    my $s = $self->doc_oneline($mode, parent => 1);
    if ($args{error}) {
        $s.= sprintf("\n[%s] %s\n",
            $self->style($mode, 'error', 'ERROR'),
            $args{error});
        return $s;
    }
    $s .= sprintf("\n%s\n\n", $self->description($mode));
    for my $comp (qw(options commands arguments)) {
        my $count = sprintf "count_%s", $comp;
        if ($self->can($count) && $self->$count) {
            $s .= sprintf("%s\n", $self->style($mode, 'heading', ucfirst($comp)));
            for (@{$self->$comp}) {
                my $help = $args{full}
                ? $_->doc_help($mode, indent => "$indent  ")
                : $_->doc_oneline($mode);
                $help =~ s/^/$indent/gmx;
                $s .= $help;
            }
        }
    }
    # $s .= "\n";
    return $s;
}
#}}}


1;
