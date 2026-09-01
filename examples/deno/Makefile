IMAGE ?= denoland/deno:alpine
CONTAINER ?= litevolve_example_deno
PKG := litevolve-node

.PHONY: run up install typecheck migrate run_bin down

run: up install typecheck migrate run_bin down

# ponytail: no check_version target — deno.json pins litevolve-node exactly (0.2.2),
# a "must equal npm latest" check would just break `make run` on every upstream release

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
	docker exec $(CONTAINER) deno run -A npm:$(PKG)@0.2.2 \
		--apply_version=3 \
		--db_path=:memory: \
		--migrations_path=/app/migrations/working \
		--init_seeds
	docker exec $(CONTAINER) deno run -A npm:$(PKG)@0.2.2 \
		--db_path=:memory: \
		--migrations_path=/app/migrations/working \
		--init_seeds

down:
	docker stop $(CONTAINER)
	rm -f deno.lock
