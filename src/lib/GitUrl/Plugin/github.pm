package GitUrl::Plugin::github;

use Clapp::Utils::File;
use GitUrl::PlatformPlugin;

use parent 'GitUrl::PlatformPlugin';

sub name { return 'github'; };
sub default_api { return 'https://api.github.com'; }

sub new {
    my ($class, %args) = @_;

    return $class->SUPER::new(
        synopsis     => 'Github integration',
        hosts        => ['github.com'],
        host_aliases => { 'gh' => 'github.com' },
        %args,
    );
}

sub clone_repo
{
    my ($self, $loc, $dir) = @_;
    $loc->{host} //= 'github.com';
    $loc->{owner} //= $self->app->get_config("github_user");
    return $self->SUPER::clone_repo($loc, $dir);
}

sub create_repo
{
    my ($self, $loc) = @_;
    $self->require_config($self->app, 'github_user', 'github_token');
    if (! grep { $_ eq $loc->{owner} } @{ $self->get_orgs } ) {
        $self->exit_error( "Can not create repo for org '%s'. Allowed: %s",
            $loc->{owner}, $self->get_orgs );
    }
    my $fmt = qq(
        curl -i -s -XPOST -u '%s:%s'
        -H "Content-Type: application/json"
        -H "Accept: application/vnd.github.v3+json"
        '%s'
        -d '{
            "name": "%s",
            "private": %s
        }'
    );
    $fmt =~ s/\n\s*/ /gmx;
    my $cmd = sprintf($fmt,
        $self->get_user,
        $self->get_token,
        # sprintf("%s/orgs/%s/repos", $self->get_api, $loc->{owner}),
        sprintf("%s/user/repos", $self->get_api),
        $loc->{repo_name},
        $self->app->get_config("private") ? 'true' : 'false'
    );
    $self->log->info($cmd);
    my $resp = $self->app->get_utils("file")->qx($cmd);
    if ([ split("\n", $resp) ]->[0] !~ 201) {
        $self->exit_error("Failed to create the repo: $resp");
    }
    return;
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
