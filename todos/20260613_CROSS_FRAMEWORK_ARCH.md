# Cross-Runtime Architecture: Bun, Node.js, Deno

_Date: 2026-06-13. Aligned to code 2026-07-31 — sections below reflect what is **built**, not just planned._

## Goal

Publish `litevolve` on npm so it works as a library on Bun, Node.js, and Deno.

---

## Hard Blocker — RESOLVED (adapter implemented)

Originally `migrate.ts` imported `Database` from `bun:sqlite` directly (Bun-only). **Resolved:** core no longer touches any SQLite API. `core/migrate.ts` exposes `migrate_with_adapter(...)` and operates against the `db_adapter` interface (`core/db_adapter.ts`); each runtime supplies its own backend. Remaining notes:
- `run_litevolve.ts` uses `node:util` `parseArgs` (not `Bun.argv`) — already cross-runtime.
- `node:fs` is used in each runtime's `index.ts` (`existsSync`) — fine everywhere.

---

## Options

### Option A — Bun-only publish (cheapest, narrowest) — NOT taken

Keep the code as-is, Bun-only. Rejected: does not satisfy the cross-runtime requirement.

### Option B — Runtime adapter — **CHOSEN & IMPLEMENTED**

A thin SQLite adapter interface, one implementation per runtime. As built:

| Runtime      | Backend                         | Adapter                                        |
| ------------ | ------------------------------- | ---------------------------------------------- |
| Bun          | `bun:sqlite` `Database`         | none — `Database` satisfies `db_adapter` as-is |
| Node ≥ 22.5  | `node:sqlite` `DatabaseSync`    | `node_db_adapter` (`node/src/node_adapter.ts`) |
| Deno         | `npm:better-sqlite3` `Database` | `deno_db_adapter` (`deno/src/deno_adapter.ts`) |

**The `db_adapter` interface** (as built, `core/db_adapter.ts`):

```ts
export type query_result<T> = {
  get(...params: unknown[]): T | null
  run(...params: unknown[]): void
}
export type db_adapter = {
  run(sql: string): void
  query<T>(sql: string): query_result<T>
}
```

`core/migrate.ts` calls `migrate_with_adapter(apply_version, migrations_path, adapter, init_seeds)`. Each runtime's `index.ts` opens its native DB, sets `PRAGMA journal_mode=WAL` + `foreign_keys=ON`, then passes an adapter in. Bun passes the raw `Database` (call-compatible); Node/Deno wrap theirs in the adapter class (their `prepare()`/`exec()` shape differs from the interface).

**API compatibility notes:**
- `bun:sqlite` and `better-sqlite3` are call-compatible by design (Bun docs: _"Credit to better-sqlite3 and its contributors for inspiring the API"_) — but Deno still goes through `deno_db_adapter`, which normalizes `exec`/`prepare` to the interface.
- `node:sqlite` uses `DatabaseSync` + `prepare(sql)` — `node_db_adapter` maps `run(sql)`→`exec`, `query(sql)`→`prepare(sql)` with `get`/`run`.
- `node:sqlite` is **Stability 1.2 — Release candidate** as of Node v25.7.0. Available since v22.5.0.

## Chosen Strategy — AS BUILT: `runtimes/*` with duplicated-and-aligned core

The originally-planned `packages/*` workspace with a private `litevolve-core` shared via `workspace:*` was **not** built. Reality:

```
litevolve/                     ← repo root — NO root package.json, NO workspaces
  scripts/ci_check_align.sh    ← enforces core is byte-identical across runtimes
  runtimes/
    bun/                       ← "name": "litevolve-bun"  (CORE MASTER)
      package.json             ← devDeps only (bun:sqlite built-in)
      src/core/                ← db_adapter.ts, index.ts, migrate.ts, migration_error.ts
      src/index.ts, run_litevolve.ts
    node/                      ← "name": "litevolve-node"
      package.json             ← devDeps only (node:sqlite built-in ≥ 22.5)
      src/core/                ← COPY of bun's core (kept identical by ci_check_align.sh)
      src/index.ts, node_adapter.ts
    deno/                      ← "name": "litevolve-deno"
      package.json             ← dependencies: { "better-sqlite3": "13.0.2" }
      src/core/                ← COPY of bun's core
      src/index.ts, deno_adapter.ts
```

