# litevolve-node

## 0.0.2

### Patch Changes

- Republish with npm provenance attestation from the automated release workflow.

  ```

  Two flaws in `make yield_version` this exposes:

  1. **The guard can never be false.** `claude --print ... > $(NODE_CHANGESET_DIR)/curr_changeset.md` creates the file unconditionally, so `ls $(NODE_CHANGESET_DIR)/*.md | grep -qv README.md` always matches. "no changeset, skipping" is dead code. Fix: `-s` test instead — `if [ -s $(NODE_CHANGESET_DIR)/curr_changeset.md ]; then` — and have this prompt emit nothing when there's no diff.
  2. **My stdout becomes the file verbatim.** Everything above — including this explanation — would land in `curr_changeset.md` if you piped it. The prompt needs to say "output only the changeset markdown, nothing else, empty output if no changes."
  ```

## 0.0.1

### Patch Changes

- Add @changesets/cli for release versioning.
- First release of litevolve-node: a versioned SQLite migration runner
  usable as a library (`migrate_db`) or a CLI binary.
