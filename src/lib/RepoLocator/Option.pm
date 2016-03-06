package RepoLocator::Option;
use strict;
use warnings;
use parent 'RepoLocator::Documenting';

my @_required_attrs = qw(name synopsis usage tag default);
my @_known_attrs    = qw(name synopsis usage tag default long_desc env csv man_usage shortcut);

sub new
{
    my ($cls, %_self) = @_;
    HELPER::validate_required_args($cls, \@_required_attrs, %_self);
    HELPER::validate_known_args($cls, \@_known_attrs, %_self);
    $_self{man_usage} ||= $_self{usage};
    $_self{shortcut} ||= {};
    return $cls->SUPER::new(%_self);
}

sub print_usage {
    my ($self) = @_;
    print HELPER::style('option', $self->{usage});
    print "  ";
    print $self->{synopsis};
    print " ";
    print HELPER::style('default', sprintf("[%s]", HELPER::human_readable_default($self->{default})));
    print "\n";
    return;
}

sub to_man {
    my ($self) = @_;
    my $desc = $self->{long_desc} || $self->{synopsis};
    $desc = ':   ' . $desc;
    $desc =  join("\n    ", split(/\n/, $desc));
    my $tpl = <<"EOMAN";

%s, ENV:*%s*, DEFAULT:%s

%s

EOMAN
    return sprintf( $tpl,
        $self->{man_usage} || $self->{usage},
        $self->{env} || '--',
        HELPER::human_readable_default($self->{default}),
        $desc
    );
}

# '--foo[bar]' \

sub to_zsh
{
    my ($self) = shift;
    my $name = $self->{name};
    my $synopsis = $self->{synopsis};
    $name =~ s/_/-/g;
    my $tpl = qq{--%s[%s]\n};
    my $out = sprintf($tpl, $name, $synopsis);
    for my $shortcut (keys %{ $self->{shortcut} }) {
        my $val = $self->{shortcut}->{$shortcut};
        my $shortcut_tpl = $tpl;
        if (length($shortcut) == 1) {
            $shortcut_tpl =~ s/--/-/;
        }
        $out .= sprintf $shortcut_tpl, $shortcut, 'Same as --' . $name . '=' . $val;
    }
    return $out;
}

# ; base_dir: Base directory where projects are stored
# ; ENV: $GITDIR
# ; base_dir     = ~/git-projects
#

sub to_ini
{
    my ($self) = shift;
    my $tpl = <<"EOINI";
; %s: %s
; ENV: %s
; %s = %s

EOINI
    return sprintf($tpl,
        $self->{name},
        $self->{synopsis},
        $self->{env} || "--",
        $self->{name},
        $self->{default} || '',
    );
}


1;
