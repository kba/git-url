package GitUrl::PlatformPlugin;
use Clapp::Utils::Object;
use strict;
use warnings;
use List::Util;
use Data::Dumper;

use parent 'Clapp::Plugin';

sub new {
    my ($class, %args) = @_;

    Clapp::Utils::Object->validate_required_args($class, ['hosts'], %args);
    Clapp::Utils::Object->validate_required_methods( $class,
        'name',
        'default_api',
        'browse_url',
        'clone_url',
        'create_repo',
    );

    return $class->SUPER::new(
        host_aliases => {},
        tag          => $class->name,
        %args
    );
}

sub get_token { my ($class) = shift; return $class->app->get_config( $class->name . '_token' ); }
sub get_user  { my ($class) = shift; return $class->app->get_config( $class->name . '_user' ); }
sub get_api   { my ($class) = shift; return $class->app->get_config( $class->name . '_api' ); }
sub get_orgs  { my ($class) = shift; return $class->app->get_config( $class->name . '_orgs' ); }
sub get_hosts  { return $_[0]->{hosts}; }

sub alias_for_host {
    my ($self, $host) = @_;
    for (keys %{ $self->{host_aliases} }) {
        my $match = $self->{host_aliases}->{$_};
        return $_ if $match eq $host;
    }
}

sub inject {
    my ($self, $app) = @_;

    my $host_aliases = $app->get_option('host_aliases');
    $host_aliases->{default} = { %{ $host_aliases->{default} }, %{ $self->host_aliases } };

    my $make_opt = sub {
        my ($opt, %args) = @_;
        $app->add_option(
            name => sprintf('%s_%s', $self->name, $opt),
            synopsis => sprintf('%s API %s', ucfirst $self->name, $opt),
            env => sprintf('%s_%s', uc $self->name, uc $opt),
            tag => $self->name,
            %args,
        );
    };

    $make_opt->('user', default =>
        $ENV{ sprintf( '%s_USER', uc $self->name ) } || sprintf( 'no-%s-user', $self->name ));
    $make_opt->('token', default => $ENV{sprintf("%s_TOKEN", uc $self->name)});
    $make_opt->('api', default => $ENV{sprintf("%s_API", uc $self->name)} || $self->default_api);
    $make_opt->('orgs', ref => ref [], default => sub {
            my %temp;
            my $user = $ENV{sprintf("%s_USER", uc $self->name)};
            if ($user) {
                $temp{$user} = 1;
            }
            my $orgs = $ENV{sprintf("%s_ORGS", uc $self->name)};
            if ($orgs) {
                $temp{$_} = 1 for (split(/\s*,\s*/mx, $orgs));
            }
            return [keys %temp];
        }
    );
}

sub clone_dir {
    my ($self, $loc) = @_;
    my $basedir = $self->app->get_config("repo_dirs")->[0];
    my $pattern = $self->app->get_config("repo_dir_patterns")->[0];
    return $self->app->get_utils("string")->fill_template("$basedir/$pattern", $loc);
}

sub clone_url_ssh
{
    my ($self, $loc) = @_;
    return sprintf("git@%s:%s/%s",
        $loc->{host},
        $loc->{owner},
        $loc->{repo_name});
}

sub clone_url_http
{
    my ($self, $loc) = @_;
    return sprintf("https://%s/%s/%s",
        $loc->{host},
        $loc->{owner},
        $loc->{repo_name});
}

sub clone_url
{
    my ($self, $loc) = @_;
    if ($self->app->get_config("prefer_ssh") && grep {$_ eq $loc->{owner} } @{ $self->get_orgs }) {
        $self->clone_url_ssh( $loc );
    }
    $self->clone_url_http( $loc );
}

sub clone_repo
{
    my ($self, $loc, $dir) = @_;
    $self->app->get_utils("file")->qx('git clone %s %s', $self->clone_url($loc), $self->clone_dir($loc));
}

sub on_configure {
    my ($self, $app) = @_;

}

1;
