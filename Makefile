VERSION := 0.0.1
PROJECT_NAME := 101g9-alternative
RELEASE_DIR := $(PROJECT_NAME)-$(VERSION)

all: release

docs:
	make -C doc/man

release-dir: docs
	rm -rf $(RELEASE_DIR)
	mkdir $(RELEASE_DIR)
	cp -r data $(RELEASE_DIR)
	cp -r bin/tools $(RELEASE_DIR)/bin
	mkdir $(RELEASE_DIR)/doc
	cp -r doc/text $(RELEASE_DIR)/doc
	mkdir $(RELEASE_DIR)/doc/man
	cp doc/man/*.[1-9] $(RELEASE_DIR)/doc/man
	cp README $(RELEASE_DIR)

release: release-dir
	tar -cvJf $(RELEASE_DIR).tar.xz $(RELEASE_DIR)

.PHONY: docs release-dir release
