package GitUrl::Location;
use strict;
use warnings;

use Clapp::Utils::Object;
use Cwd qw(getcwd realpath);
use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 1;
use File::Spec;
use File::Basename;

my @_required = qw(repo_name);

sub new {
    my ($class, %args) = @_;

    Clapp::Utils::Object->validate_required_args( $class, [@_required], 
        branch => 'master',
        path_within_repo => '.',
        %args
    );

    return bless \%args, $class;
}

my $app = undef;
sub app
{
    my $class = $_[0];
    $app = $_[1] if $_[1];
    $class->log->log_die("Must call Repo->app with \$app at some point.") unless ($app);
    return $app;
}
sub log { return Clapp::Utils::SimpleLogger->get(); }

sub parse {
    my ($class, $location) = @_;
    $class->log->log_die("Repo->parse is a class method") if (ref $class);
    $class->log->log_die("Must pass location to Repo->parse") unless ($location);

    if ($location =~ /^(https?:|.+@[^\/]+:)/mx) {
        return $class->_parse_url($location);
    }
    (my $location_without_offset = $location) =~ s/:[^:]+$//;
    if (-e $location_without_offset) {
        return $class->_parse_filename(realpath $location_without_offset);
    }
    return $class->_parse_shortcut($location);
}

sub _parse_filename
{
    my ($class, $loc) = @_;
    my $path_to_repo = $class->app->utils->{git}->git_basedir($loc);
    unless ($path_to_repo) {
        $class->app->exit_error("Not in a git directory: $loc");
    }
    my $url = $class->app->utils->{git}->git_remote_url($path_to_repo);
    warn $url;
    my $self = GitUrl::Location->_parse_url( $url );
    $self->{path_to_repo} = $path_to_repo;
    $self->{branch} = $class->app->utils->{git}->git_current_branch($path_to_repo);
    $self->{path_within_repo} = File::Spec->abs2rel($loc, $path_to_repo);
    $self->{repo_name} = File::Basename::basename( $path_to_repo );
    $class->log->info("SELF: %s", $self);
    # $self{git_config} = $class->app->utils->{git}->git_config($loc);
    return $self;
}

sub _parse_url
{
    my ($class, $loc) = @_;
    my %self;
    if ($loc =~ m,://,mx) {
        ($self{scheme}) = $loc =~ m,^(.*?)://,gmx;
        $loc =~ s,^.*?://,,gmx;
    } else {
        $self{scheme} = 'ssh';
    }
    my @segments = split(m(/)mx, $loc);
    if ($loc =~ /@/mx) {
        my ($auth_user_and_password) = split(m/@/mx, $loc);
        ($self{auth_user}, $self{auth_password}) = split(m/:/mx, $auth_user_and_password);
        $loc =~ s/^.*@//mx;
    }
    ($self{host}) = $loc =~ m/^(.+?)[:\/]/mx;
    $loc =~ s/^.+?[:\/]//mx;
    my $plugin = $class->app->get_plugin_by_host( $self{host} );
    if ($plugin && $plugin->can('parse_url_path')) {
        %self = (%self, %{ $plugin->parse_url_path($loc) });
    }
    ($self{owner}, $loc) = split('/', $loc, 2);
    ($self{repo_name}, my $path_within_repo) = split('/', $loc, 2);
    ($self{path_within_repo}, $self{line}) = split('#', $loc, 2);
    $self{line} =~ s/[^\d]//gmx if $self{line};
    return GitUrl::Location->new(%self);
}

sub _parse_shortcut {
    my ($class, $loc) = @_;
    my %self;
    # warn Dumper $class->app->config;
    for (keys %{ $class->app->get_config("host_aliases") }) {
        if ($loc =~ m,^$_[/:],mx) {
            $loc = sprintf("%s/%s",
                $class->app->get_config("host_aliases")->{ $_ },
                substr($loc, length($_) + 1)
            );
            last;
        }
    }
    ($loc, $self{path_within_repo}) = split(m,:,mx, $loc, 2);
    $self{path_within_repo} ||= '.';
    my @segments = split(m,/,mx, $loc, 3);
    if (scalar @segments == 3) {
        @self{'host', 'owner', 'repo_name'} = @segments;
    # } elsif (scalar @segments == 2) {
        # @self{'host', 'owner', 'repo_name'} = ($class->app->get_config("clone_from"), @segments);
    # } else {
        # @self{'host', 'repo_name'} = ($class->app->get_config("clone_from"), @segments);
        # my $plugin = $class->app->get_plugin_by_host( $self{host} );
        # if ($plugin) {
            # $self{owner} = $class->app->get_config( $plugin->name . '_owner' };
        # }
    } else {
        ($self{repo_name}) = @segments;
    }
    my $self = GitUrl::Location->new(%self);
    if ($self->path_to_repo) {
        return GitUrl::Location->parse($self->path_to_repo);
    }
    return $self;
}

