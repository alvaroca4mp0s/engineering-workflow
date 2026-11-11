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
`1` = hard error (bad target, not a git repo, missing dependency, invalid contract), `2` =
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

`init-project.sh` (for an existing contract) and `generate-handoff.sh`
validate the version-1 structure with jq and exit `1` on invalid input,
without overwriting the contract or updating the handoff/approval record.
The input must be exactly one JSON object with `contract_version: "1"`;
all fields shown above are required. `project_name`, each command, and
both paths must be non-whitespace strings. `risk.default` must be
`LOW`, `MEDIUM`, `HIGH`, or `CRITICAL`; `spec_tool.type` must be `none` or
`openspec`. Unknown keys are allowed for project extensions. This checks
structure, not command correctness, path safety, or completed verification;
it never executes commands. Template placeholder commands remain valid
structurally and must still be replaced by the project.

## Running VERIFY and retaining evidence

```bash
engineering-workflow verify /path/to/project
# equivalent: ./scripts/verify-project.sh /path/to/project
# target defaults to the current directory
```

The runner validates the Git working tree and version-1 contract, rejects
`commands.verify` containing `REPLACE_ME` or NUL bytes, then executes the
exact declared command using `bash -c` in the target directory. **Only run
trusted contracts**: this executes arbitrary shell code with your privileges,
not a sandbox. Output streams directly to the terminal; the runner captures
the actual exit code, not an agent's interpretation of the output.

The latest result replaces `.engineering-workflow/VERIFY.json` via a
same-directory temporary file and atomic rename:

```json
{
  "schema_version": "1",
  "verified_at": "2026-11-11T12:00:00Z",
  "git_head": "<full commit hash, or no-commits>",
  "git_tree_dirty": false,
  "command": "<exact commands.verify string>",
  "exit_code": 0,
  "status": "PASS"
}
```

`status` is `PASS` exactly when `exit_code` is zero, otherwise `FAIL`.
The script returns the command's exit code, including failures such as `7`.
Preflight or evidence-persistence errors return `1`; they never publish a
new PASS. A previous result remains untouched on preflight or rename errors.
Consult the runner's exit code as well as the file; old evidence alone
cannot demonstrate that the latest attempted run succeeded.

HEAD and dirty state are sampled after the command, before creating the
temporary file. `git_tree_dirty` includes tracked and individual untracked
changes except `.engineering-workflow/VERIFY.json` and
`.engineering-workflow/HANDOFF.md`; normal Git ignore rules still apply.
If the command itself moves HEAD, the runner conservatively sets dirty to
true. PASS may therefore legitimately record a dirty working tree: it means
the command succeeded, not that a clean committed snapshot was verified.

The default ignore template does **not** ignore `VERIFY.json`; it can be
transported in Git if desired. Existing project ignore rules are not
rewritten: a project's broader rules may ignore it, but local handoff
checks still read it directly. This is a mutable latest-result snapshot,
not an append-only history, signed attestation, output archive, or evidence
of independent review. Do not run concurrent verifications on the same
project: atomic replacement prevents partial JSON, not last-writer races.

## Handoff

`HANDOFF.md` is a **disposable** operational artifact (see
`methodology/OVERVIEW.md` principle 7) — it accelerates continuity across
sessions/agents, but it is never a source of truth. If it disagrees with
git, tests, or docs, those win.

```bash
scripts/handoff/generate-handoff.sh /path/to/project \
  --stage implement --risk MEDIUM --note "what's done, what's next"

scripts/handoff/read-handoff.sh /path/to/project

# Same operations through the dispatcher:
engineering-workflow handoff generate /path/to/project --stage review
engineering-workflow handoff read /path/to/project
```

Each `generate-handoff.sh` call backs up the previous `HANDOFF.md` (to
`.engineering-workflow/backups/`) before overwriting it, and stamps in the
current git branch, HEAD, and `git status --short` output automatically.

