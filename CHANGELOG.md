Change Log
==========

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## TODO
* Prompt before creating remotely

## [unreleased]
Added
Changed
Fixed
Removed

<!-- newest-changes -->
## [0.2.0] - 2017-08-08
Added
* `readme` command
* `ls-abs` command
Fixed
* more flexible shortcut to url parsing
* added comments and folds throughout

## [0.1.1] - 2016-06-07
Added
* Basic Support for Bitbucket
* zsh completion
* list_repos command
Changed
* Auto-generate config.ini
Fixed
* Missing required args errro

## [0.1.0] - 2016-01-10
Added
* Script to generate man page sections, integrated in Makefile
* Plugins can add options to the RepoLocator class
Fixed
* Makefile: smarter \*-home target
* Project setup: Source files under src/{lib,bin,man}, directory-local install with symlinks
Changed
* Cleaner interface for commands and options
* Documentation for CLI and man page in code
* Help for both options and commands
* Transitioned codebase to proper setup
* OOP code for commands, options, plugins
* HELPER::style as a wrapper for colored
Removed
* Superfluous tmux-ls command (tmux without argument does the same now)
* dump-config not required anymore

## [0.0.7] - 2016-01-07
Added
* man page almost complete
Fixed
* missing second clone after creating repositories 

## [0.0.6] - 2016-01-07
Fixed
* rel2abs was in the wrong package

## [0.0.5] - 2016-01-07
Added
* dump-config command
* improve man page
* Gitlab API support for creating repos
Changed
* Extracted Github/Gitlab specific functionality to resp. packages
Fixed
* Log levels
* Extended man page coverage of config defaults / commands


## [0.0.4] - 2015-12-25
Added
* tmux-ls command
* man page
* README
* --no-local option
* --create option

Changed
* Allow no-path constructor

Fixed
* tmux attach to existing session instead of clone if possible

## [0.0.3] - 2015-12-22
Added
* --fork option to work with Github API
* option to prefer git@ over https://
* configurable clone opts
* CLI overrideable config

Fixed
* Simplified code to use $self instead of $location in general

## [0.0.2] - 2015-12-22
Added
* `show` command
* repo_dirs: simple option to look for repos in specific dirs

Changed
* Install to `~/.local/bin/`

Fixed
* Log levels

## [0.0.1] - 2015-12-22
Added
* Initial commit

<!-- link-labels -->
[0.2.0]: ../../compare/v0.1.1...v0.2.0
[0.1.1]: ../../compare/v0.1.0...v0.1.1
[0.1.0]: ../../compare/v0.0.7...v0.1.0
[0.0.7]: ../../compare/v0.0.6...v0.0.7
[0.0.6]: ../../compare/v0.0.5...v0.0.6
[0.0.5]: ../../compare/v0.0.4...v0.0.5
[0.0.4]: ../../compare/v0.0.3...v0.0.4
[0.0.3]: ../../compare/v0.0.2...v0.0.3
[0.0.2]: ../../compare/v0.0.1...v0.0.2
[0.0.1]: ../../compare/v0.0.1...HEAD
