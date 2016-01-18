use lib '../lib/';
use Clapp::Utils::String;
use Data::Dumper;

my $util = Clapp::Utils::String->new(app => undef);
warn Dumper $util->fuzzy_match('fb', [qw(foobar fooquux)]);
warn Dumper $util->fuzzy_match('fb', [qw(foobar fb fooquux)]);
