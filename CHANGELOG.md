Change Log
==========

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [unreleased]
Added
* dump-config command
* improve man page

Fixed
* Log levels


<!-- newest-changes -->

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
[0.0.4]: ../../compare/v0.0.3...v0.0.4
[0.0.3]: ../../compare/v0.0.2...v0.0.3
[0.0.2]: ../../compare/v0.0.1...v0.0.2
[0.0.1]: ../../compare/v0.0.1...HEAD
