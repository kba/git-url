package Clapp::Command;
use strict;
use warnings;
use parent 'Clapp::SelfDocumenting';

use Clapp::FileUtils;

use Clapp::Option;
use Clapp::Argument;

my $INI_CACHE = {};
our @_components;

BEGIN {
#{{{ setup get_*, count_*, add_*
    use List::Util qw(first);
    no strict 'refs';
    @_components = qw(command option argument);
    for my $var (@_components) {
        my $plural = $var .'s';
        my $class = sprintf "Clapp::%s", ucfirst $var;

        my $count_method = sprintf "%s::count_%s", __PACKAGE__, $plural;
        my $get_method = sprintf "%s::get_%s", __PACKAGE__, $var;
        my $add_method =  sprintf "%s::add_%s", __PACKAGE__, $var;

        *{$count_method} = sub {
            use strict 'refs';
            return scalar(@{ $_[0]->{$var.'s'} });
        };

        *{ $get_method } = sub {
            use strict 'refs';
            my $self = shift;
            my $name = $_[0];
            # $self->log->log_die("Must pass value to " . $get_method) unless $name;
            return unless $name;
            if (scalar @_ == 0) {
                warn "Nothing passed too get_" . $var;
            } elsif (scalar @_ == 1) {
                return first { $_->name eq $name } @{ $self->{$plural} };
            } else {
                # TODO
                $self->log->log_die("Not implemented: get_$var with multiarg/hash");
            }
        };

        *{ $add_method } = sub {
            use strict 'refs';
            my $self = shift;
            my %def = ( ref $_[0] && ref $_[0] eq $class )
                ? %{ $_[0] }
                : @_;
            push @{ $self->{$plural} }, $class->new(%def, parent => $self);
        };
    }
#}}}
}
#{{{ new
sub new {
    my ($class, %args) = @_;

    for (@_components) {
        my $plural = $_ . 's';
        $args{$plural} = [] unless exists $args{$plural};
        unless ( ref $args{$plural} && ref $args{$plural} eq 'ARRAY' ) {
            $class->log->log_die( "'%s' must be 'ARRAY' not '%s' %s",
                $plural, ref $args{$plural} );
        }
    }

    # $self->config
    $args{config} //= {};
    if (exists $args{config} && (!ref $args{config} || ref $args{config} ne 'HASH')) {
        $class->log->log_die("'%s' must be 'HASH' not '%s' %s", 'config', ref $args{config});
    }

    # $self->exec
    if (!($args{exec} && ref $args{exec} && ref $args{exec} eq 'CODE')) {
        $class->log->log_die("Must either implement a 'exec' method or pass a 'exec' CODEREF for command %s", \%args);
    }

    # $self->count_commands XOR $self->count_arguments
    if (scalar(@{$args{commands}}) > 0 && scalar @{$args{arguments}} > 0) {
        $class->log->log_die("Cannot set both commands and arguments for '%s'", $args{name});
    }

    # Instantiate
    my $self = $class->SUPER::new($class, [], %args);

    # default config
    $self->{default_ini} = sprintf "%s/.config/%s/config.ini", $ENV{HOME}, $self->full_name;

    # call add_* for command, argument, option
    for my $comp_type (@_components) {
        my $plural = $comp_type . 's';
        my $add_method = sprintf "%s::add_%s", __PACKAGE__, $comp_type;
        my $before = delete $self->{$plural};
        $self->{$plural} = [];
        for my $def (@{$before}) {
            $self->$add_method(%{$def});
        }
    }

    return $self;
}
#}}}
#{{{ configure
sub configure {
    my ($self, $argv, @inis) = @_;
    $self->log->trace("%s#configure %s, %s", $self->full_name, $argv, \@inis);
    $argv //= [];
    $inis[0] //= $self->{default_ini};

    # 1) Defaults
    $self->{config} = $self->optparse_default;
    # 3) Files
    push @inis, $self->config->{ini} if ($self->config->{ini});
    $self->optparse_ini( $_ ) for (@inis);
    # 5) ARGV
    $self->optparse_argv($argv);

    # configure sub commands
    my @to_parse = ();
    for my $cmd (@{ $self->commands }) {
        # TODO aliases
        if (scalar(@{ $argv }) && $argv->[0] eq $cmd->name ) {
            push @to_parse, shift @{ $argv };
            $cmd->configure($argv, @inis);
        } else {
            $cmd->configure([], @inis);
        }
    }
    unshift @{ $argv }, @to_parse;
}
#}}}
#{{{ option parsing
sub optparse_default {
    my ($self) = @_;
    my $ret = {};
    for my $opt (@{ $self->options }) {
        if (ref $opt->default and ref $opt->default eq 'CODE') {
            $ret->{ $opt->name } = $opt->default->( $self );
        } else {
            $ret->{ $opt->name } = $opt->default;
        }
        if ($opt->env && $ENV{ $opt->env }) {
            $self->log->trace("Setting '%s' from ENV '%s' = '%s'", $opt->full_name, $opt->env, $ENV{ $opt->env });
            $ret->{ $opt->name } = $ENV{ $opt->env };
        }
    }
    # $self->log->trace("DEFAULT: %s", $ret);
    return $ret;
}

