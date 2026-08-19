# Maintenance

## Versioning

`VERSION` at the repo root is the single source of truth for this clone's
version (semver). `init-project.sh` copies it into each project's
`.engineering-workflow/VERSION` at init time ("vendoring" — see
`docs/PORTABILITY.md`).

## Upgrades are explicit (v1 has no automated upgrade path)

`doctor.sh` and `init-project.sh` will tell you when a project's vendored
version differs from the clone's `VERSION`, but **nothing upgrades a
project automatically**. As of v0.1.0 there is no `upgrade` subcommand at
all — bumping a project to a newer methodology version is a manual
operation: re-run `init-project.sh` (it will treat already-managed files
as up to date and only report the version mismatch), and manually review
`methodology/`, `contract/`, and the adapter templates for changes you
want to pull in. An explicit, scripted upgrade path is planned for a later
bet — do not assume one exists yet.

## Running the tests

```bash
./tests/run.sh
```

Self-contained bash, no `bats-core` or other test-framework dependency.
Every test creates its own throwaway `$HOME` and, where needed, its own
throwaway git project (via `tests/lib/fixtures.sh`) — the suite never
touches your real `~/.local/bin`, `~/.config`, or any real project.

Add a new test by dropping a `tests/test_*.sh` file that sources
`tests/lib/assert.sh` and `tests/lib/fixtures.sh`, sets its own `$HOME`,
and exits non-zero on failure — `tests/run.sh` picks it up automatically.

## What's deliberately out of scope in v0.1.0 (BET 1)

Per the approved design, do not add these without a deliberate new bet:

- `gh`/GitHub integration (PR creation, issue linking)
- Automated/complex upgrade tooling
- Global hooks
- Deep OpenSpec scaffolding (only `spec_tool.type` is recognized so far)
- Per-stage Claude Code skills (only `CLAUDE.md`/`AGENTS.md` templates exist)
- Mechanical enforcement of LOW/MEDIUM/HIGH review depth (only CRITICAL's
  approval gate is scripted so far)
- A JSON-schema validator for `workflow.config.json` (currently only
  checked for being valid JSON, not for required fields)

## Compatibility constraints to preserve

- All scripts under `scripts/` and `bin/` must remain bash 3.2-compatible
  (no associative arrays, no `${var,,}`, no `mapfile`) — macOS ships 3.2 by
  default and this tool must not require Homebrew bash.
- `jq` is a hard dependency by design (see the approved design decision in
  project history) — do not add a grep/sed/awk JSON-parsing fallback.
- No script may write outside of: `$HOME/.local/bin`,
  `$HOME/.config/engineering-workflow`, or the target project's own
  `.engineering-workflow/`/`AGENTS.md`/`CLAUDE.md`. This is what keeps
  `install.sh`/`init-project.sh`/`uninstall.sh` safe to run without a
  sandbox.
