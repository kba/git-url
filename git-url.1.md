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

## General Options

These are the most common options you should override on the command line as
necessary

--debug[=*LEVEL*], ENV:*DEBUG*, DEFAULT:*"${debug}"*
:   Specify logging level. Can be one of `trace`, `debug`, `info`
    or `error`. If no level is specified, defaults to `debug`. If
    the option is omitted, only errors will be logged.

--fork, ENV:*--*, DEFAULT:*${fork}*
:   Whether remote repositories should be forked before cloning.

--create, ENV:*--*, DEFAULT:*${create}*
:   Whether to create a remote repository if local cloen could not be found.

--clone, ENV:*--*, DEFAULT:*${clone}*
:   Whether or not to clone the repository and if so from what service.

--no-local, ENV:*--*, DEFAULT:*${no_local}*
:   Whether to skip searching a all the directories in `repo_dir` for matching
    local repos.

--prefer-ssh, ENV:*--*, DEFAULT:*${prefer_ssh}*
:   Whether to prefer ssh URL over HTTP URL if the remote repository is owned
    by the user. If set to a true value, use *git@host:owner/repo_name* URL over
    *https://host/owner/repo_name* URL.

## Preference Options

These settings are best provided via the configuration file (see *FILES*) or
using environment variables since you won't need to change them often.

--browser, ENV:*BROWSER*, DEFAULT:*${browser}*
:   The web browser to open project landing pages with.

--editor, ENV:*EDITOR*, DEFAULT:*${editor}*
:   The editor to open files with.

--base_dir=*BASEDIR*, ENV:*GITDIR*, DEFAULT:*"${base_dir}"*
:   The base directory to clone repos to and look for them.

-shell=*SHELL*, ENV:*SHELL*, DEFAULT:*the calling shell*
:   The shell to use for opening sub shells.

--clone_opts, ENV:*--*, DEFAULT:*"${clone_opts}"*
:   Additional command line arguments to pass to *git-clone(1)*

## Remote service options

These options are related to the integration of remote services. It is
recommended to set those using environment variables or the configuration
file (see *FILES*). Currently supported:

* **Github.com**

--github-api=*GITHUB_API*, ENV:*--*, DEFAULT:*"${github_api}"*
:   Base URL of the Github API to use. Meaningful only for Github
    Enterprise users.

--github-user=*GITHUB_USER*, ENV:*GITHUB_USER*, DEFAULT:*-*
:   Your github user name.

--github-token=*GITHUB_TOKEN*, ENV:*GITHUB_TOKEN*, DEFAULT:*-*
:   Your private Github token. The best place to set this is in a
    shell startup file. Make sure to keep this private.
    For a guide on how to set up a private access token, please refer to
```
<https://help.github.com/articles/creating-an-access-token-for-command-line-use/>
```

* **Gitlab.com**

--gitlab-api=*GITLAB_API*, ENV:*--*, DEFAULT:*"${gitlab_api}"*
:   Base URL of the Gitlab API to use.

--gitlab-user=*GITLAB_USER*, ENV:*GITLAB_USER*, DEFAULT:*-*
:   Your gitlab user name.

--gitlab-token=*GITLAB_TOKEN*, ENV:*GITLAB_TOKEN*, DEFAULT:*-*
:   Your private Gitlab token. The best place to set this is in a
    shell startup file. Make sure to keep this private.

    You can find your personal access token by browsing to
```
<https://gitlab.com/profile/account>
```

# LOCATIONS

Most commands expect a location:

## URL of a repository or a file within a repository

If the location begins with *http:*, *https:* or *git@*, it is interpreted as
the URL to a remote repository or a file within that remote repository. Fragments
are parsed as offsets within a file.

Examples:

    git-url shell https://github.com/kba/git-url
    -> clone on-demand and open shell in cloned local repository

    git-url edit https://github.com/kba/git-url/blob/master/git-url.1.md#L123
    -> clone on-demand and edit git-url/git-url.1.md at line 123

## Path to a local repository or a file within a local repository:

Examples:

    git-url tmux /home/me/my-repo/
    ->  Create or re-attach to a tmux session named 'my-repo'

    git-url browse my-repo/file.html
    ->  Open the latest version of file.html in the remote service that hosts my-repo

## Shorthand for a remote repository

If the location is neither an (existing) file nor a URL, git-url interprets it
as a shorthand notation for a remote repository. The syntax is

    [owner/]repo-name

The *owner* defaults to either the *--github_user* or the *gitlab_user* config
option, depending on the config setting of *--clone* (Default:. "${clone}").

Examples:

    git-url shell kba/git-url
    ->  clone https://github.com/kba/git-url on-demand and open a shell in the
        local repository

    GITHUB_USER=YOURNAME git-url shell my-repository
    ->  Clone https://github.com/YOURNAME/my-repository on-demand if that exists
        remotely and open a shell in the local repository

    git-url --github_user=YOURNAME --create shell my-repository
    ->  Same as before, but optionally create https://github.com/YOURNAME/my-repository
        remotely using the API if it doesn not exist yet.

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

Example:

    # use iceweasel as browser
    browser = iceweasel

    github_user = MYUSERNAME

    ; change the default base repo dirs
    repo_dir = ~/projects,~/dotfiles

# SEE ALSO

`git(1)`, `curl(1)`, `perl(1)`, `tmux(1)`

Check out the Github repository for more information at 
<https://github.com/kba/git-url>.