**Core is duplicated, not shared via a package.** `runtimes/bun/src/core` is the master; `scripts/ci_check_align.sh` runs `diff --brief --recursive` of node's and deno's `src/core` against bun's and fails CI on any drift (`make align_core` re-copies bun → node/deno). There is no `packages/core`, no root `package.json`, and no `workspace:*` protocol. Trade-off: three physical copies, but each runtime dir is a self-contained buildable/publishable unit with zero workspace tooling.

> ⚠️ **Deno is currently inconsistent.** `deno/package.json` still lists `"litevolve-core": "../core"` and `deno/src/{index,deno_adapter}.ts` import from the bare specifier `"litevolve-core"`, but **no `runtimes/core` dir exists** and deno's own core lives at `runtimes/deno/src/core`. Bun and Node import core via the relative `./core`. Deno must be reconciled (import `./core`, drop the `litevolve-core` dep) before it can build/publish. Out of scope for the current Bun+Node publish.

### What each package produces

| Package          | npm library | Docker image | Executable                    |
| ---------------- | ----------- | ------------ | ----------------------------- |
| `litevolve-bun`  | Yes         | Yes          | Yes (brew, GoReleaser, eopkg) |
| `litevolve-node` | Yes         | —            | —                             |
| `litevolve-deno` | Yes         | —            | —                             |

### Architecture Diagram

```
  runtimes/bun/src/core  ── ci_check_align.sh (diff --brief -r) ──► must equal node & deno core
  (CORE MASTER: db_adapter.ts index.ts migrate.ts migration_error.ts)
                       │ copied into each runtime's src/core
       ┌───────────────┼───────────────────┐
       ▼               ▼                    ▼
 ┌───────────────┐ ┌───────────────┐ ┌───────────────────┐
 │ runtimes/bun  │ │ runtimes/node │ │ runtimes/deno     │
 │ litevolve-bun │ │ litevolve-node│ │ litevolve-deno    │
 ├───────────────┤ ├───────────────┤ ├───────────────────┤
 │ bun:sqlite    │ │ node:sqlite   │ │ better-sqlite3    │
 │ (no adapter)  │ │ node_adapter  │ │ deno_adapter      │
 │ deps: none    │ │ deps: none    │ │ better-sqlite3    │
 │ engines:      │ │ engines:      │ │   13.0.2          │
 │  bun 1.3.14   │ │  (none yet)   │ │ ⚠ core-ref broken │
 │ exports:      │ │ exports:      │ │ exports:          │
 │  bun→src/*.ts │ │  ".":./dist/  │ │  ".":./dist/      │
 │  default→dist │ │               │ │                   │
 └───────┬───────┘ └───────┬───────┘ └─────────┬─────────┘
         │                 │                   │
═════════╪═════ CI / BUILD ╪═══════════════════╪═══════════
         ▼                 ▼                   ▼
   bun build        esbuild --bundle      bun build --target node
   --target bun     + tsc (.d.ts)         --external better-sqlite3
         │                 │               + deno check
         └─────────────────┴───────────────────┘
                           ▼
              npm publish --provenance
                           ▼
        npm: litevolve-bun / -node / -deno
```

Build commands are the real ones from `scripts/ci_build.sh`: **Node uses esbuild** (bundle → `dist/index.js`) with `tsc --emitDeclarationOnly` for `.d.ts`; Bun and Deno use `bun build`. `litevolve-bun` also feeds the additional binary/Docker/GoReleaser pipelines below.

The Docker image and standalone executable are CI/CD pipeline artifacts. They are compiled from the same source as `litevolve-bun` via a dedicated pipeline step (e.g. `make ci_binary`, GoReleaser) that runs independently of npm publishing. The `litevolve-bun/package.json` is unaware of them — its `"files"` allowlist covers only `dist/` and `src/`, and no lifecycle script or build hook in the package references binary compilation.

### GoReleaser Distribution

#### Artifact / channel verdict

