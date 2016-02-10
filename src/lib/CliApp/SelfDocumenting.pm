package CliApp::SelfDocumenting ;
use strict;
use warnings;
use HELPER;
use Data::Dumper;
$Data::Dumper::Terse = 1;
use Term::ANSIColor;

sub new {
    my ( $cls, %_self ) = @_;
    HELPER::validate_required_methods($cls, qw(print_usage print_help));
    return bless \%_self, $cls;
}

sub print_help
{
    my ($self, %args) = @_;
    print HELPER::style('heading', "\nUsage:\n\t");
    print HELPER::style('script-name', "%s ", $HELPER::SCRIPT_NAME);
    $self->print_usage();
    if ($self->{long_desc}) {
        my $long_desc = $self->{long_desc};
        $long_desc =~ s/^/\t/mgx;
        print colored("\nDescription:\n", 'underline');
        print $long_desc;
        print "\n";
    }
    return;
}


1;
