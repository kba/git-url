git-url
=======

Work with remote repositories on the Command line with ease.

Use Cases
---------

### From Github to $EDITOR in one step

You are browsing the source code of a project on the Github web site. At some point
you want the convenience of [your editor](http://vim.org).

Without `git-url`:

* Copy the URL of the repo (not the file you're currently browsing)
* Open a terminal and `cd` to an appropriate location
* `git clone` into it
* `cd` to that directory
* Open your editor
* Find the file
* Find the line

With `git-url`:

* Click the current line in the Github view and copy the whole URL
* Open a terminal and run `git url edit <URL>`. This will clone the
  repo to a sane location and open the file, including line offset.

### From Git directory to Github project in one step

To open pull requests on Github (or merge requests on Gitlab) from
a local clone:

```
git url browse .
```

### Open or reattach a Github project as a tmux session

It is very convenient to have one tmux session per project.

Executing

```
git url tmux <URL or local path of some repo>
```

* will clone the repo unless it's already cloned
* create a new session named after the repo name or
* attach to an existing session with that name if it already exists

### Open a shell in the right repository using just the repo name

If you have a repo in a place `git-url` [knows about](#repo_dirs) or on
Github/Gitlab, you can jump right into it by executing:

```
git url shell some-repo
```

This will find the repo locally or clone it if necessary, `cd` to that
directory and open a shell.

Installation
------------

Written as a single perl script without CPAN dependencies.

You will need [curl](http://curl.haxx.se/) to use the [on-demand forking feature](#fork).

To install system-wide:

```
sudo make install
```

To install into your home directory:

```
make install-home
```

Options and Configuration
-------------------------

`git-url` can be configured using command-line parameters, a configuration file
and environment variables. A commented sample configuration is installed to
`$HOME/.config/git-url/config.ini` on `make install`/`make install-home`.

See the [man page](./git-url.1.md) for more documentation.
