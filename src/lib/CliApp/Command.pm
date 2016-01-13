package CliApp::Command;
use strict;
use warnings;
use parent 'CliApp::SelfDocumenting';

my $log = 'LogUtils';


BEGIN {
    use List::Util qw(first);
    no strict 'refs';
    our @_components = qw(command option argument);
    for my $var (@_components) {
        *{ sprintf "%s::count_%ss", __PACKAGE__, $var } = sub {
            return scalar @{ $_[0]->{$var} };
        };
        *{ sprintf "%s::get_%s", __PACKAGE__, $var } = sub {
            my $self = shift;
            my $plural = $var .'s';
            if (scalar @_ == 0) {
                warn "Nothing passed too get_" . $var;
            } elsif (scalar @_ == 1) {
                return first { $_->name eq $_[0] } @{ $self->{$plural} };
            }

        };
        *{ sprintf "%s::add_%s", __PACKAGE__, $var } = sub {
            my $self = shift;
            my $plural = $var .'s';
            my $class = sprintf "CliApp::%s", ucfirst $var;
            if ( ref $_[0] && ref $_[0] eq $class ) {
                push @{ $self->{$plural} }, $_[0];
            } else {
                push @{ $self->{$plural} }, $class->new(@_, parent => $self);
            }
        };
    }
}

sub new {
    my ($class, %args) = @_;

    for (@CliApp::Command::_components) {
        my $plural = $_ . 's';
        $args{$plural} = [] unless exists $args{$plural};
        unless ( ref $args{$plural} && ref $args{$plural} eq 'ARRAY' ) {
            LogUtils->log_die( "'%s' must be 'ARRAY' not '%s' %s",
                $plural, ref $args{$plural} );
        }
    }
    if (! $class->can('do') && !( $args{do} && ref $args{do} && ref $args{do} eq 'CODE')) {
        LogUtils->log_die("Must either implement a 'do' method or pass a 'do' CODEREF for command %s", \%args);
    }
    if (scalar(@{$args{commands}}) && scalar @{$args{arguments}}) {
        LogUtils->log_die("Cannot set both options and arguments for '%s'", $args{name});
    }
    my $self = $class->SUPER::new($class, [], %args);

    for my $comp_type (@CliApp::Command::_components) {
        my $plural = $comp_type . 's';
        my $add_method = sprintf "%s::add_%s", __PACKAGE__, $comp_type;
        my $before = delete $self->{$plural};
        $self->{$plural} = [];
        for my $def (@{$before}) {
            $self->$add_method(%{$def});
        }
    }

    return $self;
}

1;
