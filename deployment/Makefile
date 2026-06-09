# litevolve: deployment build & test

DEPLOY_DIR   := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT_DIR     := $(abspath $(DEPLOY_DIR)/..)
DOCKERFILE   := $(DEPLOY_DIR)Dockerfile
IMAGE_PREFIX := litevolve

HOST_ARCH := $(shell uname -m)

ifeq ($(HOST_ARCH),aarch64)
  GLIBC_BINARIES  := litevolve_linux_arm64
  MUSL_BINARIES   := litevolve_linux_arm64_musl
  DARWIN_BINARIES := litevolve_darwin_arm64
else
  GLIBC_BINARIES  := litevolve_linux_x64 litevolve_linux_x64_modern litevolve_linux_x64_baseline
  MUSL_BINARIES   := litevolve_linux_x64_musl
  DARWIN_BINARIES := litevolve_darwin_x64 litevolve_darwin_x64_baseline
endif

DOCKER_IMAGE_STAGES := linux_glibc linux_musl darwin

.DEFAULT_GOAL := help

.PHONY: help
help: ## show this help message
	@echo "litevolve deployment - build & test Docker stages"
	@echo ""
	@echo "host arch: $(HOST_ARCH)"
	@echo ""
	@echo "available targets:"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: runners_build
runners_build: ## build executables for the specific runner (RUNNER_OS=Linux|macOS)
	@if [ "$(RUNNER_OS)" = "Linux" ]; then \
		for binary in $(GLIBC_BINARIES); do \
			echo ""; \
			echo "--- building $$binary ---"; \
			target=$$(echo "$$binary" | sed 's/litevolve_/bun-/' | tr '_' '-'); \
			$(MAKE) -C $(ROOT_DIR) ci_binary TARGET="$$target" && mv $(ROOT_DIR)/dist/litevolve "$(ROOT_DIR)/dist/$$binary" || exit 1; \
		done; \
	elif [ "$(RUNNER_OS)" = "macOS" ]; then \
		for binary in $(DARWIN_BINARIES); do \
			echo ""; \
			echo "--- building $$binary ---"; \
			target=$$(echo "$$binary" | sed 's/litevolve_/bun-/' | tr '_' '-'); \
			$(MAKE) -C $(ROOT_DIR) ci_binary TARGET="$$target" && mv $(ROOT_DIR)/dist/litevolve "$(ROOT_DIR)/dist/$$binary" || exit 1; \
		done; \
	else \
		echo "error: unsupported RUNNER_OS '$(RUNNER_OS)' (expected Linux or macOS)"; \
		exit 1; \
	fi

##@ docker

.PHONY: docker_build
docker_build: ## build Linux images and the darwin extraction stage
	@for stage in $(DOCKER_IMAGE_STAGES); do \
		echo "building $(IMAGE_PREFIX):$$stage..."; \
		docker buildx build --load \
			--build-arg "GLIBC_BINARIES=$(GLIBC_BINARIES)" \
			--build-arg "MUSL_BINARIES=$(MUSL_BINARIES)" \
			--build-arg "DARWIN_BINARIES=$(DARWIN_BINARIES)" \
			--target=$$stage \
			--tag $(IMAGE_PREFIX):$$stage \
			--file $(DOCKERFILE) \
			$(ROOT_DIR) || exit 1; \
	done

.PHONY: docker_test
docker_test: ## run smoke_test.sh for the host-arch binaries inside each Linux image
	@FAILS=0; \
	for binary in $(GLIBC_BINARIES); do \
		echo ""; \
		echo "--- $(IMAGE_PREFIX):linux_glibc / $$binary ---"; \
		docker run --rm \
			$(IMAGE_PREFIX):linux_glibc /usr/local/bin/smoke_test.sh $$binary \
			|| FAILS=$$((FAILS+1)); \
	done; \
	for binary in $(MUSL_BINARIES); do \
		echo ""; \
		echo "--- $(IMAGE_PREFIX):linux_musl / $$binary ---"; \
		docker run --rm \
			$(IMAGE_PREFIX):linux_musl /usr/local/bin/smoke_test.sh $$binary \
			|| FAILS=$$((FAILS+1)); \
	done; \
	[ "$$FAILS" -eq 0 ] || { echo ""; echo "docker_test FAILED ($$FAILS failure(s))"; exit 1; }; \
	echo ""
