# Operations

Day-to-day usage once `engineering-workflow` is installed (or run directly
from the clone).

## Initializing a project

```bash
engineering-workflow init /path/to/project
# equivalent: ./scripts/init-project.sh /path/to/project
```

Requirements: the target must already be a git repository (`git init` it
first if it isn't — this tool never creates a git repo on your behalf).

What it creates, if not already present:

- `.engineering-workflow/VERSION` — the vendored methodology version
- `.engineering-workflow/methodology/OVERVIEW.md` and `RISK-MODEL.md` —
  a vendored copy of the core methodology docs, so the project is
  actually self-contained: readable and followable on a machine where
  `engineering-workflow` was never cloned. `AGENTS.md`/`CLAUDE.md` point
  here, not at an external clone path. Copied once; never overwritten on
  re-init.
- `.engineering-workflow/workflow.config.json` — the project contract
  (edit `commands.verify`/`test`/`build` before relying on VERIFY — the
  generated file ships with `REPLACE_ME` placeholders on purpose)
- `.engineering-workflow/.gitignore` — scoped to `.engineering-workflow/`
  only, ignores `backups/` and `proposals/` (see below). Never touches the
  project's own root `.gitignore`. If this file already exists (ours or
  foreign), its content is preserved as-is and `init-project.sh` only
  appends whichever of `backups/`/`proposals/` is missing (exact-line
  match) — idempotent, never duplicates an entry already present.
- `AGENTS.md` — Codex-facing instructions
- `CLAUDE.md` — Claude Code-facing instructions
- `.engineering-workflow/HANDOFF.md` — an initial handoff note

### What's tracked in git, and what isn't

`VERSION`, `workflow.config.json`, and `HANDOFF.md` are meant to be
committed — the handoff protocol (see `OVERVIEW.md` principle 9) relies on
git as the transport between machines/agents, so `HANDOFF.md` being
disposable means its *content* is never authoritative, not that it should
be kept out of version control.

`backups/` and `proposals/` are different: they exist purely as a local
safety net for `init-project.sh` conflict handling and for
`generate-handoff.sh`'s pre-overwrite backup of the previous `HANDOFF.md`.
They have no retention/rotation policy in this version, so committing them
means unbounded growth over time. `init-project.sh` scopes a `.gitignore`
to `.engineering-workflow/` itself (never touching the project's own root
`.gitignore`) so these two directories are excluded by default — and this
is guaranteed idempotently: even if that scoped `.gitignore` already
exists (e.g. from an older `engineering-workflow` version, or hand-edited)
and is missing one or both entries, re-running `init-project.sh` adds only
what's missing, without touching any other line in the file.

### Conflicts (existing `AGENTS.md` / `CLAUDE.md`)

If `AGENTS.md` or `CLAUDE.md` already exists **and was not created by this
tool** (detected via an `engineering-workflow:managed` marker comment),
`init-project.sh`:

1. Leaves the existing file **completely untouched**.
2. Backs it up to `.engineering-workflow/backups/<file>.bak-<timestamp>`.
3. Writes the template it would have used to
   `.engineering-workflow/proposals/<file>.proposed`.
4. Reports the conflict and exits with code **2**.

There is no automatic merge in v1. Resolve by hand: diff the proposal
against the existing file and merge whatever you want manually. Re-running
`init-project.sh` afterwards will treat the file as a conflict again until
either the existing file is replaced with a marked one, or you accept
living with the conflict warning.

Exit codes for `init-project.sh`: `0` = clean (including a no-op re-run),
`1` = hard error (bad target, not a git repo, missing dependency), `2` =
completed with at least one unresolved conflict.

## Idempotency

Re-running `init-project.sh` on an already-initialized project with no
foreign files does nothing — every managed file is left byte-identical.
It is always safe to re-run.

## The project contract (`workflow.config.json`)

```jsonc
{
  "contract_version": "1",
  "project_name": "...",
  "commands": {
    "verify": "...",   // the ONLY thing that counts as VERIFY — never an agent's say-so
    "test": "...",
    "build": "..."
  },
  "risk": { "default": "MEDIUM" },
  "spec_tool": { "type": "none", "path": "openspec" },  // or "openspec"
  "handoff": { "path": ".engineering-workflow/HANDOFF.md" }
}
```

This file belongs to the project, is committed to its git history, and is
the only place project-specific commands live — nothing in
`engineering-workflow` itself hardcodes a build/test/verify command for
any language or framework.

## Handoff

`HANDOFF.md` is a **disposable** operational artifact (see
`methodology/OVERVIEW.md` principle 7) — it accelerates continuity across
sessions/agents, but it is never a source of truth. If it disagrees with
git, tests, or docs, those win.

```bash
scripts/handoff/generate-handoff.sh /path/to/project \
  --stage implement --risk MEDIUM --note "what's done, what's next"

scripts/handoff/read-handoff.sh /path/to/project
```

Each `generate-handoff.sh` call backs up the previous `HANDOFF.md` (to
`.engineering-workflow/backups/`) before overwriting it, and stamps in the
current git branch, HEAD, and `git status --short` output automatically.

## Risk gates

See `methodology/RISK-MODEL.md` for the full table. In this reference
implementation, the only gate that is mechanically enforced (as opposed to
just documented) is CRITICAL:

```bash
# refused — no durable approval given
scripts/handoff/generate-handoff.sh /path/to/project --stage handoff --risk CRITICAL --note "deploy"

# accepted — appends a durable, separate record and only then writes the handoff
scripts/handoff/generate-handoff.sh /path/to/project --stage handoff --risk CRITICAL \
  --note "deploy" --approved-by "Alvaro"
```

A CRITICAL-risk `generate-handoff.sh` call without `--approved-by` exits
`1` and writes nothing. With `--approved-by`, it appends a line to
`.engineering-workflow/APPROVALS.log` (append-only — never rotate or
truncate this file; it is the durable record, not `HANDOFF.md`) before
writing the (still disposable) `HANDOFF.md`. A commit trailer
(`Approved-by: ...`) is an acceptable complement or alternative for
projects that prefer that convention. **`--approved-by` is free text, not
an authenticated identity** — it records accountability (like a git
commit's author field), not cryptographic proof that a human approved the
change. For CRITICAL work where that distinction matters, pair it with a
real approval channel your team already trusts.

LOW/MEDIUM/HIGH review depth (self-review vs. independent review vs.
adversarial review) is a documented convention in `RISK-MODEL.md` and the
adapters, not yet mechanically enforced by a script — that is expected to
grow in a later bet as review steps get their own tooling.

## Optional capabilities

`doctor.sh` reports, without ever failing the required-dependency check
because of them:
- Claude Code / Codex CLI presence
- `codex-plugin-cc` presence (checked via
  `~/.claude/plugins/installed_plugins.json`) — if present, the Claude
  Code adapter (`CLAUDE.md`) notes that `/codex:review` and
  `/codex:adversarial-review` may be used as the independent-review step
- OpenSpec CLI presence

None of these are ever required to use the core.
