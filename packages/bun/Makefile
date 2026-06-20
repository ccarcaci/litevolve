# litevolve: SQLite migration runner

BUN          := bun
BIOME        := bunx biome
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Workspace layout
PACKAGES_DIR := packages
CORE_SRC     := $(PACKAGES_DIR)/core/src
BUN_SRC      := $(PACKAGES_DIR)/bun/src
ENTRY_POINT  := $(MAKEFILE_DIR)$(BUN_SRC)/run_litevolve.ts

# Directories
DATA_DIR    := data
DIST_DIR    := dist
SCRIPTS_DIR := scripts

# Required: provide when calling make
DB_PATH         ?=
VERSION         ?=
MIGRATIONS_PATH ?= $(MAKEFILE_DIR)

.DEFAULT_GOAL := help

.PHONY: help
help: ## show this help message
	@echo "litevolve - SQLite migration runner"
	@echo ""
	@echo "usage: make [target] DB_PATH=<path> VERSION=<n>"
	@echo ""
	@echo "available targets:"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ operate

.PHONY: _check_args
_check_args:
	@[ -n "$(DB_PATH)" ] || (echo "error: DB_PATH is required  (e.g. make migrate DB_PATH=./data/rsvr.db VERSION=1)"; exit 1)
	@[ -n "$(VERSION)" ] || (echo "error: VERSION is required  (e.g. make migrate DB_PATH=./data/rsvr.db VERSION=1)"; exit 1)

.PHONY: migrate
migrate: _check_args ## apply migrations up/down to VERSION. DB_PATH=<path> VERSION=<n>
	@echo "migrating $(DB_PATH) to version $(VERSION)..."
	@$(BUN) run $(ENTRY_POINT) \
		--db_path=$(DB_PATH) \
		--migrations_path=$(MIGRATIONS_PATH) \
		--apply_version=$(VERSION)

.PHONY: migrate_seeds
migrate_seeds: _check_args ## migrate fresh DB to VERSION with seeds (--init_seeds). DB_PATH=<path> VERSION=<n>
	@echo "migrating $(DB_PATH) to version $(VERSION) with init_seeds..."
	@$(BUN) run $(ENTRY_POINT) \
		--db_path=$(DB_PATH) \
		--migrations_path=$(MIGRATIONS_PATH) \
		--apply_version=$(VERSION) \
		--init_seeds

##@ setup and cleanup

.PHONY: install
install: ## install all workspace dependencies
	@echo "installing dependencies..."
	@$(BUN) install
	@echo "Updating biome configuration..."
	./node_modules/.bin/biome migrate --write

.PHONY: clean
clean: ## remove node_modules, *.db, data/, dist/, packages/*/dist/
	@echo "cleaning up..."
	@rm -rf node_modules
	@rm -f *.db
	@rm -rf $(DATA_DIR)
	@rm -rf $(DIST_DIR)
	@rm -rf $(PACKAGES_DIR)/*/dist
	@echo "clean complete!"

.PHONY: clean_all
clean_all: clean ## clean everything including bun lockfile
	@rm -f bun.lockb
	@echo "deep clean complete!"

##@ development

.PHONY: test
test: ## run core + bun adapter tests (e.g. make test test_name)
	@$(MAKE) --no-print-directory ci_test $(if $(filter-out test, $(MAKECMDGOALS)), PATTERN=$(filter-out test, $(MAKECMDGOALS)))

.PHONY: test_debug
test_debug: ## run core + bun adapter tests with debugger (e.g., make test_debug test_name)
	@$(MAKE) --no-print-directory ci_test DEBUG=1 $(if $(filter-out test_debug, $(MAKECMDGOALS)), PATTERN=$(filter-out test_debug, $(MAKECMDGOALS)))

.PHONY: format
format: ## fix formatting, linting (safe fixes), and import sorting with biome
	@echo "fixing formatting, linting, and import sorting..."
	@$(BIOME) check --write $(PACKAGES_DIR)/

##@ CI checks

VERSION_CHECK_SCRIPT := $(SCRIPTS_DIR)/check_bun_version.sh
.PHONY: ci_check_version
ci_check_version: ## check that installed bun version matches .bun_version
	@echo "checking bun version..."
	@$(VERSION_CHECK_SCRIPT)

UPDATES_CHECK_SCRIPT := $(SCRIPTS_DIR)/check_updates.sh
.PHONY: ci_check_updates
ci_check_updates: ## check GitHub for newer versions of bun, dockerfile base image, and npm packages (warning only)
	@$(UPDATES_CHECK_SCRIPT) --changelog

.PHONY: ci_check_lint
ci_check_lint: ## run biome linter on packages/
	@echo "running biome linter..."
	@$(BIOME) check $(PACKAGES_DIR)/

.PHONY: ci_check_build
ci_check_build: ## compile-check all packages without storing output + tsc type check
	@echo "checking compilation..."
	BUILD_TMP=$$(mktemp -d); \
		$(BUN) build $(BUN_SRC)/index.ts --bundle --target bun --outdir $$BUILD_TMP && \
		EXIT=$$?; rm -rf $$BUILD_TMP; exit $$EXIT
	$(BUN) tsc --noEmit

.PHONY: ci_sec
ci_sec: ## audit production dependencies for known vulnerabilities (bun audit --prod)
	@echo "running security audit (production deps)..."
	@$(BUN) audit --prod

PATTERN ?=
DEBUG   ?=
.PHONY: ci_test
ci_test: ## run core + bun adapter tests with bun (e.g. make test test_name)
	@echo "running tests (bun)..."
	@$(BUN) test \
		$(if $(DEBUG),--inspect-wait,--isolate --parallel=4) \
		$(if $(PATTERN),--test-name-pattern=$(PATTERN)) \
		$(CORE_SRC)/ $(BUN_SRC)/

.PHONY: ci_checks
ci_checks: ci_check_version ci_check_updates ci_check_lint ci_check_build ci_sec ci_test ## run all CI checks in order
	@echo "all CI checks passed!"

##@ CI gen

VALID_TARGETS := bun-darwin-arm64 bun-darwin-x64 bun-darwin-x64-baseline \
                 bun-linux-x64 bun-linux-x64-modern bun-linux-x64-baseline \
                 bun-linux-arm64 \
                 bun-linux-x64-musl bun-linux-arm64-musl
TARGET        ?=

.PHONY: _check_target
_check_target:
	@[ -n "$(TARGET)" ] || (echo "error: TARGET is required (allowed: $(VALID_TARGETS))"; exit 1)
	@[ -n "$(filter $(TARGET),$(VALID_TARGETS))" ] || (echo "error: invalid TARGET '$(TARGET)' (allowed: $(VALID_TARGETS))"; exit 1)

.PHONY: ci_binary
ci_binary: _check_target ## compile binary for TARGET. TARGET=<bun-darwin-arm64|bun-darwin-x64[-baseline]|bun-linux-x64[-modern|-baseline|-musl]|bun-linux-arm64[-musl]>
	@echo "compile binary for $(TARGET)..."
	@$(BUN) build $(BUN_SRC)/run_litevolve.ts \
		--compile \
		--target=$(TARGET) \
		--minify-whitespace \
		--minify-syntax \
		--outfile $(DIST_DIR)/litevolve
