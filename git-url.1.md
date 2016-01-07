% GIT-URL(1) git-url User Manual
% Konstantin Baierer
% January 07, 2016

# NAME

git-url - Integrate Github/Gitlab/Bitbucket into your git workflow

# SYNOPSIS

git-url [*options*] <*command*> [*URL or path or URL part*]

# DESCRIPTION

`git-url` simplifies working with remote repository hosting services such as
Github or Gitlab by making tedious tasks like cloning, forking and setting up
working environments as easy as possible.

# OPTIONS

All options can also be specified in the `config.ini`, just leave of the
leading slashes (see *FILES*).

Many options reuse standard environment variables as their default, denoted by
*ENV:VARNAME*. These environment variables can be set in a shell startup script
such as *~.zshrc* or *~/.zprofile* (for `zsh` (1)) or `~/.bashrc` or
`~/.bash_profile` (for `bash` (1)).

--debug[=*LEVEL*], ENV:*DEBUG*, DEFAULT:*"${debug}"*
:   Specify logging level. Can be one of `trace`, `debug`, `info`
    or `error`. If no level is specified, defaults to `debug`. If
    the option is omitted, only errors will be logged.

--github-user=*GITHUB_USER*, ENV:*GITHUB_USER*, DEFAULT:*-*
:   Your github user name.

--github-token=*GITHUB_TOKEN*, ENV:*GITHUB_TOKEN*, DEFAULT:*-*
:   Your private Github token. The best place to set this is in a
    shell startup file. Make sure to keep this private.

--github-api=*GITHUB_API*, ENV:*--*, DEFAULT:*"${github_api}"*
:   Base URL of the Github API to use. Meaningful only for Github
    Enterprise users.

--gitlab-api=*GITLAB_API*, ENV:*--*, DEFAULT:*"${gitlab_api}"*
:   Base URL of the Gitlab API to use.

--gitlab-user=*GITLAB_USER*, ENV:*GITLAB_USER*, DEFAULT:*-*
:   Your gitlab user name.

--gitlab-token=*GITLAB_TOKEN*, ENV:*GITLAB_TOKEN*, DEFAULT:*-*
:   Your private Gitlab token. The best place to set this is in a
    shell startup file. Make sure to keep this private.

--fork, ENV:*--*, DEFAULT:*${fork}*
:   Whether remote repositories should be forked before cloning.

--create, ENV:*--*, DEFAULT:*${create}*
:   Whether to create a remote repository if local cloen could not be found.

--browser, ENV:*BROWSER*, DEFAULT:*${browser}*
:   The web browser to open project landing pages with.

--editor, ENV:*EDITOR*, DEFAULT:*${editor}*
:   The editor to open files with.

--clone, ENV:*--*, DEFAULT:*${clone}*
:   Whether or not to clone the repository and if so from what service.

--clone_opts, ENV:*--*, DEFAULT:*"${clone_opts}"*
:   Additional command line arguments to pass to *git-clone(1)*

--no-local, ENV:*--*, DEFAULT:*${no_local}*
:   Whether to skip searching a all the directories in `repo_dir` for matching
    local repos.

--prefer-ssh, ENV:*--*, DEFAULT:*${prefer_ssh}*
:   Whether to prefer ssh URL over HTTP URL if the remote repository is owned
    by the user. If set to a true value, use *git@host:owner/repo_name* URL over
    *https://host/owner/repo_name* URL.

--base_dir=*BASEDIR*, ENV:*GITDIR*, DEFAULT:*"${base_dir}"*
:   The base directory to clone repos to and look for them.

-shell=*SHELL*, ENV:*SHELL*, DEFAULT:*the calling shell*
:   The shell to use for opening sub shells.

# LOCATIONS

A location must contain these parts:

* host
* owner
* repo_name

It can optionally contain these parts:

* path_within_repo
* line
* column

# COMMANDS

Almost all commands clone on-demand, so they respect the configuration from the *OPTIONS* and *FILES*.

## shell *location*

Clone if necessary and open a shell in the repository.

## browse *location*

Open the location in the browser.

## edit *location*

Open the location in an editor.

Examples:

    git-url edit https://github.com/kba/git-url
    git-url edit https://github.com/kba/git-url/blob/master/git-url.1.md
    git-url edit https://github.com/kba/git-url/blob/master/git-url.1.md#L121

## tmux *location*

Clone if necessary and create a new or attach to an existing `tmux(1)`
session with session name == repo name.

## tmux-ls

List all tmux sessions.

## about

Show version and build information.

## dump-config

Dump the configuration in an easy-to-parse format.

# FILES

Configuration options (see *OPTIONS*) can be specified in a configuration file
at `~/.config/git-url/config.ini`, just leave of the leading dashes. The format
is basic INI: One key-value pair per line, separated by *=* (equal sign).
Multiple values are separated by *,* (comma). Empty lines and lines prefixed
with `;` or `#` are ignored.

# SEE ALSO

`git(1)`, `curl(1)`, `perl(1)`, `tmux(1)`

Check out the Github repository for more information at 
<https://github.com/kba/git-url>.
