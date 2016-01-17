package Clapp::Utils::SimpleLogger;
use strict;
use warnings;
use Term::ANSIColor;

my $INSTANCE = {};
my $loglevel = 'debug';

sub get {
    my ($class, %config) = @_;
    my $caller = [caller 2];
    $caller->[0] =~ s/::/\//gmx;
    $config{name} //= sprintf("%s:%s",  $caller->[0], $caller->[2]);
    %config = (
        tracelevel => 'warn',
        levels => {
            'off'   => -1,
            'fatal' => 0,
            'error' => 0,
            'warn'  => 1,
            'info'  => 2,
            'debug' => 3,
            'trace' => 4,
        },
        colors => {
            'name' => 'yellow',
            'fatal' => 'bold red',
            'error' => 'bold red',
            'warn'  => 'bold yellow',
            'info'  => 'bold green',
            'debug' => 'bold blue',
            'trace' => 'blue',
        },
        %config
    );

    return $INSTANCE->{$config{name}} if exists $INSTANCE->{$config{name}};

    $INSTANCE->{$config{name}} = bless \%config, $class;

    return $INSTANCE->{$config{name}};
}

sub __stack_trace {
    my $s = shift;
    my $i = 0;
    while ($i < 10) {
        my @stack = caller $i++;
        last unless @stack;
        $s .= sprintf("\n\t in %s +%s", $stack[1], $stack[2]);
    }
    return $s;
}

sub name {
    my ($self) = @_;
    return $self->{name};
}

sub loglevel
{
    my ($self) = shift;
    $loglevel = $_[0] if $_[0];
    return $loglevel;
}

sub tracelevel
{
    my ($self) = shift;
    $self->{tracelevel} = $_[0] if @_;
    return $self->{tracelevel};
}

sub colors
{
    my ($self) = shift;
    $self->{colors} = @_ if @_;
    return $self->{colors};
}
sub levels
{
    my ($self) = shift;
    $self->{levels} = @_ if @_;
    return [sort { $self->{levels}->{$b} <=> $self->{levels}->{$a} } keys %{ $self->{levels} }];
}

sub should_log_level
{
    my ($self, $level) = @_;
    return if $self->{levels}->{ $loglevel } < 0;
    return $self->{levels}->{$loglevel} >= $self->{levels}->{$level};
}

sub should_trace_level
{
    my ($self, $level) = @_;
    return $self->{levels}->{$self->tracelevel} >= $self->{levels}->{$level};
}

sub _log
{
    my ($self, $level_name, $fmt, @msgs) = @_;
    return unless $self->should_log_level($level_name);
    if ($self->should_trace_level($level_name)) {
        $fmt = __stack_trace($fmt);
    }
    return sprintf( "[%s] %s: %s\n",
        colored( uc($level_name), $self->colors->{$level_name} ),
        colored( $self->name, $self->colors->{name} ),
        sprintf( $fmt, map { Clapp::Utils::String->dump($_) } @msgs ) );
}
sub trace { printf shift->_log( "trace", @_ ) }
sub debug { printf shift->_log( "debug", @_ ) }
sub info  { printf shift->_log( "info",  @_ ) }
sub warn  { printf shift->_log( "warn",  @_ ) }
sub error { printf shift->_log( "error", @_ ) }
sub log_die { die  shift->_log( "fatal", @_ ); }

1;