sub optparse_ini {
    my ($self, $filename) = @_;
    $self->log->trace("%s#optparse_ini $filename", $self->full_name);
    unless (exists $INI_CACHE->{$filename}) {
        unless (-r $filename) {
            $self->log->warn("No such INI file: $filename");
            $INI_CACHE->{$filename} = {};
            return;
        };
        my $ctx = '';
        my $sections = {$ctx=>[]};
        my $cur_section = $sections->{$ctx};
        for my $line ( grep { !( /^\s*$/mx || /^\s*[#;]/mx ) } @{ Clapp::FileUtils->slurp($filename) } ) {
            if ($line =~ m/^\[/mx) {
                ($ctx = $line) =~ s/^\s*\[(.*)\]/$1/mx;
                my $rootname = $self->app->name;
                $ctx =~ s/^$rootname\.?//mx;
                $cur_section = $sections->{$ctx} = [];
                next;
            }
            push @{$cur_section}, $line
        };
        # $self->log->debug("By Section: %s", $sections);
        $INI_CACHE->{$filename} = $sections;
    }
    # $self->log->debug(" IAM %s", $self->full_name);
    # $self->log->info("%s", $INI_CACHE->{$filename}->{ $self->full_name });
    if (exists $INI_CACHE->{$filename}->{ $self->full_name }) {
        $self->optparse_kv( @{ $INI_CACHE->{$filename}->{ $self->full_name } });
    }
    # my $is_root = ! $self->parent;
    return $self;
}

sub optparse_argv {
    my ($self, $argv) = @_;
    $self->log->trace("%s#optparse_argv: %s", $self->full_name, $argv);
    my @args_to_parse;
    while (my $arg = shift @{ $argv }) {
        if ($arg eq '--') {
            last;
        }
        if ($arg !~ m/^--/mx) {
            unshift @{$argv}, $arg;
            last;
        }
        push @args_to_parse, $arg;
    }
    $self->optparse_kv( @args_to_parse );
}

sub optparse_kv {
    my ($self, @kvpairs) = @_;
    $self->log->trace("%s#optparse_kv: %s k-v-pairs", $self->full_name, scalar @kvpairs);
    for (@kvpairs) {
        s/^\s+|\s+$//gmx;
        s/^-*//mx;
        my ($k, $v) = split /\s*=\s*/mx, $_, 2;
        $k =~ s/[^a-zA-Z0-9]/_/mxg;
        if ($k =~ m/^no/ && $self->get_option(substr($k, 2))) {
            $k = substr($k, 2);
            $v = 0;
        }
        else {
            $v //= 1;
        }
        unless ($self->get_option($k)) {
            $self->log->log_die("No such option '%s' for cmd '%s'", $k, $self->full_name);
        }
        my $opt = $self->get_option($k);
        if ($opt->{ref}) {
            my @split_values;
            for (split(/\s*,\s*/mx, $v)) {
                # resolve tilde ~ to HOME
                s/\A~/$ENV{HOME}/mx;
                s/([,:]\s*)~/$1$ENV{HOME}/mxg;
                # remove trailing slashes
                s/\/$//mx;
                s/\/(\s*[,:])/$1/mx;
                push @split_values, $_;
            }
            if ($opt->{ref} eq 'ARRAY') {
                $v = \@split_values;
            } elsif ($opt->{ref} eq 'HASH') {
                $v = { map { split /\s*=\s*/mx } @split_values };
            }
        } elsif ($opt->{boolean}) {
            $v = undef if $v eq 'false';
            $v = defined $v ? 1 : 0;
        }
        my $invalid = $opt->validate($v);
        if ($invalid) {
            $self->log->log_die(@{$invalid});
        }
        if ($opt->{ref} && $opt->{ref} eq 'HASH') {
            $self->config->{$k} //= {};
            $self->config->{$k} = { %{$self->config->{$k}}, %{ $v } };
        } else {
            $self->config->{$k} = $v;
        }
    }
}
#}}}
#{{{ exec
sub exec {
    my ($self, $argv) = @_;
    if (scalar @{$argv}) {
        if (!($self->count_arguments || $self->count_commands)) {
            $self->log->log_die("Command '%s' expects neither arguments nor subcommands: %s", $self->full_name, $argv);
        } elsif ($self->count_commands) {
            my $cmd_name = shift @{ $argv };
            my $cmd = $self->get_command( $cmd_name );
            unless($cmd) {
                $self->log->log_die("No such command '%s' in %s", $cmd_name, $self->name);
            }
            $self->log->trace("%s->exec(%s)", $self->name, $cmd->full_name);
            return $cmd->exec( $self, $argv );
        }
    }
    $self->{exec}->( $self, $argv );
}
#}}}


1;
