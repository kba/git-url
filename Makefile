SCRIPT_NAME = git-url
VERSION = 1.00

PREFIX = $(DESTDIR)/usr/local
BINDIR = $(PREFIX)/bin
HOME_BINDIR = $(HOME)/bin
HOME_CONFDIR = $(HOME)/.config/$(SCRIPT_NAME)

RM = rm -rvf
CP = cp -rv
CP_SECURE = cp -irv
MKDIR = mkdir -pv
CHMOD_AX = chmod -c a+x

.PHONY: clean install check \
	install-home install-home-bin install-home-config \
	uninstall-home uninstall-home-bin uninstall-home-config \

$(SCRIPT_NAME): $(SCRIPT_NAME).pl Makefile
	@$(CP) $< $@
	@sed -i 's/__SCRIPT_NAME__/$(SCRIPT_NAME)/' $@
	@sed -i 's/__VERSION__/$(VERSION)/' $@
	@sed -i 's/__BUILD_DATE__/$(shell date)/' $@
	@$(CHMOD_AX) $@

clean:
	@$(RM) $(SCRIPT_NAME)

# Check for installed programs

has-%:
	@which $* >/dev/null

check: has-perl has-git

# System install

install: check $(SCRIPT_NAME) install-home-config
	@$(CP) $(SCRIPT_NAME) $(BINDIR)

uninstall:
	@$(RM) $(BINDIR)/$(SCRIPT_NAME)

# Home install

install-home: check install-home-bin install-home-config

install-home-bin: $(SCRIPT_NAME) 
	@$(MKDIR) $(HOME_BINDIR)
	@$(CP) -t $(HOME_BINDIR) $(SCRIPT_NAME)

install-home-config: config.ini
	@$(MKDIR) $(HOME_CONFDIR)
	@$(CP_SECURE) -t $(HOME_CONFDIR) config.ini

uninstall-home: uninstall-home-bin uninstall-home-config

uninstall-home-bin:
	@$(RM) $(HOME_BINDIR)/$(SCRIPT_NAME)

uninstall-home-config:
	@echo "Ctrl-C to keep, enter to delete $(HOME_CONFDIR)?" && read x && $(RM) $(HOME_CONFDIR)

# Distribution stuff

TODAY := $(shell date '+%Y-%m-%d')
NEXT_VERSION := $(shell echo "$(VERSION)"|sed 's/[^0-9]//g'|xargs expr 1 + |sed 's/\(.\)\(.*\)/\1.\2/')
bump-version: has-expr has-xargs has-date
	sed -i '/^VERSION = /s/.*/VERSION = $(NEXT_VERSION)/' Makefile
	sed -i '/^<!-- newest-changes/a ## [$(NEXT_VERSION)] - $(TODAY)\
	### Added\
	### Changed\
	### Fixed\
	### Removed\
	' CHANGELOG.md
	sed -i '/^<!-- link-labels/a [$(NEXT_VERSION)]: ../compare/v$(VERSION)...v$(NEXT_VERSION)' CHANGELOG.md
