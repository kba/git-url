package StringUtils;
use LogUtils;
use Data::Dumper;
$Data::Dumper::Terse = 1;

#----------------
#
# String helpers
#
#----------------

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
    if ($opts{oneline} || $nr_of_nl < 8) {
        $val =~ s/$nl\s*//mxg;
    }
    $val;
}

sub human_readable
{
    my ($class, $val) = @_;
    return !defined $val
      ? 'NONE'
      : ref $val ? ref $val eq 'ARRAY' ? sprintf("%s", join(",", @{$val}))
          : ref $val eq 'HASH' ? sprintf("%s", join(',', map {join ':', $_, $val->{$_}} sort keys %{$val}))
            : LogUtils->log_die("Unsupported ref type '%s'", ref $val)
      : $val =~ /^1$/mx ? 'true'
      : $val =~ /^0$/mx ? 'false'
      :                 sprintf('"%s"', $val);
}

our $styles = {
    'option'      => 'magenta bold',
    'default'     => 'black bold',
    'command'     => 'green bold',
    'arg'         => 'yellow bold',
    'optarg'      => 'yellow italic',
    'script_name' => 'blue bold',
    'heading'     => 'underline',
    'error'       => 'bold red',
};

sub style
{
    my ($class, $style, $str, @args) = @_;
    unless ($styles->{$style}) {
        log_die("Unknown style '$style' at " . join(' ', caller));
    }
    return colored(sprintf($str, @args), $styles->{$style});
}


1;
