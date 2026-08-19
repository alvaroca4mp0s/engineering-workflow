# engineering-workflow

A portable, versioned, agent-agnostic development methodology:

```
DISCOVER → SHAPE → SPEC → IMPLEMENT → VERIFY → REVIEW → DOCUMENT → HANDOFF / COMMIT
```

It does not depend on any specific coding agent, model, or plugin. It works
with Claude Code, Codex, a plain human in a shell, or any future agent that
can read markdown and run shell commands. See `methodology/OVERVIEW.md` for
the full lifecycle and principles, and `methodology/RISK-MODEL.md` for the
risk-based review gates.

## Status

**v0.1.0 — core only.** This is BET 1 of the implementation: the minimal
end-to-end path (`install → doctor → init-project → operate → handoff →
uninstall`). No upgrades, no `gh` integration, no deep OpenSpec scaffolding,
no per-stage skills yet. See `docs/MAINTENANCE.md` for what's deliberately
out of scope for now.

## Requirements

- `bash` (3.2+, the version macOS ships by default — nothing here needs bash 4+)
- `git`
- `jq` — **required**, not optional. macOS: `brew install jq`. Debian/Ubuntu: `apt-get install -y jq`.

Everything else (a coding agent, OpenSpec, `codex-plugin-cc`) is optional.
`doctor.sh` tells you what's present without ever failing because an
optional capability is missing.

## Quick start

```bash
git clone <this-repo> engineering-workflow
cd engineering-workflow
./scripts/install.sh
./scripts/doctor.sh
```

Then, inside any git repository you want to use the methodology on:

```bash
engineering-workflow init /path/to/your/project
# or, without installing: <this-repo>/scripts/init-project.sh /path/to/your/project
```

See `docs/INSTALL.md` for the full install/uninstall procedure and
`docs/OPERATIONS.md` for day-to-day usage (handoff, risk gates, approvals).

## Layout

```
methodology/   core lifecycle + risk model — agnostic, no agent mentioned
contract/      the workflow.config.json schema/example a project provides
adapters/      per-agent glue (claude-code, codex, generic fallback)
scripts/       deterministic bash tooling: install, doctor, init, handoff
templates/     HANDOFF.md template
tests/         self-contained bash tests, run via tests/run.sh
docs/          INSTALL / OPERATIONS / MAINTENANCE / PORTABILITY / TROUBLESHOOTING
```

## Design constraints (why it looks like this)

- Durable state lives in the target project's repository, never in an
  agent's memory or in this tool's own state.
- `HANDOFF.md` is disposable. Durable approvals (e.g. for CRITICAL-risk
  work) are written to a separate, append-only file
  (`.engineering-workflow/APPROVALS.log`), never only to `HANDOFF.md`.
- Nothing here merges into a pre-existing `AGENTS.md`/`CLAUDE.md`
  automatically. If one already exists and isn't ours, `init-project.sh`
  backs it up, writes a separate proposal, and stops with an explicit
  conflict (exit code 2) — see `docs/OPERATIONS.md`.
- Every project vendors its own copy of the contract
  (`.engineering-workflow/`), so it stays usable even on a machine where
  this repo isn't cloned.
