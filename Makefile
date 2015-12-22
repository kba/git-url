SCRIPT_NAME = git-url
VERSION = 0.0.2

PREFIX = $(DESTDIR)/usr/local
BINDIR = $(PREFIX)/bin
HOME_BINDIR = $(HOME)/.local/bin
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

check-home: check
	@echo "$(PATH)" | grep -q '$(HOME_BINDIR)' || { echo "HOME_BINDIR $(HOME_BINDIR) not in your PATH!" && exit 1; }

install-home: check-home install-home-bin install-home-config

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
VERSION_patch := $(shell semver bump patch --pretend)
VERSION_minor := $(shell semver bump minor --pretend)
VERSION_major := $(shell semver bump major --pretend)
bump-%: has-semver
	sed -i '/^VERSION = /s/.*/VERSION = $(VERSION_$*)/' Makefile
	sed -i '/^<!-- newest-changes/a ## [$(VERSION_$*)] - $(TODAY)\
	### Added\
	### Changed\
	### Fixed\
	### Removed\
	' CHANGELOG.md
	sed -i '/^<!-- link-labels/a [$(VERSION_$*)]: ../compare/v$(VERSION)...v$(VERSION_$*)' CHANGELOG.md
	$(EDITOR) CHANGELOG.md
	git commit -v .
	git tag -a v$(VERSION_$*) -m "Release $(VERSION_$*)"
