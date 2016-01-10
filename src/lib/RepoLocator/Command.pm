package RepoLocator::Command;
use strict;
use warnings;
use parent 'RepoLocator::Documenting';

my @_required_attrs = qw(name synopsis tag do);
my @_known_attrs    = qw(name synopsis tag do args long_desc);

sub new
{
    my ($cls, %_self) = @_;
    HELPER::validate_required_args($cls, \@_required_attrs, %_self);
    HELPER::validate_known_args($cls, \@_known_attrs, %_self);
    $_self{args} //= [];
    return $cls->SUPER::new(%_self);
}

sub print_help
{
    my ($self) = @_;
    $self->SUPER::print_help(@_);

    my @args = @{$self->{args}};
    if (scalar @args > 0) {
        print HELPER::style('heading', "Arguments:\n");
        for my $arg (@args) {
            print "\t";
            print $arg->{required}
              ? HELPER::style('arg',    "<%s> ", $arg->{name})
              : HELPER::style('optarg', "[%s] ", $arg->{name});
            print $arg->{synopsis};
        }
    }
    return;
}

sub print_usage
{
    my ($self) = @_;
    print HELPER::style('command', $self->{name});
    print " ";
    for my $arg (@{ $self->{args} }) {
        print $arg->{required}
          ? HELPER::style('arg',    "<%s> ", $arg->{name})
          : HELPER::style('optarg', "[%s] ", $arg->{name});
    }
    print " ";
    print $self->{synopsis};
    print "\n";
    return;
}

1;
