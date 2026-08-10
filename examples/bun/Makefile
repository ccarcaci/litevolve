IMAGE ?= oven/bun:latest
CONTAINER ?= litevolve_example_bun
PKG := litevolve-bun

.PHONY: run up install check_version migrate down

run: check_version up install migrate run_bin down

# ponytail: host-side, no container needed — the pin in package.json is what we compare
check_version:
	@pinned=$$(sed -n 's/.*"$(PKG)": *"\([^"]*\)".*/\1/p' package.json); \
	latest=$$(npm view $(PKG) version); \
	echo "pinned=$$pinned latest=$$latest"; \
	[ "$$pinned" = "$$latest" ] || { echo "$(PKG) $$pinned is not the latest ($$latest)"; exit 1; }

up: down
	docker run -d --name $(CONTAINER) \
		-v $(CURDIR):/app/examples/bun \
		-v $(CURDIR)/../../migrations:/app/migrations:ro \
		-w /app/examples/bun \
		$(IMAGE) sleep infinity

install:
	docker exec $(CONTAINER) bun install

migrate:
	docker exec $(CONTAINER) bun index.ts

run_bin:
	docker exec $(CONTAINER) bunx litevolve-bun \
		--apply_version=3 \
		--db_path=:memory: \
		--migrations_path=/app/migrations/working \
		--init_seeds

down:
	-docker rm -f $(CONTAINER)
