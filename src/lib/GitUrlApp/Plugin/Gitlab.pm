package GitUrlApp::Plugin::Gitlab;
use strict;
use warnings;
use parent 'GitUrlApp::Plugin';

my @_hosts = qw(gitlab.com);

sub new {
    my ($cls, %_self) = @_;
    $_self{hosts} ||= [];
    push @{ $_self{hosts} }, @_hosts;
    return $cls->SUPER::new(%_self);
}

sub setup_options
{
    CliApp::Config->add_option(
        name => 'gitlab_api',
        synopsis  => 'Base URL of the Gitlab API to use.',
        usage => '--gitlab_api=<API URL>',
        default   => 'https://gitlab.com/api/v3',
        tag       => 'gitlab',
    );
    CliApp::Config->add_option(
        name => 'gitlab_user',
        usage => '--gitlab-user=<user>',
        synopsis  => 'Your Gitlab user name.',
        env       => 'GITLAB_USER',
        default   => $ENV{GITLAB_USER},
        tag       => 'gitlab',
    );
    CliApp::Config->add_option(
        name => 'gitlab_token',
        usage => '--gitlab-token=<token>',
        synopsis  => 'Your private Gitlab token.',
        long_desc  => HELPER::unindent(
            12, q(
            Your private Gitlab token. The best place to set this is in a
            shell startup file. Make sure to keep this private.

            You can find your personal access token by browsing to
            ```
            <https://gitlab.com/profile/account>
            ```)
        ),
        env     => 'GITLAB_TOKEN',
        default => $ENV{GITLAB_TOKEN},
        tag     => 'gitlab',
    );
    return;
}

sub to_url
{
    my ($self, $parent, $path) = @_;
    if (index($path, '/') == -1) {
        HELPER::require_config($parent->{config}, 'gitlab_user');
        HELPER::log_debug("Prepending " . $parent->{config}->{gitlab_user});
        $path = join('/', $parent->{config}->{gitlab_user}, $path);
    }
    return "https://gitlab.com/$path";
}

sub create_repo
{
    my ($self, $parent) = @_;
    HELPER::require_config($parent->{config}, 'gitlab_token');
    HELPER::require_location($parent, 'repo_name');
    my $api_url = join('/', $parent->{config}->{gitlab_api}, 'projects');
    my $user    = $parent->{config}->{gitlab_user};
    my $token   = $parent->{config}->{gitlab_token};
    my $forkCmd = join(
        ' ',
        'curl',
        '-i',
        '-s',
        '-H', join(':', 'PRIVATE-TOKEN', $token),
        '-X', 'POST',
        '-F', join('=', 'name',          $parent->{repo_name}),
        $api_url,
    );
    my $resp = HELPER::_qx($forkCmd);

    if ($resp !~ /201 Created/mx) {
        HELPER::log_die("Failed to create the repo: $resp");
    }
    $parent->{owner} = $user;
    return;
}

1;
