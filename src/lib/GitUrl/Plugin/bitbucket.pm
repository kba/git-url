package GitUrl::Plugin::bitbucket;

use Clapp::FileUtils;
use GitUrl::PlatformPlugin;

use parent 'GitUrl::PlatformPlugin';
sub new {
    my ($class, %args) = @_;

    return $class->SUPER::new(
        synopsis => 'Bitbucket integration',
        tag => 'bitbucket',
        %args,
    );
}

sub to_url
{
    my ($cls, $self, $path) = @_;
    if (index($path, '/') == -1) {
        $self->config_requires('bitbucket_user');
        $self->log->debug("Prepending " . $self->config->{bitbucket_user});
        $path = join('/', $self->config->{bitbucket_user}, $path);
    }
    return "https://bitbucket.com/$path";
}

sub repo_create
{
    my ($cls, $self) = @_;
    Clapp::ObjectUtils->require_hash("config", $self->{config}, ['bitbucket_user', 'bitbucket_password']);
    Clapp::ObjectUtils->require_hash("location", $self, ['repo_name']);
    if ($self->{owner} ne $self->{config}->{bitbucket_user}) {
        return HELPER::log_info(
            sprintf(
                "Can only create repos for %s, not %s",
                $self->{config}->{bitbucket_user},
                $self->{owner},
            ));
    }
    my $user    = $self->{config}->{bitbucket_user};
    my $api_url = join('/', $self->{config}->{bitbucket_api}, 'repositories', $user, $self->{repo_name});
    my $password  = $self->{config}->{bitbucket_password};
    my $is_private = $self->{config}->{create_private} ? 'true' : 'false';
    my $fork_policy = $self->{config}->{bitbucket_fork_policy};
    my $json = qq(
    {
        "scm": "git",
        "is_private": "$is_private",
        "fork_policy": "$fork_policy",
        "has_issues": "true",
        "has_wiki": "true"
    });
    $json =~ s/^\s*//mxg;
    $json =~ s/\n//mxg;
    my $forkCmd = <<"EOCMD";
curl -i -s -XPOST -u $user:$password -H "Content-Type: application/json" \\
$api_url \\
-d '$json'
EOCMD
    my $resp = Clapp::FileUtils->qx($forkCmd);
    if ([ split("\n", $resp) ]->[0] !~ 201) {
        HELPER::log_die("Failed to create the repo: $resp");
    }
    $self->{owner} = $user;
    return;
}

sub repo_fork
{
    my ($cls, $self) = @_;
    HELPER::require_config($self->{config}, 'bitbucket_user', 'bitbucket_token');
    if ($self->{owner} eq $self->{config}->{bitbucket_user}) {
        HELPER::log_info("Not forking an owned repository");
        return;
    }
    my $api_url = join(
        '/', $self->{config}->{bitbucket_api}, 'repos', $self->{owner}, $self->{repo_name},
        'forks'
    );
    my $user    = $self->{config}->{bitbucket_user};
    my $token   = $self->{config}->{bitbucket_token};
    my $forkCmd = join(
        ' ', 'curl', '-i', '-s',
        "-u $user:$token",
        '-XPOST',
        $api_url
    );
    my $resp = Clapp::FileUtils->qx($forkCmd);
    if ([ split("\n", $resp) ]->[0] !~ 202) {
        HELPER::log_die("Failed to fork the repo: $resp");
    }
    $self->{owner} = $user;
    return;
}

1;
