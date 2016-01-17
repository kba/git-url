package Clapp::Utils::Object;
use Clapp::Utils::SimpleLogger;
use Data::Dumper;
$Data::Dumper::Terse = 1;
my $log = Clapp::Utils::SimpleLogger->get();

#-------------
#
# OOP Helpers
#
#-------------

sub validate_required_methods
{
    my ($cls, $class, @required_methods) = @_;
    my @missing_methods;
    for (@required_methods) {
        unless ($class->can($_)) {
            push @missing_methods, $_;
        }
    }
    if ($missing_methods[0]) {
        $log->log_die(sprintf("Class '%s' is missing methods [%s]", $class, join(',', @missing_methods)));
    }
    return;
}

sub validate_required_args
{
    my ($cls, $class, $required_attrs, %_self) = @_;
    my @missing;
    for (@{$required_attrs}) {
        unless (exists $_self{$_}) {
            push @missing, $_;
        }
    }
    if ($missing[0]) {
        delete $_self{parent};
        $log->log_die(
            sprintf(
                "Missing args [%s] for '%s' constructor: %s",
                join(',', @missing), $class, Dumper(\%_self)));
    }
    return;
}

sub validate_known_args
{
    my ($cls, $known_attrs, %_self) = @_;
    my @unknown;
    my %known = map {$_ => $_} @{$known_attrs};
    for (keys %_self) {
        unless (defined $known{$_}) {
            push @unknown, $_;
        }
    }
    if ($unknown[0]) {
        $log->log_die(sprintf(
                "Unknown args [%s] for '%s' constructor: %s",
                join(',', @unknown), $cls, Dumper(\%_self)));
    }
    return;
}

1;
