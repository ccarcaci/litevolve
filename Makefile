# Makefile for db_migrations
# SQLite migration runner — entry point: run_migration.ts

BUN          := bun
BIOME := bunx biome
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ENTRY_POINT  := $(MAKEFILE_DIR)src/run_litevolve.ts

# Directories
SRC_DIR := src
DATA_DIR := data
DIST_DIR := dist
SCRIPTS_DIR := scripts

# Required: provide when calling make
DB_PATH         ?=
VERSION         ?=
MIGRATIONS_PATH ?= $(MAKEFILE_DIR)

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help message
	@echo "litevolve - SQLite migration runner"
	@echo ""
	@echo "Usage: make [target] DB_PATH=<path> VERSION=<n>"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Operate

.PHONY: _check_args
_check_args:
	@[ -n "$(DB_PATH)" ]  || (echo "Error: DB_PATH is required  (e.g. make migrate DB_PATH=./data/rsvr.db VERSION=1)"; exit 1)
	@[ -n "$(VERSION)" ]  || (echo "Error: VERSION is required  (e.g. make migrate DB_PATH=./data/rsvr.db VERSION=1)"; exit 1)

.PHONY: migrate
migrate: _check_args ## Apply migrations up/down to VERSION. DB_PATH=<path> VERSION=<n>
	@echo "Migrating $(DB_PATH) to version $(VERSION)..."
	@$(BUN) run $(ENTRY_POINT) \
		--db_path=$(DB_PATH) \
		--migrations_path=$(MIGRATIONS_PATH) \
		--apply_version=$(VERSION)

.PHONY: migrate_seeds
migrate_seeds: _check_args ## Migrate fresh DB to VERSION with seeds (--init_seeds). DB_PATH=<path> VERSION=<n>
	@echo "Migrating $(DB_PATH) to version $(VERSION) with init_seeds..."
	@$(BUN) run $(ENTRY_POINT) \
		--db_path=$(DB_PATH) \
		--migrations_path=$(MIGRATIONS_PATH) \
		--apply_version=$(VERSION) \
		--init_seeds

##@ Setup and Cleanup

.PHONY: install
install: ## Install dependencies using bun
	@echo "Installing dependencies..."
	@$(BUN) install

.PHONY: clean
clean: ## Remove node_modules, *.db, data/, dist/
	@echo "Cleaning up..."
	@rm -rf node_modules
	@rm -f *.db
	@rm -rf $(DATA_DIR)
	@rm -rf $(DIST_DIR)
	@echo "Clean complete!"

.PHONY: clean_all
clean_all: clean ## Clean everything including bun lockfile
	@rm -f bun.lockb
	@echo "Deep clean complete!"

##@ Development

.PHONY: test_debug
test_debug: ## Run tests with debugger (e.g., make test_debug test_name)
	@echo "Running tests..."
	@$(BUN) test --inspect-wait $(if $(filter-out test_debug,$(MAKECMDGOALS)),--test-name-pattern=$(filter-out test_debug,$(MAKECMDGOALS))) $(SRC_DIR)/

.PHONY: format
format: ## Fix formatting, linting (safe fixes), and import sorting with Biome
	@echo "Fixing formatting, linting, and import sorting..."
	@$(BIOME) check --write $(SRC_DIR)/

##@ CI

VERSION_CHECK_SCRIPT := $(SCRIPTS_DIR)/check_bun_version.sh
.PHONY: ci_check_version
ci_check_version: ## Check that installed Bun version matches .bun_version
	@echo "Checking Bun version..."
	@$(VERSION_CHECK_SCRIPT)

UPDATES_CHECK_SCRIPT := $(SCRIPTS_DIR)/check_updates.sh
.PHONY: ci_check_updates
ci_check_updates: ## Check GitHub for newer versions of Bun, Dockerfile base image, and npm packages (warning only)
	@$(UPDATES_CHECK_SCRIPT) --changelog

.PHONY: ci_lint
ci_lint: ## Run Biome linter on src/
	@echo "Running Biome linter..."
	@$(BIOME) check $(SRC_DIR)/

.PHONY: ci_build
ci_build: ## Compile src/ with Bun without storing output (checks code is runnable)
	@echo "Checking compilation..."
	@BUILD_TMP=$$(mktemp -d); $(BUN) build $(SRC_DIR)/index.ts --target bun --outdir $$BUILD_TMP; EXIT=$$?; rm -rf $$BUILD_TMP; exit $$EXIT
	@$(BUN) tsc --noEmit

.PHONY: ci_sec
ci_sec: ## Audit production dependencies for known vulnerabilities (bun audit --prod)
	@echo "Running security audit (production deps)..."
	@$(BUN) audit --prod

.PHONY: ci_test
ci_test: ## Run tests with Bun native test runner (e.g. make test test_name)
	@echo "Running tests..."
	@$(BUN) test --isolate --parallel=4 $(if $(filter-out ci_test,$(MAKECMDGOALS)),--test-name-pattern=$(filter-out ci_test,$(MAKECMDGOALS))) $(SRC_DIR)/

.PHONY: ci_fast
ci_fast: ci_check_version ci_check_updates ci_lint ci_build ci_sec ## Run ci-check, ci-build, ci-test, ci-sec, and ci-updates in order
	make ci_test
	@echo "All CI checks passed!"
