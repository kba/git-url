package Clapp::SelfDocumenting;
use strict;
use warnings;
use Clapp::Utils::SimpleLogger;
use Clapp::Utils::String;
use List::Util qw(first);

use Clapp::Utils::Object;

my @_required = qw(name synopsis tag parent);
our @_modes = qw(ini man cli);
my %HELP_VERBOSITY = (
    ONELINE => 0,
    USAGE => 1,
    DESCRIPTION => 2,
    HEADINGS => 3,
    FULL => 4
);

sub new {
    my ($class, $subclass, $subclass_required, %_self) = @_;

    $_self{description} //= $_self{synopsis};
    # $_self{parent} //= undef;

    Clapp::Utils::Object->validate_required_args( $subclass, [@_required, @{ $subclass_required }],  %_self );

    for my $var (keys %_self) {
        no strict 'refs';
        next if $var eq 'validate';
        next if $var eq 'exec';
        my $method = sprintf "%s::%s", $subclass, $var;
        next if __PACKAGE__->can($method);
        *{$method} = sub {
            # $self->log->trace("%s->{%s} = %s", $_[0], $var, $_[0]->{$var});
            return $_[0]->{$var};
        };
    }
    my $self = bless \%_self, $subclass;
    # $self->log->debug("self->{name}: '%s'", $self->{name});
    # $self->log->debug("Can 'name': '%s' [%s]", $self->can('name'), $self->name);
    return $self;
}

sub get_by_name {
    my ($self, $name) = @_;
    if ($name =~ '^-') {
        $name =~ s/^-*//mx;
        $name =~ s/-/_/gmx;
        $name =~ s/=.*$//gmx;
        return $self->get_option($name);
    }
    return $self->get_command($name) if ($self->commands && $self->get_command($name));
    return $self->get_argument($name) if ($self->arguments && $self->get_argument($name));
}

sub log { return Clapp::Utils::SimpleLogger->get; }

sub style {
    my ($self, $mode, $style, $str, @args) = @_;
    if (scalar @_ == 1) {
        my $ret = lc ref $self;
        $ret =~ s/^.*:://;
        return $ret;
    }
    @args = map {$self->app->utils->{string}->dump($_)} @args;
    $self->_require_mode(mode=>$mode);
    if ($mode eq 'cli') {
        return $self->app->utils->{string}->style($style, $str, @args);
    } else {
        return sprintf($str, @args);
    }
}

sub app {
    my ($self) = @_;
    return $self->parent ? $self->parent->app : $self;
}

sub full_name {
    my ($self) = @_;
    my @parents = ($self->name);
    while ($self = $self->parent) {
        unshift @parents, $self->name;
    }
    return join('.', @parents);
}

sub validate {
    my ($self, @args) = @_;
    if ($self->{validate}) {
        return $self->{validate}->( $self, @args );
    } elsif ($self->{enum}) {
        for my $val (@args) {
            grep { $val eq $_ } @{ $self->{enum} } or return [
                "Invalid value '%s' for option '%s'. Allowed: %s", $val, $self->name, $self->enum
            ];
        }
    }
    return;
}

#{{{ doc_* Methods for documentation
sub _require_mode {
    my ($self, %args) = @_;
    $self->log->log_die("Mode '%s' not one of %s", $args{mode}, \@_modes) unless (
        $args{mode} && first { $_ eq $args{mode} } @_modes
    );
}

sub doc_name {
    my ($self, %args) = @_;
    $self->_require_mode(%args);
    return $self->style($args{mode}, $self->style, $self->name);
}

sub doc_usage {
    my ($self, %args) = @_;
    $self->_require_mode(%args);
    my $mode = $args{mode};
    my $ret = '';
    $ret .= $self->doc_name(%args);
    if ($self->can('count_options') && $self->count_options) {
        if ($args{verbosity} && $args{verbosity} == 0) {
            $ret .= sprintf(" [%s]", join(' ', map { $_->doc_name(%args) } sort { $a->name cmp $b->name } @{ $self->options }));
        } else {
            $ret .= $self->style($mode, 'option', ' <options>');
        }
    }
    if ($self->can('count_commands') && $self->count_commands) {
        $ret .= sprintf " %s", join('|', map { $_->doc_name(%args) } @{ $self->commands });
    }
    if ($self->can('count_arguments') && $self->count_arguments) {
        $ret .= sprintf " <%s>", join('|', map { $_->doc_name(%args) } @{ $self->arguments });
    }
    return $ret;
}

