## Clapp

Commandline Apps made purty.

```
StringUtils
    dump( $thing )
    style( style_name, @sprintf_args );

SimpleLoggers (singleton)
    METHODS
        trace(@sprintf_args)
        debug(@sprintf_args)
        info(@sprintf_args)
        error(@sprintf_args)
        log_die(@sprintf_args)

ObjectUtils
    validate_required_args
    validate_known_args
    validate_required_methods

---

SelfDocumenting
    String  name,
            synopsis,
            aliases=[]
            tag
            description=synopsis
            default

    doc_usage( )
    doc_help( mode => cli|ini|man, verbosity => [0..4] )

Option extends SelfDocumenting
    ref=undef, env=undef

Argument extends SelfDocumenting
    required=false

Command extends SelfDocumenting
    Map<String,Option> options;
    Argument[] args = [];
    Map<String,Command> commands = [];
    Config config;
    Command parent;
    CODE action;

    configure( \@ARGV );
        -> plugin.each on_configure
    Command|Argument|Option get_by_name ( name )
    Command get_[command|argument|option] ( String name )
    Command parent( )
    Command app( )
    sub exec

App extends Command
    Plugin
    Command parent = null;

Plugin extends SelfDocumenting
    inject( $self, $app )
    on_configure( $self, $app )
```

## GitUrl

```
Utils::Tmux
    list_sessions()
    create_or_attach( $sesison_name )

Utils::Git
    find_git_dir ( $file )

Repo
    parse( $str )

```
