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
    my ($self, %args) = @_;
    $self->_require_mode(%args);
    (my $optname = $self->name) =~ s/_/-/gmx;
    return $self->style($args{mode}, $self->style, "--%s", $optname);
}

sub doc_usage {
    my ($self, %args) = @_;
    # $self->log->debug('HERE: %s', $self->doc_usage($mode));
    $self->_require_mode(%args);
    my $s = '';
    $s .= $self->doc_name(%args);
    if ($self->can('enum') && $self->enum) {
        my @vals;
        for my $val (@{ $self->enum }) {
            if ($val eq $self->default) {
                push @vals, $self->style($args{mode}, 'value-default', $val);
            } else {
                push @vals, $self->style($args{mode}, 'value', $val);;
            }
        }
        $s .= sprintf "=<%s>", join('|', @vals);
    }
    return $s;
}

1;
