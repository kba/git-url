package Clapp::Argument;
use strict;
use warnings;
use parent 'Clapp::SelfDocumenting';

sub new {
    my ($cls, %self) = @_;

    if ($self{required}) {
        if (exists $self{default}) {
            $cls->log->log_die("A required argument cannot have a default: %s", \%self);
        }
        $self{default} = undef;
    }
    $self{repeatable} //= undef;

    return $cls->SUPER::new($cls, [qw(required default repeatable)], %self);
}

sub doc_usage {
    my ($self, %args) = @_;
    $self->_require_mode(%args);
    my $mode = $args{mode};
    my $ret = " ";
    $ret .= $self->required ? '<' : '[';
    my $style = sprintf("argument-%s", $self->required ? 'required' : 'optional');
    $ret .= sprintf("%s", $self->style($args{mode}, $style, $self->name));
    # $ret .= '?' unless ($self->required);
    $ret .= '...' if $self->repeatable;
    # if (! $self->required) {
    #     $ret .= $self->style($args{mode}, 'default', " %s", $self->human_readable_default);
    # }
    $ret .= $self->required ? '>' : ']';
    return $ret;
}

1;
