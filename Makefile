# Public variables.
NIM ?= nim
NIMC ?= $(NIM) c
OBJDIR ?= .obj
OUTDIR ?= target
# These paths are quoted in recipes.
PREFIX ?= /usr/local
MANPREFIX ?= $(PREFIX)/share/man
MANPREFIX1 ?= $(MANPREFIX)/man1
MANPREFIX5 ?= $(MANPREFIX)/man5
MANPREFIX7 ?= $(MANPREFIX)/man7
TARGET ?= release
PANDOC ?= pandoc

# Note: this is not a real shell substitution.
# The default setting is at {the binary's path}/../libexec/chawan.
# You may override it with any path if your system does not have a libexec
# directory.
# (This way, `cha' can be directly executed without installation.)
LIBEXECDIR ?= \$$CHA_BIN_DIR/../libexec/chawan

# I won't take this from the environment for obvious reasons. Please override it
# in the make command if you must, or (preferably) fix your environment so it's
# not needed.
DANGER_DISABLE_SANDBOX = 0

# Private variables.
# If overridden, take libexecdir that was specified.
# Otherwise, just install to libexec/chawan.
ifeq ($(LIBEXECDIR),\$$CHA_BIN_DIR/../libexec/chawan)
LIBEXECDIR_CHAWAN = "$(DESTDIR)$(PREFIX)/libexec/chawan"
else
LIBEXECDIR_CHAWAN = $(LIBEXECDIR)
endif

# Static linking.
STATIC_LINK ?= 0

# These paths are quoted in recipes.
OUTDIR_TARGET = $(OUTDIR)/$(TARGET)
OUTDIR_BIN = $(OUTDIR_TARGET)/bin
OUTDIR_LIBEXEC = $(OUTDIR_TARGET)/libexec/chawan
OUTDIR_CGI_BIN = $(OUTDIR_LIBEXEC)/cgi-bin
OUTDIR_MAN = $(OUTDIR_TARGET)/share/man

# Force a poll implementation.  0 - do not force, 1 - poll, 2 - select.
# This is an intentionally undocumented debugging flag; open a ticket if
# you need it on a certain system, because it has subtle issues without
# platform-specific adjustments.
FORCE_POLL_MODE ?= 0

# Nim compiler flags
ifeq ($(TARGET),debug)
FLAGS += -d:debug --debugger:native
else ifeq ($(TARGET),release)
FLAGS += -d:release -d:strip -d:lto
else ifeq ($(TARGET),release0)
FLAGS += -d:release --stacktrace:on
else ifeq ($(TARGET),release1)
FLAGS += -d:release --debugger:native
endif

protocols = file ftp gopher finger man spartan chabookmark \
	stbi jebp sixel canvas resize nanosvg http gemini sftp
converters = gopher2html md2html ansi2html gmi2html dirlist2html uri2html img2html
tools = urlenc nc

ifeq ($(STATIC_LINK),1)
FLAGS += -d:staticLink=$(STATIC_LINK)
LDFLAGS += -static
protocols += ssl
endif

ifeq ($(FORCE_POLL_MODE),2)
# for seccomp
CFLAGS += -DCHA_FORCE_SELECT
endif

ifneq ($(CFLAGS),)
FLAGS += $(foreach flag,$(CFLAGS),--passc:$(flag))
endif
ifneq ($(LDFLAGS),)
FLAGS += $(foreach flag,$(LDFLAGS),--passl:$(flag))
endif

FLAGS += -d:disableSandbox=$(DANGER_DISABLE_SANDBOX)
FLAGS += -d:forcePollMode=$(FORCE_POLL_MODE)

export CC CFLAGS LDFLAGS

binaries = $(OUTDIR_BIN)/cha $(OUTDIR_BIN)/mancha
binaries += $(foreach bin,$(protocols),$(OUTDIR_CGI_BIN)/$(bin))
binaries += $(foreach bin,$(converters),$(OUTDIR_LIBEXEC)/$(bin))
binaries += $(foreach bin,$(tools),$(OUTDIR_LIBEXEC)/$(bin))
binaries += $(OUTDIR_LIBEXEC)/urldec

.PHONY: all
all: $(binaries)
	ln -sf "$(OUTDIR)/$(TARGET)/bin/cha" cha

ifeq ($(shell uname), Linux)
chaseccomp = lib/chaseccomp/chaseccomp.o

lib/chaseccomp/chaseccomp.o: .FORCE
	(cd lib/chaseccomp && $(MAKE))
.FORCE:
endif

