package CliApp::Command;
use strict;
use warnings;
use parent 'CliApp::SelfDocumenting';

use CliApp::Plugin::Core;

my $log = 'LogUtils';

my @_components = qw(command option argument plugin);
my @_components_plural = map {$_."s"} @_components;

sub new {
    my ($class, %_self) = @_;

    for (@_components_plural) {
        $_self{$_} = [] unless exists $_self{$_};
        LogUtils->log_die( "'%s' must be 'ARRAY' not '%s' %s", $_, ref $_self{$_} ) unless ref $_self{$_} && ref $_self{$_} eq 'ARRAY';
    };


    # XXX INSTANTIATE XXX
    my $self = $class->SUPER::new($class, [@_components_plural], %_self);

    if (scalar(@{$self->commands}) && scalar(@{$self->arguments})) {
        LogUtils->log_die("Cannot set both options and arguments for '%s'", $self->name);
    }

    for (@_components) {
        my $comp_class = sprintf "CliApp::%s", ucfirst $_;
        my $comp_count = sprintf "count_%ss", $_;
        my $comp_acc = sprintf "%ss", $_;
        $log->trace("%s: %s=%s", $self->name, $comp_count, $self->$comp_count);
        my $temp = $_ eq 'argument' ? [] : {};
        if ( $self->$comp_count ) {
            for (@{ $self->$comp_acc }) {
                if (ref $temp eq 'ARRAY') {
                    push @{$temp}, $comp_class->new( %{$_}, parent => $self );
                } else {
                    if ($comp_acc eq 'plugins') {
                        my $comp = ref $_ ? $_ : $_->new();
                        $temp->{ref($comp)} = $comp;
                    } else {
                        my $comp = $comp_class->new( %{$_}, parent => $self );
                        $temp->{$comp->name} = $comp;
                    }
                }
            }
            $self->{$comp_acc} = $temp;
        }
    }
    return $self;
}

sub _make_command {
    my ($self, $sub_self) = @_;

    $sub_self->{parent} = $self;

    return CliApp::Command->new(%{$sub_self});
}

1;
