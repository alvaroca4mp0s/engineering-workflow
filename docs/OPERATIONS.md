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
- `.engineering-workflow/workflow.config.json` — the project contract
  (edit `commands.verify`/`test`/`build` before relying on VERIFY — the
  generated file ships with `REPLACE_ME` placeholders on purpose)
- `AGENTS.md` — Codex-facing instructions
- `CLAUDE.md` — Claude Code-facing instructions
- `.engineering-workflow/HANDOFF.md` — an initial handoff note

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
projects that prefer that convention.

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
