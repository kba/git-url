package GitUrl::Utils::Git;
use Clapp::Utils::SimpleLogger;
use Clapp::Utils::File;

use parent 'GitUrl::Utils';

my $log = Clapp::Utils::SimpleLogger->new;
my $file_utils = Clapp::Utils::File;

sub git_dir_for_filename
{
    my ($class, $path) = @_;
    if (!-d $path) {
        $file_utils->chdir(dirname($path));
    }
    else {
        $file_utils->chdir($path);
    }
    my $dir = $file_utils->qx('git rev-parse --show-toplevel 2>&1');
    chomp($dir);
    if ($? > 0) {
        $log->error($dir);
    }
    return $dir;
}

1;
