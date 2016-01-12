package CliApp::Plugin::Core;

use LogUtils;
use StringUtils;
use ObjectUtils;

my $log = 'LogUtils';

use parent 'CliApp::Plugin';

sub inject {
    my ($self, $app) = @_;

    push @{$app->{commands}}, {
        name => 'version',
        synopsis => 'Show version information',
        tag => 'core',
    };
}

1;
