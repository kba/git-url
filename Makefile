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
PANDOC = pandoc -s -t man

.PHONY: clean check \
	install install-bin install-man install-config uninstall \
	install-home uninstall-home

all: $(SCRIPT_NAME) $(SCRIPT_NAME).1

# Script
LAST_COMMIT = $(shell git log --pretty=format:'%h' -n 1)
$(SCRIPT_NAME): $(SCRIPT_NAME).pl Makefile
	@$(CP) $< $@
	@sed -i 's/__SCRIPT_NAME__/$(SCRIPT_NAME)/' $@
	@sed -i 's/__VERSION__/$(VERSION)/' $@
	@sed -i 's/__BUILD_DATE__/$(shell date)/' $@
	@sed -i 's/__LAST_COMMIT__/$(LAST_COMMIT)/' $@
	@$(CHMOD_AX) $@

# Man page
%.1: %.1.md has-pandoc has-envsubst
	@echo "'$<' -> '$@'"
	@eval `./$(SCRIPT_NAME) dump-config |sed 's,$(HOME),~,g'|sed 's/^/export /'` && \
		cat $< | envsubst \
		| $(PANDOC) -o $@

clean:
	@$(RM) $(SCRIPT_NAME)
	@$(RM) $(SCRIPT_NAME).1

# Check for installed programs

has-%:
	@which $* >/dev/null

check: has-perl has-git
	@echo "$(PATH)" | grep -q '$(BINDIR)' || { echo "BINDIR $(BINDIR) not in your PATH!" && exit 1; }
	@echo "$(MANPATH)" | grep -q '$(MANDIR)' || { echo "MANDIR $(MANDIR) not in your MANPATH!" && exit 1; }

#
# Install / Uninstall
#

install: install-bin install-config install-man

install-man: $(SCRIPT_NAME).1
	@$(MKDIR) $(MANDIR)
	@$(CP) -t $(MANDIR) $(SCRIPT_NAME).1

install-bin: $(SCRIPT_NAME)
	@$(MKDIR) $(BINDIR)
	@$(CP) -t $(BINDIR) $(SCRIPT_NAME)

install-config: config.ini
	@$(MKDIR) $(CONFDIR)
	@$(CP_SECURE) -t $(CONFDIR) config.ini

uninstall-all: uninstall uninstall-config

uninstall: uninstall-bin uninstall-man

uninstall-man:
	@$(RM) $(MANDIR)/$(SCRIPT_NAME).1

uninstall-bin:
	@$(RM) $(BINDIR)/$(SCRIPT_NAME)

uninstall-config:
	@echo "Ctrl-C to keep, enter to delete $(CONFDIR)?" && read x && $(RM) $(CONFDIR)

link: $(SCRIPT_NAME)
	$(LN) $(PWD)/$(SCRIPT_NAME) $(HOME)/.local/bin/$(SCRIPT_NAME)

install-home:
	$(MAKE) PREFIX=$(HOME)/.local install

uninstall-home:
	$(MAKE) PREFIX=$(HOME)/.local uninstall


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
