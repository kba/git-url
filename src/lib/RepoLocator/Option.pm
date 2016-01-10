package RepoLocator::Option;
use strict;
use warnings;
use parent 'RepoLocator::Documenting';

my @_required_attrs = qw(name synopsis usage tag default);
my @_known_attrs    = qw(name synopsis usage tag default long_desc env csv man_usage);

sub new
{
    my ($cls, %_self) = @_;
    HELPER::validate_required_args($cls, \@_required_attrs, %_self);
    HELPER::validate_known_args($cls, \@_known_attrs, %_self);
    $_self{man_usage} ||= $_self{usage};
    return $cls->SUPER::new(%_self);
}

sub print_usage {
    my ($self) = @_;
    print HELPER::style('option', $self->{usage});
    print "  ";
    print $self->{synopsis};
    print " ";
    print HELPER::style('default', sprintf("[%s]", HELPER::human_readable_default($self->{default})));
    print "\n";
    return;
}

1;
