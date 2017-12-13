package RepoLocator::Plugin::Github;
use strict;
use warnings;
use parent 'RepoLocator::Plugin';

my @_hosts = qw(github.com);

sub new {
    my ($cls, %_self) = @_;
    $_self{hosts} ||= [];
    push @{ $_self{hosts} }, @_hosts;
    return $cls->SUPER::new(%_self);
}

sub add_options
{
    my ($cls, $parent) = @_;
    $parent->add_option(
        name => 'github_api',
        usage => '--github_api=<API URL>',
        synopsis  => 'Base URL of the Github API to use.',
        long_desc => 'Base URL of the Github API to use. Meaningful only for Github Enterprise users.',
        default => 'https://api.github.com',
        tag     => 'github',
    );
    $parent->add_option(
        name => 'github_user',
        usage => '--github-user=<user name>',
        synopsis  => 'Your github user name.',
        env       => 'GITHUB_USER',
        default   => $ENV{GITHUB_USER},
        tag       => 'github',
    );
    $parent->add_option(
        name => 'github_token',
        usage => '--github_token=<token>',
        synopsis  => 'Your private github token.',
        long_desc  => HELPER::unindent(
            12, q(
            Your private github token. the best place to set this is in a shell
            startup file. Make sure to keep this private.  For a guide on how
            to set up a private access token, please refer to

            <https://help.github.com/articles/creating-an-access-token-for-command-line-use/>
            )
        ),
        env     => 'GITHUB_TOKEN',
        default => $ENV{GITHUB_TOKEN},
        tag     => 'github',
    );
    return;
}

sub create_repo
{
    my ($cls, $self) = @_;
    HELPER::require_config($self->{config}, 'github_user', 'github_token');
    HELPER::require_location($self, 'repo_name');
    if ($self->{owner} ne $self->{config}->{github_user}) {
        return HELPER::log_info(
            sprintf(
                "Can only create repos for %s, not %s",
                $self->{owner},
                $self->{config}->{github_user}));
    }
    my $api_url = join('/', $self->{config}->{github_api}, 'user', 'repos');
    my $user    = $self->{config}->{github_user};
    my $token   = $self->{config}->{github_token};
    my $json = sprintf(q('{
        "name": "%s",
        "private": true
    }')
        , $self->{repo_name}
    );
    my $forkCmd = join(
        ' ', 'curl', '-i', '-s',
        "-u $user:$token",
        '-d ', $json, 
        '-XPOST',
        $api_url
    );
    HELPER::log_info($forkCmd);
    print("<Enter> to create repository on Github, <Ctrl-C> to cancel\n");
    <>;
    my $resp = HELPER::_qx($forkCmd);
    if ([ split("\n", $resp) ]->[0] !~ 201) {
        HELPER::log_die("Failed to create the repo: $resp");
    }
    $self->{owner} = $user;
    return;
}

sub get_username { return $_[1]->{config}->{github_user} }

sub fork_repo
{
    my ($cls, $self) = @_;
    HELPER::require_config($self->{config}, 'github_user', 'github_token');
    if ($self->{owner} eq $self->{config}->{github_user}) {
        HELPER::log_info("Not forking an owned repository");
        return;
    }
    my $api_url = join(
        '/', $self->{config}->{github_api}, 'repos', $self->{owner}, $self->{repo_name},
        'forks'
    );
    my $user    = $self->{config}->{github_user};
    my $token   = $self->{config}->{github_token};
    my $forkCmd = join(
        ' ', 'curl', '-i', '-s',
        "-u $user:$token",
        '-XPOST',
        $api_url
    );
    my $resp = HELPER::_qx($forkCmd);
    if ([ split("\n", $resp) ]->[0] !~ 202) {
        HELPER::log_die("Failed to fork the repo: $resp");
    }
    $self->{owner} = $user;
    return;
}

1;