Omitting `--risk` uses the validated contract's `risk.default`; an explicit
`--risk` overrides it (an explicit empty value is invalid). A missing or
invalid contract is an error even with an override. `--stage` accepts
`discover`, `shape`, `spec`, `implement`, `verify`, `review`, `document`,
`handoff`, and `commit`, plus the compatibility values `init` and
`unspecified` (the default). Case is normalized to lowercase. Arbitrary
free-form stages are now rejected intentionally; stages are labels, not a
state machine or proof of a completed gate. The lifecycle is unchanged.
The scripts continue to use `.engineering-workflow/HANDOFF.md`; this change
does not introduce custom-path routing via `handoff.path`.

`read-handoff.sh` compares the recorded HEAD with current Git HEAD and
warns on stderr if they differ (including an unresolvable recorded commit).
It still prints the handoff and exits successfully. Short and full hashes
of the same commit compare equal. Legacy handoffs without HEAD metadata
remain readable without a comparison; dirty working trees alone are not
detected by this advisory check.

### Evidence checks in handoffs

For `--stage verify`, `review`, `document`, `handoff`, or `commit`, generation
warns on stderr if evidence is absent, malformed, FAIL, stale by HEAD, or
records a dirty tree. This remains advisory to preserve existing workflows.
The reader warns for those problems when evidence exists; missing evidence
alone does not warn in the reader (legacy compatibility). Neither operation
executes VERIFY automatically.

```bash
engineering-workflow handoff generate /path/to/project \
  --stage review --require-verify --note "ready for independent QA"
```

`--require-verify` opts into a hard gate at **any** stage: the evidence must
be structurally valid, PASS, for current HEAD and record `git_tree_dirty:
false`. The current tree must also be clean under the same exclusions, so
edits after a clean run cannot bypass the gate. Failure exits `1` before
approval-log append, backup, or handoff write. Schema/status validation
rejects inconsistent results (for example PASS with a nonzero exit code).

These checks do not authenticate the file, fingerprint the tree contents,
compare command histories, or enforce review. Manual evidence editing and
changes confined to ignored paths cannot be detected. Rerun VERIFY after
changing code/configuration; commit changes and rerun if clean evidence is
needed. Advisory mode does not inspect current dirty state independently
of the recorded flag; strict mode does.

## Risk gates

See `methodology/RISK-MODEL.md` for the full table. In this reference
implementation, CRITICAL approval is enforced on every CRITICAL handoff;
VERIFY evidence is enforced only when `--require-verify` is requested:

```bash
# refused — no durable approval given
scripts/handoff/generate-handoff.sh /path/to/project --stage handoff --risk CRITICAL --note "deploy"

# accepted — appends a durable, separate record and only then writes the handoff
scripts/handoff/generate-handoff.sh /path/to/project --stage handoff --risk CRITICAL \
  --note "deploy" --approved-by "Alvaro"
```

A CRITICAL-risk `generate-handoff.sh` call without `--approved-by` exits
`1` and writes nothing. Explicit empty or whitespace-only `--approved-by`
values are also rejected, at every risk level. All rejected input is checked
before backups, handoff writes, or approval appends. With a nonblank
`--approved-by`, it appends a line to
`.engineering-workflow/APPROVALS.log` (append-only — never rotate or
truncate this file; it is the durable record, not `HANDOFF.md`) before
writing the (still disposable) `HANDOFF.md`. A commit trailer
(`Approved-by: ...`) is an acceptable complement or alternative for
projects that prefer that convention. **`--approved-by` is free text, not
an authenticated identity** — it records accountability (like a git
commit's author field), not cryptographic proof that a human approved the
change. For CRITICAL work where that distinction matters, pair it with a
real approval channel your team already trusts.

The approval log retains its existing seven pipe-separated fields. CR, LF,
and `|` in free-text values are replaced by spaces before append, so callers
cannot inject extra records or fields. This is intentionally lossy display
sanitization, not an escaping/round-trip format. Existing log records are
not rewritten or retroactively sanitized.

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
