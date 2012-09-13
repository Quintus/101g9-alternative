MANUAL_NAME=101g9-alternative
MANPAGES=makeinitramfs.1
VERSION=0.0.1

all: manpages

%.1: %.ronn.1
	ronn --roff --manual=$(MANUAL_NAME) --organization="$(MANUAL_NAME) $(VERSION)" $<

manpages: $(MANPAGES)
