package ObjectUtils;
use LogUtils;
use Data::Dumper;
$Data::Dumper::Terse = 1;

#-------------
#
# OOP Helpers
#
#-------------

sub validate_required_methods
{
    my ($cls, @required_methods) = @_;
    my @missing_methods;
    for (@required_methods) {
        unless ($cls->can($_)) {
            push @missing_methods, $_;
        }
    }
    if ($missing_methods[0]) {
        LogUtils->log_die(sprintf("Class '%s' is missing methods [%s]", $cls, join(',', @missing_methods)));
    }
    return;
}

sub validate_required_args
{
    my ($cls, $required_attrs, %_self) = @_;
    my @missing;
    for (@{$required_attrs}) {
        unless (exists $_self{$_}) {
            push @missing, $_;
        }
    }
    if ($missing[0]) {
        LogUtils->log_die(
            sprintf(
                "Missing args [%s] for '%s' constructor: %s",
                join(',', @missing), $cls, Dumper(\%_self)));
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
        LogUtils->log_die(sprintf(
                "Unknown args [%s] for '%s' constructor: %s",
                join(',', @unknown), $cls, Dumper(\%_self)));
    }
    return;
}

1;
