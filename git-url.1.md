% GIT-URL(1) git-url User Manual
% Konstantin Baierer
% December 23, 2015

# NAME

git-url - Integrate Github/Gitlab/Bitbucket into your git workflow

# SYNOPSIS

git-url [*options*] <*command*> [*URL or path or URL part*]

# DESCRIPTION

…

# OPTIONS

All options can also be specified in the `config.ini`, just leave of the
leading slashes.

Many options reuse standard environment variables as their default, denoted
by *ENV:VARNAME*. These environment variables can be set in a shell startup script
such as `~.zshrc` (for `zsh` (1)) or `~/.bashrc` (for `bash` (1)).

--debug[=*LEVEL*], ENV:*DEBUG*, DEFAULT:*"${debug}"*
:   Specify logging level. Can be one of `trace`, `debug`, `info`
    or `error`. If no level is specified, defaults to `debug`. If
    the option is omitted, only errors will be logged.

--github-user=*GITHUB_USER*, ENV:*GITHUB_USER*, DEFAULT:*-*
:   Your github user name.

--github-api=*GITHUB_API*, ENV:*--*, DEFAULT:*"${github_api}"*
:   Base URL of the Github API to use. Meaningful only for Github
    Enterprise users.

--fork, ENV:*--*, DEFAULT:*${fork}*
:   Whether remote repositories should be forked before cloning.

--create, ENV:*--*, DEFAULT:*${create}*
:   Whether to create a remote repository if local cloen could not be found.

--no-local, ENV:*--*, DEFAULT:*${no_local}*
:   Whether to skip searching a all the directories in `repo_dir` for matching
    local repos.

--base_dir=*BASEDIR*, ENV:*GITDIR*, DEFAULT:*"${base_dir}"*
:   The base directory to clone repos to and look for them.

# COMMANDS

## shell

Open a shell in the repository.

# SEE ALSO

`git` (1), `curl` (1), `perl` (1)

Check out the Github repository for more information at 
<https://github.com/kba/git-url>.
