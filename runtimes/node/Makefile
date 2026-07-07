MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
NODE_VERSION  := $(shell cat $(MAKEFILE_DIR)../../.node-version)
REPO_ROOT     := $(abspath $(MAKEFILE_DIR)../..)

.PHONY: shell
shell:
	docker run --rm -it \
		-v $(REPO_ROOT):/workspace \
		-w /workspace \
		node:$(NODE_VERSION)-alpine \
		/bin/sh
