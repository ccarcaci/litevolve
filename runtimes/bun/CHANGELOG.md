# litevolve-bun

## 0.0.2

### Patch Changes

- Republish with npm provenance attestation from the automated release workflow.

  ```

  Note `publishConfig.provenance: true` is already committed in `runtimes/bun/package.json`, so provenance is a property of *how* `publish.yml` runs, not of the package contents — it's still not a code change.

  Same two `make yield_version` flaws the node run surfaced still apply: the `ls | grep -qv README.md` guard can never be false because the redirect creates the file unconditionally (use `[ -s ... ]`), and this explanation would land verbatim in the file if piped (prompt must demand changeset markdown only, empty on no-diff).
  ```

## 0.0.1

### Patch Changes

- Add @changesets/cli for release versioning.
- First release of litevolve-bun: a versioned SQLite migration runner
  usable as a library (`migrate_db`) or a CLI binary.
