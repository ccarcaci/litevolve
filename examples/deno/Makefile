IMAGE ?= denoland/deno:alpine
CONTAINER ?= litevolve_example_deno
PKG := litevolve-node

.PHONY: run up install check_version typecheck migrate run_bin down

# ponytail: teardown is a recipe step, not a prerequisite — make runs a prereq
# only once, so listing `down` twice would skip the final stop
run: check_version up install typecheck migrate run_bin
	$(MAKE) down

# ponytail: host-side, no container needed — the deno.json pin is what we compare
check_version:
	@pinned=$$(sed -n 's/.*npm:$(PKG)@\([^"]*\)".*/\1/p' deno.json); \
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
	docker exec $(CONTAINER) deno install --minimum-dependency-age 0

typecheck:
	docker exec $(CONTAINER) deno task typecheck

migrate:
	docker exec $(CONTAINER) deno task start

# deno runs the package's single `bin` entry (litevolve-node/dist/run_litevolve.js)
run_bin:
	docker exec $(CONTAINER) deno run -A npm:$(PKG) \
		--apply_version=3 \
		--db_path=:memory: \
		--migrations_path=/app/migrations/working \
		--init_seeds
	docker exec $(CONTAINER) deno run -A npm:$(PKG) \
		--db_path=:memory: \
		--migrations_path=/app/migrations/working \
		--init_seeds

down:
	-docker stop $(CONTAINER)
	rm -f deno.lock
