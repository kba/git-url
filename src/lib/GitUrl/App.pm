package GitUrl::App;
use parent 'CliApp::App';
use GitUrl::Plugin::giturl;

sub new {
    my ($class) = @_;

    my $self = $class->SUPER::new(
        version => '__VERSION__',
        build_date => '__BUILD_DATE__',
        name => 'git-url',
        synopsis => 'Work with Git platforms',
        tag => 'app',
        plugins => [qw(
            CliApp::Plugin::cliapp
            GitUrl::Plugin::giturl
        )]
    );

    return $self;
}

my $app = GitUrl::App->new();
$app->exec([qw(help)]);

1;
