TARGETS := $(shell ls scripts | grep -v \\.sh)
GO_FILES ?= $$(find . -name '*.go' | grep -v generated)
GO_VERSION ?= 1.20.4
USE_DAPPER ?= 1
UNAME := $(shell uname -m)
SHELL = /bin/bash
WD := $(shell pwd)
export TOOLPATH := $(WD)
export GOROOT := $(TOOLPATH)/bin/go
export PATH := $(TOOLPATH)/bin:$(GOROOT)/bin:$(PATH)

ifeq ($(UNAME),x86_64)
	ARCH = amd64
else
        ifeq ($(UNAME),arm64)
	        ARCH = arm64
        endif
endif

.dapper:
	@echo Downloading dapper
	@curl -sL https://releases.rancher.com/dapper/v0.6.0/dapper-$$(uname -s)-$$(uname -m) > .dapper.tmp
	@@chmod +x .dapper.tmp
	@./.dapper.tmp -v
	@mv .dapper.tmp .dapper

.nodapper:
	$(info Checking essential build tools.)
	@if [ ! -d $(WD)/bin ] ; then \
		mkdir $(WD)/bin ; \
	fi
	$(info Checking go version for compatibility.)
	@if [ ! -d $(GOROOT) ] ; then \
		echo "No go found, fetching compatible version." ; curl -sL https://go.dev/dl/go$(GO_VERSION).linux-$(ARCH).tar.gz | tar -C $$PWD/bin -zxf - ; \
	else \
		case "$$(go version)" in \
			*$(GO_VERSION)* ) echo "Compatible go version found." ;; \
			* ) echo "Go appears to be " $$(go version) ; echo "Incompatible or non-functional go found, fetching compatible version." ; curl -sL https://go.dev/dl/go$(GO_VERSION).linux-$(ARCH).tar.gz | tar -C $$PWD/bin -zxf - ;; \
		esac \
	fi
	@if ! type yq 2>/dev/null ; then \
		echo "yq not found, fetching."; \
		curl -sL --output $$PWD/bin/yq https://github.com/mikefarah/yq/releases/download/v4.34.1/yq_linux_$(ARCH) ; \
		chmod +x $$PWD/bin/yq ; \
	fi

ifeq ($(strip $(USE_DAPPER)),1)
$(TARGETS): .dapper
	./.dapper $@
else

# We call clean ourselves in a separate target and we are reproducing the ci
# call here in our 'build' case.
$(filter-out clean ci, $(TARGETS)): .nodapper
	env ; \
	case $@ in \
		build ) ./scripts/download ; ./scripts/validate ; ./scripts/build ;; \
		* ) ./scripts/$@ ;; \
	esac

ci: build
	$(info No additional ci steps required.)

clean:
	./scripts/clean

endif

.PHONY: deps
deps:
	go mod tidy

release:
	./scripts/release.sh

.DEFAULT_GOAL := ci

.PHONY: $(TARGETS)

build/data:
	mkdir -p $@

.PHONY: binary-size-check
binary-size-check:
	scripts/binary_size_check.sh

.PHONY: image-scan
image-scan:
	scripts/image_scan.sh $(IMAGE)

format:
	gofmt -s -l -w $(GO_FILES)
	goimports -w $(GO_FILES)
