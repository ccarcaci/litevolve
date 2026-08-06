IMAGE ?= node:22-slim
CONTAINER ?= litevolve_example_node
PKG := litevolve-node

.PHONY: run up install check_version typecheck migrate down

run: check_version up install typecheck migrate down

# ponytail: host-side, no container needed — the pin in package.json is what we compare
check_version:
	@pinned=$$(sed -n 's/.*"$(PKG)": *"\([^"]*\)".*/\1/p' package.json); \
	latest=$$(npm view $(PKG) version); \
	echo "pinned=$$pinned latest=$$latest"; \
	[ "$$pinned" = "$$latest" ] || { echo "$(PKG) $$pinned is not the latest ($$latest)"; exit 1; }

up: down
	docker run -d --name $(CONTAINER) \
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

down:
	-docker rm -f $(CONTAINER)
