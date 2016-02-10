use GitUrl::Location;
use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 1;

{
    $x = GitUrl::Location->new(
        repo_name => 'foo',
        config => Clapp::Config->new(
            foo => 42
        ),
    );
}
my $config = Clapp::Config->new(
    'repo_dirs' => [
        'foo',
    ],
    fuzzy => 1,
    'repo_dir_patterns' => [
        'bar',
    ],
    'host_aliases' => {
        gh => 'github.com'
    }
);
{
    my $x = GitUrl::Location->new('foo',  { config => $config });
    warn Dumper $x;
}