| Artifact / Channel                    | Target platform               | GoReleaser config block              | Verdict                                                  |
| ------------------------------------- | ----------------------------- | ------------------------------------ | -------------------------------------------------------- |
| GitHub Release (archives + checksums) | all                           | `builds:` + `archives:` + `release:` | **ship** — baseline, automatic                           |
| Homebrew tap                          | macOS + Linux                 | `brews:`                             | **ship**                                                 |
| `.deb`                                | Ubuntu, Debian, Mint, Pop!_OS | `nfpms:` `formats: [deb]`            | **ship**                                                 |
| `.rpm`                                | RHEL, Fedora, Rocky, Alma     | `nfpms:` `formats: [rpm]`            | **ship**                                                 |
| AUR                                   | Arch, Manjaro, EndeavourOS    | `aurs:`                              | **ship** — GoReleaser pushes PKGBUILD automatically      |
| NUR                                   | NixOS + nix on any distro     | `nix:`                               | **ship** — low effort, growing audience                  |
| Docker image (`litevolve:latest`)     | Linux glibc                   | `dockers:` (glibc build target)      | **ship**                                                 |
| Docker image (`litevolve:musl`)       | Alpine-based                  | `dockers:` (musl build target)       | **ship** — needed for multi-stage builds                 |
| npm packages                          | Bun / Node / Deno             | separate `npm publish` CI step       | **ship** — outside GoReleaser scope                      |
| snap                                  | cross-distro (Ubuntu-first)   | `snapcrafts:`                        | **test first** — sandbox may block SQLite file access    |
| flatpak                               | cross-distro                  | `flatpaks:`                          | **skip** — sandbox model is wrong for a CLI tool         |
| `.apk` (Alpine native)                | Alpine                        | `nfpms:` `formats: [apk]`            | **skip** — Docker multi-stage build covers this use case |
| eopkg                                 | Solus                         | custom publisher                     | **skip** — too niche for the maintenance cost            |

#### Build matrix

`builds:` targets that feed all of the above:

| Target                 | Used by                                               |
| ---------------------- | ----------------------------------------------------- |
| `darwin/amd64`         | brew, GitHub release                                  |
| `darwin/arm64`         | brew, GitHub release                                  |
| `linux/amd64` (glibc)  | `.deb`, `.rpm`, AUR, Docker `latest`, GitHub release  |
| `linux/arm64` (glibc)  | `.deb`, `.rpm`, Docker `latest`, GitHub release       |
| `linux/amd64` (musl)   | Docker `musl`, GitHub release                         |
| `linux/arm64` (musl)   | Docker `musl`, GitHub release                         |

---

### Why three packages, not conditional exports on one

npm dependency installation is not runtime-aware — there is no `runtime` field, only `os` and `cpu`. Putting `better-sqlite3` in any shared `dependencies` or `optionalDependencies` field installs a native addon on Bun and Node consumers who will never use it. Three packages give each runtime an isolated `package.json` with only the deps it actually needs.

### `core` — duplicated per runtime, aligned by CI (AS BUILT)

`core/` (`db_adapter.ts`, `index.ts`, `migrate.ts`, `migration_error.ts`) holds all runtime-agnostic logic against the `db_adapter` interface. It is **physically copied** into `runtimes/{bun,node,deno}/src/core`. `runtimes/bun/src/core` is the master; `scripts/ci_check_align.sh` fails CI if node's or deno's copy drifts, and `make align_core` re-copies bun → node/deno.

The interface is intentionally a generic relational-DB shape (run / query→get/run), not a SQLite-specific wrapper, so a non-SQLite backend could implement it later.

**Why duplicate instead of a `workspace:*` shared package** (the originally-planned approach, dropped): no root `package.json`/workspace tooling to maintain; each `runtimes/*` dir is a standalone unit that builds and publishes on its own. The cost — three copies that could silently diverge — is bought off by the mandatory `ci_check_align.sh` gate. `litevolve-core` is **not** a real published or workspace package.

### Why three packages, not one with conditional exports

The root problem is `better-sqlite3`: a native addon requiring a `postinstall` compile step. npm has no `runtime` field — only `os` and `cpu` — so there is no way to say "install this dep only on Deno". Any package listing `better-sqlite3` in `dependencies`/`optionalDependencies` installs it on every consumer, including Bun/Node users who never use it. Separate packages give each runtime exactly the deps it needs. (See the "Publishing Execution Plan" section for how this interacts with the README's single-`litevolve` promise for the Bun+Node-only scope.)

### How the bundle collapses core in

Each runtime's build (`scripts/ci_build.sh`) starts from that runtime's `src/index.ts`, follows imports into the sibling `src/core/`, and **inlines core** into a single self-contained `dist/index.js` — Bun/Deno via `bun build`, Node via `esbuild`. No `litevolve-core` reference survives in the output, and none appears in any consumer's `node_modules`. (Deno's build is currently blocked by the broken `litevolve-core` import noted above.)

### API — AS BUILT