# lib/*0 has a 0 so that it doesn't conflict with the old submodules.
# git can't deal with this, it seems.
$(OUTDIR_BIN)/cha: src/*.nim src/*/*.nim res/* lib/chame0/chame/* \
		lib/chagashi0/chagashi/* lib/monoucha0/monoucha/* \
		lib/monoucha0/monoucha/qjs/* $(chaseccomp) \
		res/map/idna_gen.nim nim.cfg
	@mkdir -p "$(OUTDIR_BIN)"
	$(NIMC) --nimcache:"$(OBJDIR)/$(TARGET)/cha" -d:libexecPath=$(LIBEXECDIR) \
                $(FLAGS) -o:"$(OUTDIR_BIN)/cha" src/main.nim

$(OUTDIR_BIN)/mancha: adapter/tools/mancha.nim
	@mkdir -p "$(OUTDIR_BIN)"
	$(NIMC) --nimcache:"$(OBJDIR)/$(TARGET)/mancha" $(FLAGS) \
		-o:"$(OUTDIR_BIN)/mancha" $(FLAGS) adapter/tools/mancha.nim

unicode_version = 16.0.0

.PHONY: unicode_gen
unicode_gen:
	@printf 'Download EastAsianWidth.txt and IdnaMappingTable.txt from www.unicode.org? (y/n) '
	@read res; if test "$$res" = "y"; then \
	cha -d 'https://www.unicode.org/Public/idna/$(unicode_version)/IdnaMappingTable.txt' >res/map/IdnaMappingTable.txt; \
	cha -d 'https://www.unicode.org/Public/$(unicode_version)/ucd/EastAsianWidth.txt' >res/map/EastAsianWidth.txt; \
	fi
	$(NIMC) --nimcache:"$(OBJDIR)/idna_gen_cache" -d:danger -o:"$(OBJDIR)/genidna" res/genidna.nim
	$(NIMC) --nimcache:"$(OBJDIR)/charwidth_gen_cache" -d:danger -o:"$(OBJDIR)/gencharwidth" res/gencharwidth.nim
	$(OBJDIR)/genidna > res/map/idna_gen.nim
	$(OBJDIR)/gencharwidth > res/map/charwidth_gen.nim

twtstr = src/utils/twtstr.nim src/types/opt.nim
dynstream = src/io/dynstream.nim
lcgi = $(dynstream) $(twtstr) $(sandbox) adapter/protocol/lcgi.nim
lcgi_ssl = $(lcgi) adapter/protocol/lcgi_ssl.nim
sandbox = src/utils/sandbox.nim $(chaseccomp)
tinfl = adapter/protocol/tinfl.h

$(OUTDIR_CGI_BIN)/man: $(twtstr)
$(OUTDIR_CGI_BIN)/http: $(sandbox) $(lcgi_ssl) $(tinfl)
$(OUTDIR_CGI_BIN)/file: $(twtstr)
$(OUTDIR_CGI_BIN)/ftp: $(lcgi)
$(OUTDIR_CGI_BIN)/sftp: $(lcgi) $(twtstr)
$(OUTDIR_CGI_BIN)/gemini: $(lcgi_ssl)
$(OUTDIR_CGI_BIN)/ssl: $(lcgi_ssl) $(sandbox) $(tinfl)
$(OUTDIR_CGI_BIN)/stbi: adapter/img/stbi.nim adapter/img/stb_image.h \
	adapter/img/stb_image_write.h $(sandbox) $(dynstream)
$(OUTDIR_CGI_BIN)/jebp: adapter/img/jebp.h $(sandbox)
$(OUTDIR_CGI_BIN)/sixel: src/types/color.nim $(sandbox) $(twtstr) $(dynstream)
$(OUTDIR_CGI_BIN)/canvas: src/types/canvastypes.nim src/types/path.nim \
	src/io/packetreader.nim src/types/color.nim adapter/img/stb_image.h \
	$(sandbox) $(dynstream) $(twtstr)
$(OUTDIR_CGI_BIN)/resize: adapter/img/stb_image_resize.h $(sandbox) $(dynstream) $(twtstr)
$(OUTDIR_CGI_BIN)/nanosvg: $(sandbox) adapter/img/nanosvg.nim adapter/img/nanosvg.h
$(OUTDIR_LIBEXEC)/urlenc: $(twtstr)
$(OUTDIR_LIBEXEC)/nc: $(lcgi)
$(OUTDIR_LIBEXEC)/gopher2html: $(twtstr)
$(OUTDIR_LIBEXEC)/ansi2html: src/types/color.nim src/io/poll.nim $(twtstr) $(dynstream)
$(OUTDIR_LIBEXEC)/md2html: $(twtstr)
$(OUTDIR_LIBEXEC)/dirlist2html: $(twtstr)
$(OUTDIR_LIBEXEC)/img2html: $(twtstr)

$(OUTDIR_CGI_BIN)/%: adapter/protocol/%.nim
	@mkdir -p "$(OUTDIR_CGI_BIN)"
	$(NIMC) $(FLAGS) --nimcache:"$(OBJDIR)/$(TARGET)/$(subst $(OUTDIR_CGI_BIN)/,,$@)" \
		-o:"$@" $<

$(OUTDIR_CGI_BIN)/%: adapter/protocol/%
	@mkdir -p "$(OUTDIR_CGI_BIN)"
	install -m755 $< "$(OUTDIR_CGI_BIN)"

$(OUTDIR_LIBEXEC)/%: adapter/format/%
	@mkdir -p "$(OUTDIR_LIBEXEC)"
	install -m755 $< "$(OUTDIR_LIBEXEC)"

$(OUTDIR_CGI_BIN)/%: adapter/img/%.nim
	@mkdir -p "$(OUTDIR_CGI_BIN)"
	$(NIMC) $(FLAGS) --nimcache:"$(OBJDIR)/$(TARGET)/$(subst $(OUTDIR_CGI_BIN)/,,$@)" \
                -o:"$@" $<

ifeq ($(STATIC_LINK),1)
$(OUTDIR_CGI_BIN)/http: $(OUTDIR_CGI_BIN)/ssl
	(cd "$(OUTDIR_CGI_BIN)" && ln -sf ssl http)
$(OUTDIR_CGI_BIN)/gemini: $(OUTDIR_CGI_BIN)/ssl
	(cd "$(OUTDIR_CGI_BIN)" && ln -sf ssl gemini)
$(OUTDIR_CGI_BIN)/sftp: $(OUTDIR_CGI_BIN)/ssl
	(cd "$(OUTDIR_CGI_BIN)" && ln -sf ssl sftp)
endif

$(OUTDIR_LIBEXEC)/%: adapter/format/%.nim
	@mkdir -p "$(OUTDIR_LIBEXEC)"
	$(NIMC) $(FLAGS) --nimcache:"$(OBJDIR)/$(TARGET)/$(subst $(OUTDIR_LIBEXEC)/,,$@)" \
		-o:"$@" $<

$(OUTDIR_LIBEXEC)/%: adapter/tools/%.nim
	@mkdir -p "$(OUTDIR_LIBEXEC)"
	$(NIMC) $(FLAGS) --nimcache:"$(OBJDIR)/$(TARGET)/$(subst $(OUTDIR_LIBEXEC)/,,$@)" \
		-o:"$@" $<

$(OUTDIR_LIBEXEC)/urldec: $(OUTDIR_LIBEXEC)/urlenc
	(cd "$(OUTDIR_LIBEXEC)" && ln -sf urlenc urldec)

$(OBJDIR)/man/cha-%.md: doc/%.md md2manpreproc
	@mkdir -p "$(OBJDIR)/man"
	./md2manpreproc $< > $@

$(OBJDIR)/man/cha-%.md.roff: $(OBJDIR)/man/cha-%.md
	$(PANDOC) --standalone --to man $< -o $@

doc/cha-%.5: $(OBJDIR)/man/cha-%.md.roff
	awk 'last=="T}" && $$1=="T{" {print "_"} {last=$$1} 1' $< > $@

doc/cha-%.7: $(OBJDIR)/man/cha-%.md.roff
	awk 'last=="T}" && $$1=="T{" {print "_"} {last=$$1} 1' $< > $@

.PHONY: clean
clean:
	rm -rf "$(OBJDIR)/$(TARGET)"
	(cd lib/chaseccomp && $(MAKE) clean)

.PHONY: distclean
distclean: clean
	rm -rf "$(OUTDIR)"

manpages1 = cha.1 mancha.1
manpages5 = cha-config.5 cha-mailcap.5 cha-mime.types.5 cha-localcgi.5 \
	cha-urimethodmap.5
manpages7 = cha-protocols.7 cha-api.7 cha-troubleshooting.7 cha-image.7 cha-css.7 cha-terminal.7

manpages = $(manpages1) $(manpages5) $(manpages7)

.PHONY: manpage
manpage: $(manpages:%=doc/%)

.PHONY: install
install:
	mkdir -p "$(DESTDIR)$(PREFIX)/bin"
	install -m755 "$(OUTDIR_BIN)/cha" "$(DESTDIR)$(PREFIX)/bin"
	install -m755 "$(OUTDIR_BIN)/mancha" "$(DESTDIR)$(PREFIX)/bin"
# intentionally not quoted
	mkdir -p $(LIBEXECDIR_CHAWAN)/cgi-bin
	for f in $(protocols); do \
	install -m755 "$(OUTDIR_CGI_BIN)/$$f" $(LIBEXECDIR_CHAWAN)/cgi-bin; \
	done
	for f in $(converters) $(tools); \
	do install -m755 "$(OUTDIR_LIBEXEC)/$$f" $(LIBEXECDIR_CHAWAN); \
	done
# urldec is just a symlink to urlenc
	(cd $(LIBEXECDIR_CHAWAN) && ln -sf urlenc urldec)
ifeq ($(STATIC_LINK),1)
	(cd $(LIBEXECDIR_CHAWAN)/cgi-bin && ln -sf ssl http)
	(cd $(LIBEXECDIR_CHAWAN)/cgi-bin && ln -sf ssl gemini)
	(cd $(LIBEXECDIR_CHAWAN)/cgi-bin && ln -sf ssl sftp)
endif
	mkdir -p "$(DESTDIR)$(MANPREFIX1)"
	for f in $(manpages1); do install -m644 "doc/$$f" "$(DESTDIR)$(MANPREFIX1)"; done
	mkdir -p "$(DESTDIR)$(MANPREFIX5)"
	for f in $(manpages5); do install -m644 "doc/$$f" "$(DESTDIR)$(MANPREFIX5)"; done
	mkdir -p "$(DESTDIR)$(MANPREFIX7)"
	for f in $(manpages7); do install -m644 "doc/$$f" "$(DESTDIR)$(MANPREFIX7)"; done

.PHONY: uninstall
uninstall:
	rm -f "$(DESTDIR)$(PREFIX)/bin/cha"
	rm -f "$(DESTDIR)$(PREFIX)/bin/mancha"
# intentionally not quoted
	for f in $(protocols); do rm -f $(LIBEXECDIR_CHAWAN)/cgi-bin/$$f; done
# We only want to uninstall binaries that the main distribution
# includes or has ever included, but not those that the user might have
# added.  However, some of these cannot be directly derived from our
# variables:
# * png has been removed in favor of stbi
# * data, about have been moved back into the main binary
# * gmifetch has been replaced by gemini
# * cha-finger has been renamed to finger
# * ssl is an alias for http, gemini, sftp in static builds
	rm -f $(LIBEXECDIR_CHAWAN)/cgi-bin/about
	rm -f $(LIBEXECDIR_CHAWAN)/cgi-bin/cha-finger
	rm -f $(LIBEXECDIR_CHAWAN)/cgi-bin/data
	rm -f $(LIBEXECDIR_CHAWAN)/cgi-bin/gmifetch
	rm -f $(LIBEXECDIR_CHAWAN)/cgi-bin/png
	rm -f $(LIBEXECDIR_CHAWAN)/cgi-bin/http
	rm -f $(LIBEXECDIR_CHAWAN)/cgi-bin/gemini
	rm -f $(LIBEXECDIR_CHAWAN)/cgi-bin/sftp
	rm -f $(LIBEXECDIR_CHAWAN)/cgi-bin/ssl
	rmdir $(LIBEXECDIR_CHAWAN)/cgi-bin || true
	for f in $(converters) $(tools); do rm -f $(LIBEXECDIR_CHAWAN)/$$f; done
# urldec is just a symlink to urlenc
	rm -f $(LIBEXECDIR_CHAWAN)/urldec
	rmdir $(LIBEXECDIR_CHAWAN) || true
	for f in $(manpages7); do rm -f "$(DESTDIR)$(MANPREFIX7)/$$f"; done
	for f in $(manpages5); do rm -f "$(DESTDIR)$(MANPREFIX5)/$$f"; done
# moved to section 7
	for f in cha-protocols.5 cha-api.5 cha-troubleshooting.5 cha-image.5; do rm -f "$(DESTDIR)$(MANPREFIX5)/$$f"; done
	for f in $(manpages1); do rm -f "$(DESTDIR)$(MANPREFIX1)/$$f"; done

test/net/run: test/net/run.nim
	$(NIMC) test/net/run.nim

.PHONY: test_js
test_js:
	(cd test/js && ./run.sh)

.PHONY: test_layout
test_layout:
	(cd test/layout && ./run.sh)

.PHONY: test_md
test_md:
	(cd test/md && ./run.sh)

.PHONY: test_net
test_net: test/net/run
	(cd test/net && ./run)

.PHONY: test
test: test_js test_layout test_net test_md
