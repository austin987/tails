CC ?= gcc
CFLAGS ?= -O2 -Wall -Wextra -Werror -std=c11 -fPIE -fstack-protector-strong -D_FORTIFY_SOURCE=2
LDFLAGS ?= -pie -Wl,-z,relro,-z,now
PREFIX ?= /usr

all: anitails-udev-watchdog

anitails-udev-watchdog: anitails-udev-watchdog.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

install: anitails-udev-watchdog
	install -Dm0755 anitails-udev-watchdog "$(DESTDIR)$(PREFIX)/bin/anitails-udev-watchdog"

clean:
	rm -f anitails-udev-watchdog

.PHONY: all install clean
