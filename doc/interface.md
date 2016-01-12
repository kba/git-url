```
StringUtils
    style( style_name, @sprintf_args );

LogUtils
    VARS
        LOGLEVEL
        LOGLEVELS
    METHODS
        dump( $thing )
        log_trace(@sprintf_args)
        log_debug(@sprintf_args)
        log_info(@sprintf_args)
        log_error(@sprintf_args)
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
    doc_usage_options( )
    doc_usage_commands( )
    doc_usage_arguments( )
    doc_usage_args( )
    doc_help( mode => cli|ini|man )

Option extends SelfDocumenting
    ref=undef, env=undef

Argument extends SelfDocumenting
    required=false

Config
    Option get( );
    Map<String,Any> load(
        Map<String, Any> orig,
        file => $ini_file,
        config => \%config,
        args => \@args
    )

Command extends SelfDocumenting
    Map<String,Option> options;
    Argument[] args = [];
    Map<String,Command> commands = [];
    Config config;
    Command parent;
    CODE action;

    parse_args( @args );
    Command get_command( String cmd_name );
    Command parent( );
    Command root( );
    sub do;

App extends Command
    Plugin
    Command parent = null;
```
