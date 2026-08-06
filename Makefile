# litevolve: SQLite migration runner

BUN          := bun
BIOME        := bunx biome
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Workspace layout
RUNTIMES_DIR  := $(MAKEFILE_DIR)runtimes
BUN_DIR       := $(RUNTIMES_DIR)/bun
BUN_SRC       := $(BUN_DIR)/src
ENTRY_POINT   := $(BUN_SRC)/run_litevolve.ts

# Directories
SCRIPTS_DIR := $(MAKEFILE_DIR)scripts

# Required: provide when calling make
DB_PATH         ?=
VERSION         ?=
MIGRATIONS_PATH ?= $(MAKEFILE_DIR)

##@ litevolve - SQLite migration runner
##@ usage: make [target] DB_PATH=<path> VERSION=<n>

.DEFAULT_GOAL := help

.PHONY: help
help: ## show this help message
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ operate

.PHONY: _check_args
_check_args:
	@[ -n "$(DB_PATH)" ] || (echo "error: DB_PATH is required  (e.g. make migrate DB_PATH=./data/rsvr.db VERSION=1)"; exit 1)
	@[ -n "$(VERSION)" ] || (echo "error: VERSION is required  (e.g. make migrate DB_PATH=./data/rsvr.db VERSION=1)"; exit 1)

.PHONY: migrate
.ONESHELL:
migrate: _check_args ## apply migrations up/down to VERSION. DB_PATH=<path> VERSION=<n>
	@echo "migrating $(DB_PATH) to version $(VERSION)..."
	@cd $(BUN_DIR)
	@$(BUN) run $(ENTRY_POINT) \
		--db_path=$(DB_PATH) \
		--migrations_path=$(MIGRATIONS_PATH) \
		--apply_version=$(VERSION)
	@cd $(MAKEFILE_DIR)

.PHONY: migrate_seeds
.ONESHELL:
migrate_seeds: _check_args ## migrate fresh DB to VERSION with seeds (--init_seeds). DB_PATH=<path> VERSION=<n>
	@echo "migrating $(DB_PATH) to version $(VERSION) with init_seeds..."
	@cd $(BUN_DIR)
	@$(BUN) run $(ENTRY_POINT) \
		--db_path=$(DB_PATH) \
		--migrations_path=$(MIGRATIONS_PATH) \
		--apply_version=$(VERSION) \
		--init_seeds
	@cd $(MAKEFILE_DIR)

