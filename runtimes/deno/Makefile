MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
DENO_VERSION  := $(shell cat $(MAKEFILE_DIR)../../.deno-version)
REPO_ROOT     := $(abspath $(MAKEFILE_DIR)../..)

.PHONY: shell
shell:
	docker run --rm -it \
		--volume $(REPO_ROOT):/workspace \
		--workdir /workspace \
		denoland/deno:$(DENO_VERSION) \
		/bin/sh
