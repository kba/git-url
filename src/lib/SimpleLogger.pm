package SimpleLogger;
use strict;
use warnings;
use Term::ANSIColor;

my $INSTANCE = undef;

sub new {
    my ($class, %config) = @_;

    return $INSTANCE if defined $INSTANCE;

    $INSTANCE = bless {
        loglevel => 'debug',
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
            'fatal' => 'bold red',
            'error' => 'bold red',
            'warn'  => 'bold yellow',
            'info'  => 'bold green',
            'debug' => 'bold blue',
            'trace' => 'blue',
        },
        %config
    }, $class;

    return $INSTANCE;
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

sub loglevel
{
    my ($self) = shift;
    $self->{loglevel} = $_[0] if @_;
    return $self->{loglevel};
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
    return if $self->{levels}->{ $self->loglevel } < 0;
    return $self->{levels}->{$self->loglevel} >= $self->{levels}->{$level};
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
    return sprintf( "[%s] %s\n",
        colored( uc($level_name), $self->colors->{$level_name} ),
        sprintf( $fmt, map { StringUtils->dump($_) } @msgs ) );
}
sub trace { printf shift->_log( "trace", @_ ) }
sub debug { printf shift->_log( "debug", @_ ) }
sub info  { printf shift->_log( "info",  @_ ) }
sub warn  { printf shift->_log( "warn",  @_ ) }
sub error { printf shift->_log( "error", @_ ) }
sub log_die { die  shift->_log( "fatal", @_ ); }

1;
