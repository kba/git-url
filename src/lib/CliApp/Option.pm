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
        LogUtils->log_die(
            "'ref' must be HASH or ARRAY or undef, not '%s'. In %s",
            $self{ref}, LogUtils->dump( \%self ) );
    }

    return $cls->SUPER::new($cls, [qw(ref env default)], %self);
}

sub full_name {
    my ($self) = @_;
    return join('--', $self->parent->name, $self->name);
}
1;
