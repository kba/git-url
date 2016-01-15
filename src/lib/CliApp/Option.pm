package CliApp::Option;
use strict;
use warnings;

use parent 'CliApp::SelfDocumenting';

sub new {
    my ($cls, %self) = @_;

    $self{ref} //= undef;
    $self{env} //= undef;
    $self{boolean} //= 0;

    if ( $self{ref} && $self{ref} ne 'ARRAY' && $self{ref} ne 'HASH' ) {
        $cls->log->log_die(
            "'ref' must be HASH or ARRAY or undef, not '%s'. In %s",
            $self{ref}, \%self);
    }

    return $cls->SUPER::new($cls, [qw(ref env default)], %self);
}

sub full_name {
    my ($self) = @_;
    return join('--', $self->parent->name, $self->name);
}

sub doc_name {
    my ($self, $mode) = @_;
    $self->_require_mode($mode);
    (my $optname = $self->name) =~ s/_/-/gmx;
    return $self->style($mode, $self->style, "--%s", $optname);
}

sub doc_usage {
    my ($self, $mode) = @_;
    # $self->log->debug('HERE: %s', $self->doc_usage($mode));
    $self->_require_mode($mode);
    my $s = '';
    $s .= $self->doc_name($mode);
    if ($self->can('enum') && $self->enum) {
        my @vals;
        for my $val (@{ $self->enum }) {
            if ($val eq $self->default) {
                push @vals, $self->style($mode, 'value-default', $val);
            } else {
                push @vals, $self->style($mode, 'value', $val);;
            }
        }
        $s .= sprintf "=<%s>", join('|', @vals);
    }
    return $s;
}

sub doc_oneline {
    my ($self, $mode, %args) = @_;
    my $s = $self->SUPER::doc_oneline($mode, %args);
    my $default = $self->style($mode, 'default', "  [%s]", $self->parent->config->{ $self->name });
    $s =~ s/\n/$default\n/;
    return $s;
}


1;
