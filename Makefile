SCRIPT_NAME = git-url
VERSION = $(shell cat .version)

PREFIX = $(DESTDIR)/usr/local
BINDIR = $(PREFIX)/bin
MANDIR = $(PREFIX)/share/man/man1
CONFDIR = $(HOME)/.config/$(SCRIPT_NAME)

RM = rm -rvf
CP = cp -rv
LN = ln -si
CP_SECURE = cp -irv
MKDIR = mkdir -pv
CHMOD_AX = chmod -c a+x
PANDOC = pandoc -s -M hyphenate=false -V adjusting=false -t man

.PHONY: clean check \
	install install-bin install-man install-config uninstall \
	install-home uninstall-home

all: bin/$(SCRIPT_NAME) man/$(SCRIPT_NAME).1

# Script
LAST_COMMIT = $(shell git log --pretty=format:'%h' -n 1)
bin/$(SCRIPT_NAME): $(SCRIPT_NAME).pl Makefile
	@$(MKDIR) bin
	@$(CP) $< $@
	@sed -i 's/__SCRIPT_NAME__/$(SCRIPT_NAME)/' $@
	@sed -i 's/__VERSION__/$(VERSION)/' $@
	@sed -i 's/__BUILD_DATE__/$(shell date)/' $@
	@sed -i 's/__LAST_COMMIT__/$(LAST_COMMIT)/' $@
	@$(CHMOD_AX) $@

# Man page
man/%.1: %.1.md bin/$(SCRIPT_NAME) has-pandoc dist/gen-manpage.pl
	@$(MKDIR) man
	@cat $< | perl dist/gen-manpage.pl 2>/dev/null| $(PANDOC) -o $@

clean:
	@$(RM) bin
	@$(RM) man

# Check for installed programs
has-%:
	@which $* >/dev/null

check: has-perl has-git
	@echo "$(PATH)" | grep -q '$(BINDIR)' || { echo "BINDIR $(BINDIR) not in your PATH!" && exit 1; }
	@echo "$(MANPATH)" | grep -q '$(MANDIR)' || { echo "MANDIR $(MANDIR) not in your MANPATH!" && exit 1; }

#
# Install
#
install: bin/$(SCRIPT_NAME) man/$(SCRIPT_NAME).1
	@$(MKDIR) $(BINDIR)
	@$(CP) -t $(BINDIR) bin/$(SCRIPT_NAME)
	@$(MKDIR) $(MANDIR)
	@$(CP) -t $(MANDIR) man/$(SCRIPT_NAME).1

install-config: config.ini
	@$(MKDIR) $(CONFDIR)
	@$(CP_SECURE) -t $(CONFDIR) config.ini

install-all: install install-config

link: bin/$(SCRIPT_NAME)
	$(LN) $(PWD)/bin/$(SCRIPT_NAME) $(BINDIR)/$(SCRIPT_NAME)

#
# Uninstall
#
uninstall:
	@$(RM) $(MANDIR)/$(SCRIPT_NAME).1
	@$(RM) $(BINDIR)/$(SCRIPT_NAME)

uninstall-config:
	@echo "Ctrl-C to keep, enter to delete $(CONFDIR)?" && read x && $(RM) $(CONFDIR)

uninstall-all: uninstall uninstall-config

#
# Home install / uninstall / link
#
%-home:
	$(MAKE) PREFIX=$(HOME)/.local $*

#
# Distribution stuff
#

TODAY := $(shell date '+%Y-%m-%d')
VERSION_patch := $(shell semver bump patch --pretend)
VERSION_minor := $(shell semver bump minor --pretend)
VERSION_major := $(shell semver bump major --pretend)
bump-%: has-semver
	sed -i '/^<!-- newest-changes/a ## [$(VERSION_$*)] - $(TODAY)\
	### Added\
	### Changed\
	### Fixed\
	### Removed\
	' CHANGELOG.md
	sed -i '/^<!-- link-labels/a [$(VERSION_$*)]: ../../compare/v$(VERSION)...v$(VERSION_$*)' CHANGELOG.md
	$(EDITOR) CHANGELOG.md
	semver bump $*
	git commit -v .
	git tag -a v$(VERSION_$*) -m "Release $(VERSION_$*)"
