package CliApp::Plugin::Bitbucket;
use strict;
use warnings;
use parent 'CliApp::Plugin';

my @_hosts = qw(bitbucket.org);

sub new {
    my ($cls, %_self) = @_;
    $_self{hosts} ||= [];
    push @{ $_self{hosts} }, @_hosts;
    return $cls->SUPER::new(%_self);
}

sub add_options
{
    CliApp::Config->add_option(
        name => 'bitbucket_api',
        usage => '--bitbucket-api=<API URL>',
        synopsis  => 'Base URL of the Bitbucket API to use.',
        long_desc => 'Base URL of the Bitbucket API to use.',
        default => 'https://api.bitbucket.org/2.0',
        tag     => 'bitbucket',
    );
    CliApp::Config->add_option(
        name => 'bitbucket_user',
        usage => '--bitbucket-user=<user name>',
        synopsis  => 'Your bitbucket user name.',
        env       => 'BITBUCKET_USER',
        default   => $ENV{BITBUCKET_USER},
        tag       => 'bitbucket',
    );
    CliApp::Config->add_option(
        name => 'bitbucket_fork_policy',
        usage => '--bitbucket-fork-policy=<allow_forks|no_public_forks|no_forks>',
        synopsis  => 'The fork policy for newly created repos.',
        default   => 'allow_forks',
        tag       => 'bitbucket',
    );
    CliApp::Config->add_option(
        name => 'bitbucket_password',
        usage => '--bitbucket-password=<password>',
        synopsis  => 'Your bitbucket password.',
        long_desc  => HELPER::unindent(
            12, q(
            The password for your Bitbucket account.
            )
        ),
        env     => 'BITBUCKET_PASSWORD',
        default => $ENV{BITBUCKET_PASSWORD},
        tag     => 'bitbucket',
    );
    return;
}

sub to_url
{
    my ($cls, $self, $path) = @_;
    if (index($path, '/') == -1) {
        HELPER::require_config($self->{config}, 'bitbucket_user');
        HELPER::log_debug("Prepending " . $self->{config}->{bitbucket_user});
        $path = join('/', $self->{config}->{bitbucket_user}, $path);
    }
    return "https://bitbucket.com/$path";
}

sub create_repo
{
    my ($cls, $self) = @_;
    HELPER::require_config($self->{config}, 'bitbucket_user', 'bitbucket_password');
    HELPER::require_location($self, 'repo_name');
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
    my $resp = HELPER::_qx($forkCmd);
    if ([ split("\n", $resp) ]->[0] !~ 201) {
        HELPER::log_die("Failed to create the repo: $resp");
    }
    $self->{owner} = $user;
    return;
}

sub fork_repo
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
    my $resp = HELPER::_qx($forkCmd);
    if ([ split("\n", $resp) ]->[0] !~ 202) {
        HELPER::log_die("Failed to fork the repo: $resp");
    }
    $self->{owner} = $user;
    return;
}

1;

