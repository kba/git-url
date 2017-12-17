% GIT-URL(1) git-url User Manual
% Konstantin Baierer
% __VERSION__ (__BUILD_DATE__)

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

__OPTIONS_COMMON__

## Preference Options

These settings are best provided via the configuration file (see *FILES*) or
using environment variables since you won't need to change them often.

__OPTIONS_PREFS__

## Remote service options

These options are related to the integration of remote services. It is
recommended to set those using environment variables or the configuration
file (see *FILES*). Currently supported:

* **Github.com**

__OPTIONS_GITHUB__

* **Gitlab.com**

__OPTIONS_GITLAB__

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

__COMMANDS__

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
