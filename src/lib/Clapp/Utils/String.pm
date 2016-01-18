package Clapp::Utils::String;
use strict;
use warnings;
use Clapp::Utils::SimpleLogger;
use Data::Dumper;
use Term::ANSIColor;
$Data::Dumper::Terse = 1;

use parent 'Clapp::Utils';

my $log = Clapp::Utils::SimpleLogger->get();

#----------------
#
# String helpers
#
#----------------

our $styles = {
    'config'        => 'white',
    'option'        => 'magenta bold',
    'value'         => 'cyan',
    'value-default' => 'cyan bold',
    'default'       => 'black bold',
    'command'       => 'green bold',
    'arg'           => 'yellow bold',
    'app'           => 'blue bold',
    'argument'      => 'blue bold',
    'heading'       => 'underline',
    'error'         => 'bold red',
    'bold'          => 'bold',
};

sub unindent
{
    my ($class, $amount, $str) = @_;
    # $str =~ s/\n*\z//mx;
    # $str =~ s/\A\n+//mx;
    $str =~ s/^\x20{$amount}//mxg;
    return $str;
}

sub dump
{
    my ($class, $val, %opts) = @_;
    return $val unless ref $val;
    $val = Dumper($val);
    my $nl = "[\n\r]";
    my $nr_of_nl = () = $val =~ m/$nl\s*/mxg;
    $opts{maxlines} //= 10;
    if ($opts{oneline} || $nr_of_nl < $opts{maxlines}) {
        $val =~ s/$nl\s*//mxg;
    }
    # $val =~ s/\s*=>\s*/: /gmx;
    # $val =~ s/^[\[\{]/$& /gmx;
    # $val =~ s/[\]\}]$/ $&/gmx;
    $val =~ s/'?\s*,([^\s'])'?/', $1'/gmx;
    # $val =~ s/'//gmx;
    $val;
}

sub human_readable
{
    my ($class, $val) = @_;
    return !defined $val
      ? 'NONE'
      : ref $val ? ref $val eq 'ARRAY' ? sprintf("%s", join(",", map {"\"$_\""} @{$val}))
          : ref $val eq 'HASH' ? join(',', map {join ':',  map {"\"$_\""} ($_, $val->{$_})} sort keys %{$val})
            : $log->log_die("Unsupported ref type '%s'", ref $val)
      : $val =~ /^1$/mx ? 'true'
      : $val =~ /^0$/mx ? 'false'
      :                 sprintf('"%s"', $val);
}

sub style
{
    my ($class, $style, $str, @args) = @_;
    # $log->debug("Style: %s", $style);
    unless ($styles->{$style}) {
        $log->log_die("Unknown style '$style' at " . join(' ', caller));
    }
    return colored(sprintf($str, @args), $styles->{$style});
}

sub fuzzy_match
{
    my ($class, $needle, @strings) = @_;
    @strings = @{ $strings[0] } if (ref $strings[0]);
    $needle =~ s/(.)/$1.*?/gmx;
    my @matches =  grep { m/^$needle$/gmx } @strings ;
    return undef if scalar @matches == 0;
    return $matches[0] if scalar @matches == 1;
    return \@matches;
}

sub fill_template
{
    my ($self, $s, $tpl) = @_;
    for my $k (sort {length($a) <=> length($b)} keys %{ $tpl }) {
        my $v = $tpl->{$k};
        $s =~ s/%$k/$v/gmx;
    }
    return $s;
}

1;