`migrate_db(apply_version, migrations_path, db_path, init_seeds?)` in each runtime opens the native DB and calls `migrate_with_adapter(...)` with the runtime's adapter. `migration_error` is re-exported from core.

## package.json per runtime package

Each package targets exactly one runtime, so no multi-runtime conditional routing is needed. The only conditional in `litevolve-bun` is a **TypeScript source optimization**: Bun can import raw `.ts` files directly, skipping compilation. This is unrelated to runtime discrimination — it is a build-output choice for the Bun consumer only.

Bun docs (verbatim): _"If your library is written in TypeScript, you can publish your (un-transpiled!) TypeScript files to npm directly. If you specify your package's `*.ts` entrypoint in the `"bun"` condition, Bun will directly import and execute your TypeScript source files."_

**`runtimes/bun/package.json` — AS BUILT:**

```json
{
  "name": "litevolve-bun",
  "version": "0.0.1",
  "type": "module",
  "exports": {
    ".": {
      "bun": { "types": "./src/index.ts", "default": "./src/index.ts" },
      "default": "./dist/index.js"
    }
  },
  "types": "./dist/index.d.ts",
  "files": ["dist", "src"],
  "engines": { "bun": "1.3.14" },
  "devDependencies": { "@types/bun": "1.3.14", "@biomejs/biome": "2.5.6" }
}
```

Engine is pinned to the **exact** Bun version (`1.3.14`), matching the repo's exact-pin policy — not a `>=`/`=1.0` range. The `"bun"` condition serves raw TypeScript to Bun consumers; `"default"` serves compiled JS to Node/IDE tooling.

**`runtimes/node/package.json` — AS BUILT (⚠ `engines` still missing):**

```json
{
  "name": "litevolve-node",
  "version": "0.0.1",
  "type": "module",
  "exports": { ".": "./dist/index.js" },
  "types": "./dist/index.d.ts",
  "files": ["dist"],
  "devDependencies": { "@types/node": "26.1.2", "typescript": "7.0.2" }
}
```

`node:sqlite` (`DatabaseSync`) was added in v22.5.0 (Stability 1.2 RC as of v25.7.0). The package **should** declare `"engines": { "node": ">=22.5" }` (or an exact pin) — not present yet; tracked as a publish gap below.

**`runtimes/deno/package.json` — AS BUILT (⚠ broken core ref):**

```json
{
  "name": "litevolve-deno",
  "version": "0.0.1",
  "type": "module",
  "exports": { ".": "./dist/index.js" },
  "types": "./dist/index.d.ts",
  "files": ["dist"],
  "dependencies": { "better-sqlite3": "13.0.2", "litevolve-core": "../core" },
  "devDependencies": { "@types/better-sqlite3": "7.6.13", "typescript": "7.0.2" },
  "trustedDependencies": ["better-sqlite3"]
}
```

`better-sqlite3` is pinned exact (`13.0.2`, not the earlier-planned `11.0.0`). The `"litevolve-core": "../core"` dep points at a **nonexistent** `runtimes/core` dir and must be removed (core is at `runtimes/deno/src/core`, imported via `./core`). `trustedDependencies` is required so Bun-based tooling runs `better-sqlite3`'s native `postinstall`.

Exact-pin policy holds across runtimes and deps; `scripts/ci_check_updates_*.sh` surface newer versions for manual promotion after testing.

### `better-sqlite3` and Bun's lifecycle scripts

Bun docs (verbatim): _"For security reasons Bun does not execute lifecycle scripts of installed dependencies. To tell Bun to allow lifecycle scripts for a particular package, add the package to `trustedDependencies` in your package.json."_

`better-sqlite3` requires a `postinstall` to compile its native binary. Deno users installing `litevolve-deno` via `npm install` get it compiled automatically. Bun users consuming `litevolve-deno` must add `better-sqlite3` to their own `trustedDependencies`. This should be documented.

**Open question**: if Deno supports `node:sqlite` natively (not confirmed from docs), `litevolve-deno` can use the same adapter as `litevolve-node` and drop `better-sqlite3` entirely.

---

## npm Publishing Security

### 2FA

npm requires 2FA on your account or a granular access token with bypass 2FA. Store recovery codes in a password manager; they are the only recovery path if the 2FA device is lost.

### Provenance (supply-chain attestation)

Links the published package to the exact source commit and CI build. Consumers verify with `npm audit signatures`.

