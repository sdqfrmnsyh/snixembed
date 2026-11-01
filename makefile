PKG = gtk+-3.0 gio-2.0 Dbusmenu-0.4 DbusmenuGtk3-0.4
CPKG = dbusmenu-gtk3-0.4
SRC = src/*.vala version.vala

PREFIX ?= /usr
BINDIR ?= /bin
MANDIR ?= /share/man

# Optimize for size and speed on low-end hardware
# -Os: optimize for size (better instruction cache usage on weak CPU)
# -flto: link-time optimization
# -fdata-sections -ffunction-sections + -Wl,--gc-sections: remove unused code
# -pipe: faster compilation
# -march=native: optimize for your specific CPU (AMD A4-9125)
# -Wno-deprecated-declarations: suppress GTK deprecated warnings (GtkStatusIcon is required)
# -Wno-incompatible-pointer-types: suppress Vala binding issue with gtk_icon_theme_set_search_path
# -Wno-discarded-qualifiers: suppress g_atomic_pointer_get volatile qualifier warning
CFLAGS := -Os -flto -fdata-sections -ffunction-sections -pipe -march=native -Wno-deprecated-declarations -Wno-incompatible-pointer-types -Wno-discarded-qualifiers $(shell pkg-config --cflags $(CPKG))
LDFLAGS := -Wl,--gc-sections -Wl,--as-needed -flto $(shell pkg-config --libs $(CPKG))

VFLAGS := $(foreach flag, $(CFLAGS) $(LDFLAGS), -X $(flag)) $(VFLAGS)

# Release build: strip debug symbols, disable assertions
# VAPI dirs must come before --pkg flags
VALAC_FLAGS = --disable-assert --vapidir /usr/share/vala/vapi --vapidir /usr/share/vala-0.56/vapi

snixembed: $(SRC)
	valac -o $@ $(VALAC_FLAGS) $(VFLAGS) --pkg gtk+-3.0 --pkg gio-2.0 --pkg Dbusmenu-0.4 --pkg DbusmenuGtk3-0.4 $(SRC)
	strip --strip-all $@ 2>/dev/null || true

version.vala: # update version from git if possible
ifneq (,$(wildcard ./.git/HEAD))
	echo "const string VERSION = \"$(shell git describe --always --tags --dirty)\";" > $@
endif

doc: $(SRC)
	valadoc --force -o $@ --internal --private --package-name snixembed $(SRC) $(PKG)

clean:
	rm -rf src/*.c version.vala snixembed doc

install: snixembed
	install -Dm755 snixembed $(DESTDIR)$(PREFIX)$(BINDIR)/snixembed
	install -Dm644 snixembed.1 $(DESTDIR)$(PREFIX)$(MANDIR)/man1/snixembed.1

uninstall:
	rm -f $(DESTDIR)$(PREFIX)$(BINDIR)/snixembed \
		$(DESTDIR)$(PREFIX)$(MANDIR)/man1/snixembed.1

.PHONY: clean install uninstall version.vala
