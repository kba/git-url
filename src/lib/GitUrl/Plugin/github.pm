package GitUrl::Plugin::github;

use Clapp::Utils::File;
use GitUrl::PlatformPlugin;

use parent 'GitUrl::PlatformPlugin';

sub new {
    my ($class, %args) = @_;

    return $class->SUPER::new(
        synopsis     => 'Github integration',
        hosts        => ['github.com'],
        host_aliases => { 'gh:' => 'github.com' },
        tag          => 'github',
        %args,
    );

}

sub browse_url
{
    my ($self, $loc) = @_;
    my $url = sprintf("https://%s/%s/%s",
        $loc->{host},
        $loc->{owner},
        $loc->{repo_name},
    );
    if ($loc->{path_within_repo} ne '.') {
        if (-d $loc->full_path) {
            $url .= sprintf("/tree/%s/%s", $loc->{branch}, $loc->{path_within_repo});
        } else {
            $url .= sprintf("/blob/%s/%s", $loc->{branch}, $loc->{path_within_repo});
            if ($loc->{line}) {
                $url .= sprintf('#L%s', $loc->{line});
            }
        }
    }
    return $url;
}

1;
