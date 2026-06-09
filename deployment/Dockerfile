FROM oven/bun:1.3.14 AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends make && rm -rf /var/lib/apt/lists/*

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

COPY Makefile tsconfig.json ./
COPY src/ ./src/

ARG GLIBC_BINARIES
ARG MUSL_BINARIES
ARG DARWIN_BINARIES

# build all binaries, then, in the following stages, each stage will copy only its compatible binaries
RUN mkdir -p dist \
 && for binary in $GLIBC_BINARIES $MUSL_BINARIES $DARWIN_BINARIES; do \
      target=$(echo "$binary" | sed 's/litevolve_/bun-/' | tr '_' '-'); \
      make ci_binary TARGET="$target" && mv dist/litevolve "dist/$binary"; \
    done

##  --

FROM debian:bookworm-slim AS debian_base
RUN apt-get update && apt-get install -y --no-install-recommends sqlite3 && rm -rf /var/lib/apt/lists/*

FROM alpine:3.23 AS alpine_base
RUN apk add --no-cache sqlite libstdc++ libgcc

#  -- Linux glibc (Debian) ---

FROM debian_base AS linux_glibc
ARG GLIBC_BINARIES
RUN --mount=type=bind,from=builder,source=/app/dist,target=/dist \
    for binary in $GLIBC_BINARIES; do \
        cp /dist/$binary /usr/local/bin/$binary && chmod +x /usr/local/bin/$binary; \
    done
COPY migrations/ /migrations/
COPY deployment/smoke_test.sh /usr/local/bin/smoke_test.sh
RUN chmod +x /usr/local/bin/smoke_test.sh

#  -- Linux musl (Alpine) ---

FROM alpine_base AS linux_musl
ARG MUSL_BINARIES
RUN --mount=type=bind,from=builder,source=/app/dist,target=/dist \
    for binary in $MUSL_BINARIES; do \
        cp /dist/$binary /usr/local/bin/$binary && chmod +x /usr/local/bin/$binary; \
    done
COPY migrations/ /migrations/
COPY deployment/smoke_test.sh /usr/local/bin/smoke_test.sh
RUN chmod +x /usr/local/bin/smoke_test.sh

#  -- Darwin ---
# macOS is not a supported Docker container OS — this stage is for binary
# extraction only via: docker build --target=darwin --output type=local,dest=./dist .

FROM builder AS darwin_collect
ARG DARWIN_BINARIES
RUN mkdir -p /darwin_dist \
    && for binary in $DARWIN_BINARIES; do \
        cp /app/dist/$binary /darwin_dist/$binary; \
    done

FROM scratch AS darwin
COPY --from=darwin_collect /darwin_dist/ /