NODE_CHANGESET_DIR := $(RUNTIMES_DIR)/node/.changeset
BUN_CHANGESET_DIR := $(RUNTIMES_DIR)/bun/.changeset
DENO_CHANGESET_DIR := $(RUNTIMES_DIR)/deno/.changeset
.PHONY: yield_version
.ONESHELL:
yield_version: ## bump versions from changeset files (node + bun + deno), commit and tag <pkg>@<semver>
	@claude --print "Generate changeset file content for the changes in @runtimes/node/ folder relative to the current active branch" > $(NODE_CHANGESET_DIR)/curr_changeset.md
	@claude --print "Generate changeset file content for the changes in @runtimes/bun/ folder relative to the current active branch" > $(BUN_CHANGESET_DIR)/curr_changeset.md
	@claude --print "Generate changeset file content for the changes in @runtimes/deno/ folder relative to the current active branch" > $(DENO_CHANGESET_DIR)/curr_changeset.md
	@if ls $(NODE_CHANGESET_DIR)/*.md 2>/dev/null | grep -qv README.md; then \
		echo "versioning node..."; cd $(RUNTIMES_DIR)/node && npx changeset version; cd $(MAKEFILE_DIR); \
	else echo "node: no changeset, skipping"; fi
	@if ls $(BUN_CHANGESET_DIR)/*.md 2>/dev/null | grep -qv README.md; then \
		echo "versioning bun..."; cd $(RUNTIMES_DIR)/bun && bunx changeset version; cd $(MAKEFILE_DIR); \
	else echo "bun: no changeset, skipping"; fi
	@if ls $(DENO_CHANGESET_DIR)/*.md 2>/dev/null | grep -qv README.md; then \
		echo "versioning deno..."; cd $(RUNTIMES_DIR)/deno && npx changeset version; cd $(MAKEFILE_DIR); \
	else echo "deno: no changeset, skipping"; fi

# tag name and version both come from package.json, so they cannot drift from what
# gets published - publish.yml re-runs the same check and refuses a mismatch.
# annotated on purpose: `git push --follow-tags` ignores lightweight tags.
.PHONY: yield_new_version
.ONESHELL:
yield_new_version: ## tag the current main commit <pkg>@<semver>, run after the dev branch is merged
	@[ "$$(git rev-parse --abbrev-ref HEAD)" = "main" ] || \
		{ echo "error: not on main - publish.yml refuses tags that are not on main"; exit 1; }
	@git diff --quiet && git diff --cached --quiet || \
		{ echo "error: uncommitted changes - the tag would not describe them"; exit 1; }
	@for rt in bun node deno; do \
		tag="$$(cd $(RUNTIMES_DIR)/$$rt && node -p "const p = require('./package.json'); p.name + '@' + p.version")"; \
		if git rev-parse -q --verify "refs/tags/$$tag" >/dev/null; then \
			echo "$$tag: already tagged, skipping"; \
		else \
			git tag -a -m "$$tag" "$$tag" && echo "tagged $$tag"; \
		fi; \
	done
	@echo "now run: git push --follow-tags"

##@ setup and cleanup

.PHONY: install
.ONESHELL:
install: ## install Bun dependencies for development purposes
	@cd $(BUN_DIR)
	@echo "installing dependencies..."
	@$(BUN) install
	@echo "Updating biome configuration..."
	./node_modules/.bin/biome migrate --write
	@cd $(MAKEFILE_DIR)

.PHONY: clean
.ONESHELL:
clean: ## remove node_modules, bun.lockb, *.db, runtimes/*/dist/
	@cd $(BUN_DIR)
	@echo "cleaning up..."
	@rm -rf node_modules
	@rm -f bun.lockb
	@rm -f *.db
	@cd $(MAKEFILE_DIR)
	@rm -rf $(RUNTIMES_DIR)/*/dist
	@echo "clean complete!"

##@ development

.PHONY: align_artifacts
align_artifacts: ## align core directory with node and deno versions, bun version is the master one
	cp -R $(BUN_SRC)/core/* $(RUNTIMES_DIR)/node/src/core
	cp -R $(BUN_SRC)/core/* $(RUNTIMES_DIR)/deno/src/core
	cp LICENSE $(RUNTIMES_DIR)/node/LICENSE
	cp LICENSE $(RUNTIMES_DIR)/bun/LICENSE
	cp LICENSE $(RUNTIMES_DIR)/deno/LICENSE
	cp README.md $(RUNTIMES_DIR)/node/README.md
	cp README.md $(RUNTIMES_DIR)/bun/README.md
	cp README.md $(RUNTIMES_DIR)/deno/README.md

.PHONY: test
test: ## run core + bun adapter tests (e.g. make test <name>)
	@$(BUN) test --verbose \
		$(if $(filter-out test,$(MAKECMDGOALS)),--test-name-pattern=$(filter-out test,$(MAKECMDGOALS))) \
		$(BUN_SRC)

.PHONY: test_debug
test_debug: ## run core + bun adapter tests with debugger (e.g. make test_debug <name>)
	@$(BUN) test --verbose \
		--timeout=7200000 \
		--inspect-wait \
		$(if $(filter-out test_debug,$(MAKECMDGOALS)),--test-name-pattern=$(filter-out test_debug,$(MAKECMDGOALS))) \
		$(BUN_SRC)

ifneq ($(filter test test_debug,$(MAKECMDGOALS)),)
%: ;
endif

.PHONY: format
format: ## fix formatting, linting (safe fixes), and import sorting with biome
	@echo "fixing formatting, linting, and import sorting..."
	@$(BIOME) check --write $(RUNTIMES_DIR)/

##@ CI checks

.PHONY: ci_check_version
ci_check_version: ## check that installed bun version matches .bun_version
	@echo "checking bun version..."
	@$(SCRIPTS_DIR)/ci_check_bun_version.sh

.PHONY: ci_check_align
ci_check_align: ## check that node/core/src and deno/core/src are aligned with bun/core/src
	@$(SCRIPTS_DIR)/ci_check_align.sh

.PHONY: ci_check_updates
ci_check_updates: ## check GitHub for newer versions of bun, dockerfile base image, and npm packages (warning only)
	@$(SCRIPTS_DIR)/ci_check_updates_bun.sh

.PHONY: ci_check_lint
ci_check_lint: ## run biome linter on runtimes/
	@$(SCRIPTS_DIR)/ci_lint.sh

.PHONY: ci_check_build
ci_check_build: ## compile-check all packages without storing output + tsc type check
	@$(SCRIPTS_DIR)/ci_build.sh bun
	@$(SCRIPTS_DIR)/ci_types.sh bun

.PHONY: ci_sec
ci_sec: ## audit production dependencies for known vulnerabilities (bun audit --prod)
	@$(SCRIPTS_DIR)/ci_sec.sh bun

.PHONY: ci_test
ci_test: ## run core + bun adapter tests with bun
	@$(SCRIPTS_DIR)/ci_test.sh bun

.PHONY: ci_checks
ci_checks: ci_check_version ci_check_align ci_check_updates ci_check_lint ci_check_build ci_sec ci_test ## run all CI checks in order
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

DIST_DIR := dist
.PHONY: ci_binary
ci_binary: _check_target ## compile binary for TARGET. TARGET=<bun-darwin-arm64|bun-darwin-x64[-baseline]|bun-linux-x64[-modern|-baseline|-musl]|bun-linux-arm64[-musl]>
	@echo "compile binary for $(TARGET)..."
	@$(BUN) build $(BUN_SRC)/run_litevolve.ts \
		--compile \
		--target=$(TARGET) \
		--minify-whitespace \
		--minify-syntax \
		--outfile $(DIST_DIR)/litevolve
