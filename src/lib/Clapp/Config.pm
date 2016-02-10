package Clapp::Config;
use Clapp::Utils::SimpleLogger;

my $log = Clapp::Utils::SimpleLogger->get;

sub new {
    my ($self, %config) = @_;
    return bless \%config, $self;
}

sub get {
    my ($self, $name) = @_;
    if (! ref $self) {
        $log->log_die("Clapp::Config->get is an object method");
    }
    if (! exists $self->{$name}) {
        $log->log_die("'$name' is not set in config!");
    }
    my $val = $self->{$name};
    if (ref $val) {
        if (ref $val eq 'ARRAY') {
            return wantarray ? @{$val} : $val;
        }
        elsif (ref $val eq 'HASH') {
            return wantarray ? %{$val} : $val;
        }
    }
    return $val;
}

sub set {
    my ($self, $name, $val) = @_;
    if (! ref $self) {
        $log->log_die("Clapp::Config->set is an object method");
    }
    unless ($val) {
        $log->log_die("Must pass value to Clapp::Config->set");
    }
    if (exists $self->{$name}) {
        $log->log_die("Clapp::Config is immutable, '%s' already set to '%s'", $name, $self->{$name});
    }
    $self->{$name} = $val;
}


1;
