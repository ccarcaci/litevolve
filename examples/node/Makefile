IMAGE ?= node:slim
CONTAINER ?= litevolve_example_node
PKG := litevolve-node

.PHONY: run up install check_version typecheck migrate down

# ponytail: teardown is a recipe step, not a prerequisite — make runs a prereq
# only once, so listing `down` twice would skip the final stop
run: check_version up install typecheck migrate run_bin
	$(MAKE) down

# ponytail: host-side, no container needed — the pin in package.json is what we compare
check_version:
	@pinned=$$(sed -n 's/.*"$(PKG)": *"\([^"]*\)".*/\1/p' package.json); \
	latest=$$(npm view $(PKG) version); \
	echo "pinned=$$pinned latest=$$latest"; \
	[ "$$pinned" = "$$latest" ] || { echo "$(PKG) $$pinned is not the latest ($$latest)"; exit 1; }

up: down
	docker run --detach --rm --name $(CONTAINER) \
		-v $(CURDIR):/app/examples/node \
		-v $(CURDIR)/../../migrations:/app/migrations:ro \
		-w /app/examples/node \
		$(IMAGE) sleep infinity

install:
	docker exec $(CONTAINER) npm install

typecheck:
	docker exec $(CONTAINER) npm run typecheck

migrate:
	docker exec $(CONTAINER) node index.ts

run_bin:
	docker exec $(CONTAINER) npx --yes litevolve-node \
		--apply_version=3 \
		--db_path=:memory: \
		--migrations_path=/app/migrations/working \
		--init_seeds
	docker exec $(CONTAINER) npx --yes litevolve-node \
		--db_path=:memory: \
		--migrations_path=/app/migrations/working \
		--init_seeds

down:
	-docker stop $(CONTAINER)
	rm -f package-lock.json
