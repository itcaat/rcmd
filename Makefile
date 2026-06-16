SHELL := /bin/bash

SWIFT ?= swift
BUMP ?= patch
PUSH ?= 0
VERSION ?=

.PHONY: build test ci package release release-push clean

build:
	$(SWIFT) build

test:
	@test_files="$$(find Tests -type f -name '*.swift' -print -quit 2>/dev/null)"; \
	if [ -n "$$test_files" ]; then \
		$(SWIFT) test; \
	else \
		echo "No Swift tests found; skipping swift test."; \
	fi

ci: build test package

package:
	VERSION="$(VERSION)" ./scripts/package-release.sh

release: ci
	BUMP="$(BUMP)" VERSION="$(VERSION)" PUSH="$(PUSH)" ./scripts/release.sh

release-push:
	$(MAKE) release PUSH=1

clean:
	$(SWIFT) package clean
	rm -rf dist