Requirements:
- npm CLI ≥ 9.5.0
- GitHub Actions or GitLab CI with a cloud-hosted runner
- Workflow permission: `id-token: write`
- `repository` field in each `package.json` must match the publishing source (case-sensitive)
- Publish command: `npm publish --provenance --access public`

### Additional hardening

- `"files"` allowlist on each package — never `.npmignore`. Prevents accidentally shipping `.env`, test fixtures, migration SQL, or source maps with absolute paths.
- No `postinstall` or network-fetching lifecycle scripts in litevolve packages themselves.
- Always use pinned versions.

---

## Open Items

1. **Deno reconciliation** — remove `"litevolve-core": "../core"`, switch `deno/src/*` imports from bare `litevolve-core` to `./core`. Deno cannot build until then. (Out of scope for the Bun+Node publish.)
2. **Node `engines`** — not declared yet; add `>=22.5` (or exact pin) before publishing `litevolve-node`.
3. **Versioning discipline** — the three package names carry independent `version` fields (all `0.0.1`). Decide whether they publish together at a locked version (Changesets, or a single tag-driven job) or independently.
4. **`node:sqlite` stability risk** — Stability 1.2 means the API is not frozen; Node may change it in a semver-minor/patch without calling it breaking. Consider pinning an exact Node version rather than `>=22.5`. Exact runtime pinning is already the policy elsewhere (`.bun-version` 1.3.14, `.node-version` 24.18.1), so this aligns.

---

## Sources