sub get_shortcut {
    my ($self) = @_;
    if ($self->{host}) {
        my $plugin = $self->get_plugin();
        my $host = $self->{host};
        if ($plugin) {
            $host = $plugin->alias_for_host($self->{host});
        }
        return sprintf("%s/%s/%s", $host, $self->{owner}, $self->{repo_name});
    }
    return sprintf("%s/%s", $self->{owner}, $self->{repo_name});
}

sub get_plugin {
    my ($self, %args) = @_;
    unless ($self->{host}) {
        if ($args{exit}) {
            $self->app->exit_error("Not on a remote tracking branch: %s", $self);
        }
        return;
    }
    my $plugin = $self->app->get_plugin_by_host( $self->{host} );
    unless ($plugin) {
        if ($args{exit}) {
            $self->app->exit_error("Not supported by any plugin: %s", $self->{host});
        }
        return;
    }
    return $plugin;
}

sub browse_url {
    my ($self) = @_;
    return $self->get_plugin(exit => 1)->browse_url($self);
}

sub clone_url {
    my ($self) = @_;
    return $self->get_plugin(exit => 1)->clone_url($self);
}

sub path_to_repo {
    my ($self) = @_;
    if ($self->{path_to_repo} && -d $self->{path_to_repo}) {
        return $self->{path_to_repo};
    }
    my @basedirs = @{ $self->app->get_config("repo_dirs") };
    my @patterns = @{ $self->app->get_config("repo_dir_patterns") };
    my @additional_basedirs;
    if ($self->app->get_config("fuzzy") > 0) {
        for my $basedir (@basedirs) {
            for my $pat (@patterns) {
                for my $plugin (@{ $self->app->platform_plugins }) {
                    for my $host (@{ $plugin->get_hosts }) {
                        for my $org (@{ $plugin->get_orgs }) {
                            my $subdir = $self->app->utils->{string}->fill_template("$basedir/$pat", {
                                host => $host,
                                owner => $org,
                            });
                            next if $subdir =~ m/%/mx;
                            push @additional_basedirs, $subdir;
                        }
                    }
                }
            }
        }
    }
    for my $basedir (@basedirs) {
        for (@patterns) {
            my $subdir = $self->app->utils->{string}->fill_template("$basedir/$_", $self);
            next if $subdir =~ m/%/mx;
            if (-d $subdir) {
                $self->{path_to_repo} = $subdir;
                return $subdir;
            }
        }
        for (@additional_basedirs) {
            my $subdir = $self->app->utils->{string}->fill_template($_, $self);
            next if $subdir =~ m/%/mx;
            if (-d $subdir) {
                $self->{path_to_repo} = $subdir;
                return $subdir;
            }
        }
    }
}

sub full_path {
    my ($self) = @_;
    return $self->{path_to_repo} if $self->{path_within_repo} eq '.';
    return sprintf("%s/%s", $self->{path_to_repo}, $self->{path_within_repo});
}

sub clone {
    my ($self) = @_;
    if ($self->path_to_repo) {
        $self->log->info( "Repo already cloned: '%s'.", $self->path_to_repo );
        if (!$self->app->get_config("force")) {
            return;
        }
    }
    my $app = $self->app;
    my $plugin = $self->get_plugin(exit=>0) || $app->plugins->{ $app->get_config("default_platform") };
    $plugin->clone_repo($self);
    if (! $self->path_to_repo && $app->get_config("create")) {
        $self->log->info("Creating %s", $self->get_shortcut);
        $plugin->create_repo($self);
        $plugin->clone_repo($self);
    }
    if (! $self->path_to_repo) {
        $self->app->exit_error("Failed to clone or create.");
    }
}

1;
