package CliApp::Option;
use parent 'CliApp::SelfDocumenting';

sub new {
    my ($cls, %_self) = @_;

    $self{ref} //= undef;
    $self{env} //= undef;

    return bless $cls->SUPER::new(%_self), $cls;
}

my $opt = CliApp::Option->new(
    name => 'foo',
    synopsis => 'set foo opt',
    tag => 'common',
    default => 0,
);
LogUtils->log_debug($opt->doc_usage);

1;