sub exit_error {
    my ($self, $msg, @args) = @_;
    use Data::Dumper;
    $Data::Dumper::Terse = 1;
    $Data::Dumper::Indent = 1;
    print $self->doc_help(
        mode => 'cli',
        verbosity => 1,
        error => sprintf($msg, Dumper @args),
    );
    exit 1;
}

sub doc_help {
    my ($self, %args) = @_;
    $self->_require_mode(%args);
    my ($mode, $verbosity, $indent, $error) = @args{qw(mode verbosity indent error)};
    $indent //= '  ';
    $verbosity //= 1;
    $args{tag} //= 'common';

    my $s = '';
    unless ($args{skip_parent}) {
        my $parent = $self;
        while ($parent = $parent->parent) {
            $s = sprintf "%s %s", $parent->doc_name(%args), $s;
        }
    }
    my $cur = '';
    if ($self->parent && exists $self->parent->config->{ $self->name }) {
        my $val = $self->app->utils->{string}->human_readable($self->parent->config->{ $self->name });
        $cur = $self->style($args{mode}, 'default', "%s", $val);
    }
    $s .= sprintf("%s  %s %s\n", $self->doc_usage(%args), $self->synopsis, $cur);

    if ($error) {
        my $prompt = $self->style($mode, 'error', 'ERROR') .'>';
        $s.= sprintf("\n%s\n%s %s\n%s\n",
            $prompt, $prompt, $error, $prompt);
        delete $args{error};
    }
    if ($verbosity >= $HELP_VERBOSITY{USAGE}) {
        if ($verbosity >= $HELP_VERBOSITY{DESCRIPTION}) {
            $s .= sprintf("\n$indent%s\n", $self->description($mode));
        }
        my $should_nl = 0;
        for my $comp (qw(options commands arguments)) {
            my $count = sprintf "count_%s", $comp;
            if ($self->can($count) && $self->$count) {
                $should_nl = 1;
                $s .= "\n";
                my $cur_tag = '';
                for (sort { $a->tag cmp $b->tag || $a->name cmp $b->name } @{$self->$comp}) {
                    if ($args{group}) {
                        if ($_->tag ne $cur_tag) {
                            $cur_tag = $_->tag;
                            $s .= sprintf("$indent%s [%s]\n",
                                $self->style($mode, 'heading', "%s %s", ucfirst($comp)),
                                $self->style($mode, 'default', $cur_tag),
                            );
                        }
                    }
                    my $help = $_->doc_help(
                        %args,
                        skip_parent => 1,
                        indent    => "$indent  ",
                        verbosity => $verbosity - 1
                    );
                    $help =~ s/^/$indent/gmx;
                    $s .= $help;
                }
            }
        }
        $s .= "\n" if $should_nl;
    }
    return $s;
}

sub doc_version {
    my ($self, %args) = @_;
    $self->_require_mode(%args);
    my $mode = $args{mode};
    my $app = $self->app;
    my $ret = '';
    $ret .= $self->doc_usage(%args);
    $ret .= "\n";
    $ret .= sprintf( "%s %s\n",
        $self->style($mode, 'heading', 'Version:'),
        $self->style($mode, 'value',   $app->version));
    $ret .= sprintf( "%s %s\n",
        $self->style($mode, 'heading', 'Build Date:'),
        $self->style($mode, 'value',   $app->build_date));
    $ret .= sprintf( "%s %s\n",
        $self->style($mode, 'heading', 'Plugins:' ),
        $self->style($mode, 'value', "%s", [ keys %{ $app->plugins } ] )
    );
    $ret .= sprintf( "%s %s\n",
        $self->style($mode, 'heading', 'Configuration file:'),
        $self->style($mode, 'value',   $app->{default_ini}));
    $ret .= $self->style( $mode, 'heading', "Configuration:\n" );
    $ret .= sprintf( "  %s : %s\n",
        $self->style($mode, 'command', $self->name),
        $self->style($mode, 'config', $self->app->utils->{string}->dump($self->config)));
    for (@{$self->commands}) {
        $ret .= sprintf( "  %s : %s\n",
            $self->style($mode, 'command', $_->full_name),
            $self->style($mode, 'config', $self->app->utils->{string}->dump($_->config)));
    }
    return $ret;
}

#}}}


1;
