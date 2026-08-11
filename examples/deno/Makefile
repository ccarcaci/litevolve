IMAGE ?= denoland/deno:alpine
CONTAINER ?= litevolve_example_deno
PKG := litevolve-deno

.PHONY: run up install check_version migrate down

run: check_version up install migrate run_bin down

# ponytail: host-side, no container needed — the pin in deno.json is what we compare
check_version:
	@pinned=$$(sed -n 's/.*"npm:$(PKG)@\([^"]*\)".*/\1/p' deno.json); \
	latest=$$(npm view $(PKG) version); \
	echo "pinned=$$pinned latest=$$latest"; \
	[ "$$pinned" = "$$latest" ] || { echo "$(PKG) $$pinned is not the latest ($$latest)"; exit 1; }

# ponytail: denoland/deno's entrypoint is `deno`, so override it to keep the container alive
up: down
	docker run --detach --rm --name $(CONTAINER) --entrypoint sleep \
		-v $(CURDIR):/app/examples/deno \
		-v $(CURDIR)/../../migrations:/app/migrations:ro \
		-w /app/examples/deno \
		$(IMAGE) infinity

install:
	docker exec $(CONTAINER) deno install

migrate:
	docker exec $(CONTAINER) deno task start

run_bin:
	docker exec $(CONTAINER) npx --yes litevolve-deno \
		--apply_version=3 \
		--db_path=:memory: \
		--migrations_path=/app/migrations/working \
		--init_seeds
	docker exec $(CONTAINER) npx --yes litevolve-deno \
		--db_path=:memory: \
		--migrations_path=/app/migrations/working \
		--init_seeds

down:
	-docker stop $(CONTAINER)
	-docker rm --force $(CONTAINER)