- [Bun: bun:sqlite](https://bun.sh/docs/api/sqlite)
- [Bun: Module resolution / conditional exports](https://bun.sh/docs/runtime/modules)
- [Bun: bun install / lifecycle scripts](https://bun.sh/docs/cli/install)
- [Bun: Workspaces](https://bun.sh/docs/install/workspaces)
- [Node.js: node:sqlite](https://nodejs.org/api/sqlite.html)
- [Node.js: Conditional exports](https://nodejs.org/api/packages.html#conditional-exports)
- [Deno: Node.js compatibility](https://docs.deno.com/runtime/fundamentals/node/)
- [WinterCG Runtime Keys proposal](https://runtime-keys.proposal.wintercg.org/)
- [npm: workspaces](https://docs.npmjs.com/cli/v11/using-npm/workspaces)
- [npm: peerDependenciesMeta](https://docs.npmjs.com/cli/v11/configuring-npm/package-json#optionaldependencies)
- [npm: Generating provenance statements](https://docs.npmjs.com/generating-provenance-statements)
- [npm: Configuring 2FA](https://docs.npmjs.com/configuring-two-factor-authentication)
- [TypeScript: package.json exports](https://www.typescriptlang.org/docs/handbook/modules/reference.html#packagejson-exports)
- [Hono package.json](https://cdn.jsdelivr.net/npm/hono/package.json)
- [Drizzle ORM package.json](https://cdn.jsdelivr.net/npm/drizzle-orm/package.json)

---

## Publishing Execution Plan — Bun + Node only, npm

_Added 2026-07-31. Scope: publish for **Bun and Node.js** (Deno out of scope here)._

### Naming — code already committed to separate packages, but README says otherwise

**What the code has done:** three `package.json` files named `litevolve-bun`, `litevolve-node`, `litevolve-deno`. So the *separate-packages* decision is effectively made in the tree.

**The live contradiction:** `README.md` still advertises `npm install litevolve` (a single unscoped name that no `package.json` claims). One of these has to give before first publish:
- **Keep three names** (`litevolve-bun`/`-node`) — matches the code as-is; fix the README to install the runtime-specific package. Trivially extends to `-deno` later.
- **Add a single `litevolve`** umbrella with conditional exports (viable for the Bun+Node scope, since both use built-in SQLite / zero deps) — matches the README, but is *new work* not reflected in the current three-package tree, and Deno re-entry (`better-sqlite3` native dep) would be awkward.

```jsonc
// single-litevolve exports, IF that path is chosen (not currently in the tree)
"exports": { ".": {
  "bun":     { "types": "./src/index.ts", "default": "./src/index.ts" },
  "types":   "./dist/index.d.ts",
  "default": "./dist/index.js"      // node + everything else
}}
```

Default reading of the code: **ship the three separate names, fix the README.** The single-package assembly note below only applies if the umbrella path is chosen instead.

### `.npmignore` verdict — don't add one

Both packages already use the `files` **allowlist** in `package.json`, which is strictly better than an `.npmignore` denylist (default-deny vs. default-allow). If both exist, `files` wins and `.npmignore` is dead config. **Skip `.npmignore`.** Current allowlists are correct: node = `["dist"]` (compiled only ✅ — satisfies "Node should ship only the compiled version"), bun = `["dist","src"]` (src needed for the `bun` condition). npm force-includes `package.json`, `README`, `LICENSE` regardless.

### Gaps to close before first publish

1. **README/LICENSE not in package root.** They live at repo root; the package root is `runtimes/bun`, so the tarball ships none. → copy both into the publish dir at CI time (don't commit copies).
2. **Metadata absent** from every `package.json`: `description`, `license`, `repository` (must match publishing source, case-sensitive, for provenance), `homepage`, `keywords`, `author`.
3. **`engines.node` missing** on node package → `"engines": { "node": ">=22.5" }` (`node:sqlite`'s `DatabaseSync` added in 22.5.0). Repo `.node-version` is 24.18.1.
4. **`node:sqlite` is experimental** (Stability 1.2 RC; emits `ExperimentalWarning`, API may shift in minor/patch per Node policy) — document as a caveat, and consider pinning a Node minor rather than `>=22.5`. Biggest risk in shipping the Node build.
5. **`dist/` is gitignored** → the publish job must build (`ci_build.sh node && ci_build.sh bun`) before `npm publish`; nothing to publish otherwise.
6. **No publish CI job** exists yet.
7. **`publishConfig`** — unscoped name, so `access` not required; add `"publishConfig": { "provenance": true }` for provenance (needs `id-token: write`).

Not needed (YAGNI): no `bin`/CLI on npm — standalone binaries (`run_litevolve.ts` → `bun --compile`) are a separate GitHub-releases concern.

### CI publish step — gate it, don't fire on every merge

Publishing on **every** push to `main` breaks the second run — npm rejects republishing an existing version, so the job goes red until someone bumps `version`.

- **Recommended — tag/release triggered:** `on: push: tags: ['v*']` (or `release: published`). Bump + tag *is* the publish signal. No guard logic.
- **Literal "on merge to master":** add a step comparing `package.json` version to `npm view litevolve version`, `exit 0` (skip) if unchanged. Same outcome, more moving parts.

Job shape (add to `.github/workflows/ci.yml` or a new `publish.yml`; pin action SHAs to match existing style):

```yaml
publish:
  needs: [check_bun, check_node]                # don't publish red code
  if: startsWith(github.ref, 'refs/tags/v')     # or the version-diff guard
  runs-on: ubuntu-latest
  permissions: { contents: read, id-token: write }   # id-token only for provenance
  steps:
    - uses: actions/checkout@<sha>
    - uses: oven-sh/setup-bun@<sha>
      with: { bun-version-file: ".bun-version" }
    - run: bun install
      working-directory: runtimes/bun
    - run: scripts/ci_build.sh node && scripts/ci_build.sh bun   # dist is gitignored
    - run: cp README.md LICENSE.md <publish-dir>/                # gap #1
    - uses: actions/setup-node@<sha>
      with: { registry-url: 'https://registry.npmjs.org' }
    - run: npm publish --provenance
      env: { NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }} }
```

Manual prereqs (cannot be automated here): create an npm **automation token**, add repo secret `NPM_TOKEN`, reserve the `litevolve` name on npm, enable 2FA (store recovery codes).

### Assembly note (single-package path)

Unified `litevolve` must carry **both** bun `src` (for the `bun` condition) *and* node `dist` (for `default`) in one tarball. Publish from `runtimes/bun` and stage node's `dist/index.js` + `index.d.ts` into it at CI time — a small assembly step, not a bare `npm publish`.

### Ordered checklist

1. Reconcile naming: keep the three code names (`litevolve-bun`/`-node`) and fix the README, **or** add a single `litevolve` umbrella (blocks everything).
2. Fill `package.json` metadata + node `engines` + `publishConfig` (gaps 2,3,7).
3. Wire README/LICENSE copy (+ dist assembly only if the umbrella path is chosen) into a build/stage script (gaps 1,5).
4. Add the gated `publish` job (gap 6).
5. Manual: npm token → `NPM_TOKEN` secret, reserve name(s), 2FA.
6. Document `node:sqlite` experimental caveat in README (gap 4).
7. Tag `v0.0.1` (or bump) to trigger the first publish.
