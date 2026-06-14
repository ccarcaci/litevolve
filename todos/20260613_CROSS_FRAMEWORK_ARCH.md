# Cross-Runtime Architecture: Bun, Node.js, Deno

_Date: 2026-06-13_

## Goal

Publish `litevolve` on npm so it works as a library on Bun, Node.js, and Deno.

---

## Hard Blocker

`src/migrate.ts` imports `Database` from `bun:sqlite` — Bun-only, no shim exists for Node or Deno. The code cannot be made cross-runtime without changes. Other Bun-isms:
- `Bun.argv` in `run_litevolve.ts` — trivial swap for `process.argv`.
- `node:fs`, `node:path`, `node:util` — fine on all runtimes; they already use the `node:` prefix.

---

## Options

### Option A — Bun-only publish (cheapest, narrowest)

Keep the code as-is. Set `"engines": { "bun": ">=1.0" }`. Document it as Bun-only. Consumers on Node/Deno get an immediate import error on `bun:sqlite`. Does not satisfy the cross-runtime requirement.

### Option B — Runtime adapter (chosen)

Introduce a thin SQLite adapter interface. Three implementations, one per runtime.

| Runtime | Backend | Class |
|---|---|---|
| Bun | `bun:sqlite` | `Database` |
| Node ≥ 22.5 | `node:sqlite` | `DatabaseSync` |
| Deno | `npm:better-sqlite3` (Node-API) | `Database` |

**API surface used in `migrate.ts`** (the adapter only needs to cover this):
- `new Database(path)`
- `db.run(sql)`
- `db.query(sql).get(...params)` → single row or null
- `db.query(sql).run(...params)`

**API compatibility notes:**
- `bun:sqlite` and `better-sqlite3` are call-compatible by design (Bun docs: _"Credit to better-sqlite3 and its contributors for inspiring the API"_).
- `node:sqlite` uses `DatabaseSync` and `prepare(sql)` — close but not identical; `db.query(...)` calls need translating to `db.prepare(...).get/all/run`.
- `node:sqlite` is **Stability 1.2 — Release candidate** as of Node v25.7.0. Available since v22.5.0.

---

## Industry Pattern

Libraries that support all three runtimes follow one of two approaches:

- **Zero native deps** (Hono, Zod): use only Web Standard APIs. No SQLite means no problem. Not applicable here.
- **Accept the db object from the caller** (Drizzle ORM): the library defines a thin adapter interface; the caller brings their own driver (`bun:sqlite`, `node:sqlite`, `better-sqlite3`). No native dep inside the library. Drizzle uses `peerDependenciesMeta: { optional: true }` for each driver — users install only the one they need.

Drizzle's model is the right reference for litevolve.

---

## Chosen Strategy: Monorepo with Runtime Packages

```
litevolve/                     ← monorepo root (not published)
  package.json                 ← workspaces config
  packages/
    core/                      ← shared logic: migrate.ts, migration_error.ts
      package.json             ← private, "name": "litevolve-core"
      src/                     ← pure TypeScript, no runtime-specific imports
    bun/                       ← "name": "litevolve-bun"
      package.json             ← dependencies: {} (bun:sqlite is built-in)
      src/                     ← bun:sqlite adapter + re-exports core
    node/                      ← "name": "litevolve-node"
      package.json             ← dependencies: {} (node:sqlite built-in since v22.5)
      src/                     ← node:sqlite adapter + re-exports core
    deno/                      ← "name": "litevolve-deno"
      package.json             ← dependencies: { "better-sqlite3": ">=11.0.0" }
      src/                     ← better-sqlite3 adapter + re-exports core
```

Root `package.json`:
```json
{
  "name": "litevolve-monorepo",
  "private": true,
  "workspaces": ["packages/*"]
}
```

### What each package produces

| Package | npm library | Docker image | Executable |
|---|---|---|---|
| `litevolve-bun` | Yes | Yes | Yes (brew, GoReleaser, eopkg) |
| `litevolve-node` | Yes | — | — |
| `litevolve-deno` | Yes | — | — |

### Why three packages, not conditional exports on one

