SCRIPT_NAME = git-url
VERSION = $(shell cat .version)

PREFIX = $(DESTDIR)/usr/local
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/share/$(SCRIPT_NAME)
MANDIR = $(PREFIX)/share/man/man1
ZSHDIR = $(PREFIX)/share/zsh/site-functions
CONFDIR = $(HOME)/.config/$(SCRIPT_NAME)

RM = rm -rvf
CP = cp -rv
LN = ln -svf
CP_SECURE = cp -irv
MKDIR = mkdir -pv
CHMOD_AX = chmod -c a+x
PANDOC_OPTIONS = -M hyphenate=false -V adjusting=false 
PANDOC = pandoc -s $(PANDOC_OPTIONS) -t man
LIB_TARGETS = $(shell find src/lib -type f -name "*.pm"|sed 's,src/,,')

.PHONY: clean check install uninstall

all: lib bin man config.ini

# lib
lib: ${LIB_TARGETS}

lib/HELPER.pm: src/lib/HELPER.pm
	@$(MKDIR) $(dir $@)
	@$(CP) $< $@
	@sed -i 's/__SCRIPT_NAME__/$(SCRIPT_NAME)/' $@
	@sed -i 's/__VERSION__/$(VERSION)/' $@
	@sed -i 's/__BUILD_DATE__/$(shell date)/' $@
	@sed -i 's/__LAST_COMMIT__/$(LAST_COMMIT)/' $@

lib/%.pm: src/lib/%.pm
	@$(MKDIR) $(dir $@)
	@$(CP) $< $@

# bin
bin: bin/$(SCRIPT_NAME)

LAST_COMMIT = $(shell git log --pretty=format:'%h' -n 1)
bin/$(SCRIPT_NAME): src/bin/$(SCRIPT_NAME).pl
	@$(MKDIR) bin
	@$(CP) $< $@
	@$(CHMOD_AX) $@

# man
man: man/$(SCRIPT_NAME).1

man/%.1: src/man/%.1.md bin has-pandoc dist/gen-manpage.pl
	@$(MKDIR) man
	cat $< | perl dist/gen-manpage.pl man | $(PANDOC) -o $@

# config.ini
config.ini: src/config.ini lib bin dist/gen-manpage.pl
	cat $< | perl dist/gen-manpage.pl ini > $@

# clean
clean:
	@$(RM) lib
	@$(RM) bin
	@$(RM) man
	@$(RM) config.ini

# Check for installed programs
has-%:
	@which $* >/dev/null

check: has-perl has-git has-curl
	@echo "$(PATH)" | grep -q '$(BINDIR)' || { echo "BINDIR $(BINDIR) not in your PATH!" && exit 1; }
	@echo "$(MANPATH)" | grep -q '$(MANDIR)' || { echo "MANDIR $(MANDIR) not in your MANPATH!" && exit 1; }

#
# Install
#
install: lib bin man src/zsh/_git-url
	@$(MKDIR) $(BINDIR) $(LIBDIR) $(MANDIR) $(ZSHDIR)
	@$(CP) -t $(LIBDIR) bin lib man README.md
	@$(LN) -t $(BINDIR) $(LIBDIR)/bin/$(SCRIPT_NAME)
	@$(LN) -t $(MANDIR) $(LIBDIR)/man/$(SCRIPT_NAME).1
	@$(CP) -t $(ZSHDIR) src/zsh/_$(SCRIPT_NAME)

install-config: config.ini
	@$(MKDIR) $(CONFDIR)
	@$(CP_SECURE) -t $(CONFDIR) config.ini

install-all: install install-config

#
# Uninstall
#
uninstall:
	@$(RM) $(LIBDIR)
	@$(RM) $(BINDIR)/$(SCRIPT_NAME)
	@$(RM) $(MANDIR)/$(SCRIPT_NAME).1
	@$(RM) $(ZSHDIR)/_$(SCRIPT_NAME)

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
# TODAY := $(shell date '+%Y-%m-%d')
# VERSION_patch := $(shell semver bump patch --pretend)
# VERSION_minor := $(shell semver bump minor --pretend)
# VERSION_major := $(shell semver bump major --pretend)
# bump-%: has-semver
#     sed -i '/^<!-- newest-changes/a ## [$(VERSION_$*)] - $(TODAY)\
#     Added\
#     Changed\
#     Fixed\
#     Removed\
#     ' CHANGELOG.md
#     sed -i '/^<!-- link-labels/a [$(VERSION_$*)]: ../../compare/v$(VERSION)...v$(VERSION_$*)' CHANGELOG.md
#     $(EDITOR) CHANGELOG.md
#     semver bump $*
#     git commit -v .
#     git tag -a v$(VERSION_$*) -m "Release $(VERSION_$*)"
