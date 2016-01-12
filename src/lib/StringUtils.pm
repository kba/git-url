package StringUtils;
use LogUtils;

#----------------
#
# String helpers
#
#----------------

sub unindent
{
    my ($cls, $amount, $str) = @_;
    # $str =~ s/\n*\z//mx;
    # $str =~ s/\A\n+//mx;
    $str =~ s/^\x20{$amount}//mxg;
    return $str;
}

sub human_readable
{
    my ($cls, $val) = @_;
    return !defined $val
      ? 'NONE'
      : ref $val ? ref $val eq 'ARRAY'
          ? sprintf("%s", join(",", @{$val}))
          : ref $val eq 'HASH'
            ? sprintf("%s", join(',', map {join ':', $_, $val->{$_}} sort keys %{$val}))
            : HELPER::log_die 'Unsupported ref type ' . ref $val
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
    my ($cls, $style, $str, @args) = @_;
    unless ($styles->{$style}) {
        log_die("Unknown style '$style' at " . join(' ', caller));
    }
    return colored(sprintf($str, @args), $styles->{$style});
}


1;