npm dependency installation is not runtime-aware — there is no `runtime` field, only `os` and `cpu`. Putting `better-sqlite3` in any shared `dependencies` or `optionalDependencies` field installs a native addon on Bun and Node consumers who will never use it. Three packages give each runtime an isolated `package.json` with only the deps it actually needs.

### `core` package

Contains `migrate.ts` and `migration_error.ts` with all runtime-specific SQLite calls removed. It operates against a `db_adapter` interface:

```ts
type db_adapter = {
  run(sql: string): void
  query<T>(sql: string): { get(...params: unknown[]): T | null; run(...params: unknown[]): void }
}
```

The `core` package is `private` — never published to npm. Each runtime package depends on it via `workspace:*` and bundles it at build time.

### API change

`migrate_db` currently accepts `db_path: string` and opens the database internally. With the adapter model the signature becomes:

```ts
migrate_db(apply_version: number, migrations_path: string, db: db_adapter): void
```

The caller opens and configures the database. This mirrors Drizzle's model and eliminates all runtime-specific code from `core`.

**What changes in the codebase:**
1. New adapter interface file (`db_adapter.ts`) + three implementation files.
2. `migrate.ts` imports from the adapter instead of `bun:sqlite` directly.
3. `migrate_db` return type changes from `Database` (bun:sqlite) to the adapter type — a public API break, acceptable at v0.0.1.
4. `Bun.argv` → `process.argv` in `run_litevolve.ts`.
5. Build step added: `bun build` emitting `dist/*.js` + `tsc --emitDeclarationOnly` for `.d.ts`.

---

## package.json per runtime package

### Runtime condition resolution order (from official docs)

| Condition | Bun | Node.js | Deno (ESM) |
|---|---|---|---|
| `"bun"` | first | ignored | ignored |
| `"deno"` | ignored | ignored | first |
| `"node"` | fallback | matched | fallback |
| `"import"` | fallback | matched | fallback |
| `"default"` | last | last | last |

Bun full order: `["bun", "node", "require", "import", "default"]`
Deno ESM order: `["deno", "node", "import", "module-sync", "default"]`
Node.js: ignores `"bun"` and `"deno"` entirely.

Each package `package.json` is simple — no conditional exports needed since each package is already runtime-specific:

```json
{
  "name": "litevolve-bun",
  "version": "0.0.1",
  "type": "module",
  "exports": {
    ".": {
      "bun":    { "types": "./src/index.ts", "default": "./src/index.ts" },
      "default": "./dist/index.js"
    }
  },
  "types": "./dist/index.d.ts",
  "files": ["dist", "src"],
  "engines": { "bun": ">=1.0" }
}
```

Bun docs (verbatim): _"If your library is written in TypeScript, you can publish your (un-transpiled!) TypeScript files to npm directly. If you specify your package's `*.ts` entrypoint in the `"bun"` condition, Bun will directly import and execute your TypeScript source files."_

The `litevolve-node` and `litevolve-deno` packages ship only `dist/` (compiled JS + `.d.ts`). `engines.node >= 22.5` for `litevolve-node` (`node:sqlite` added in v22.5.0, Stability 1.2 RC as of v25.7.0).

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
- Pin `better-sqlite3` to a tested minor version (it is a runtime dep for the Deno build).

---

## Open Items

1. **Confirm Deno + `node:sqlite`** — if supported, `litevolve-deno` shares the Node adapter and drops `better-sqlite3`.
2. **`migrate_db` return type** — `void` or return the `db_adapter`? (callers may want to reuse the connection).
3. **Versioning discipline** — all three packages must be published together at the same version. Set up coordinated CI publish (e.g., Changesets).
4. **CLI / executable scope** — `litevolve-bun` produces the Bun-compiled binary distributed via brew, GoReleaser, eopkg. Confirm those pipelines are out of scope for the npm library packages.
5. **Verify Bun + `node:sqlite`** — if Bun already supports `node:sqlite`, the Bun and Node adapter implementations could share one file.
6. **Verify Deno + `npm:better-sqlite3`** — confirm it works without extra `--allow-ffi` flags in target environments.

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
