# engineering-workflow Handbook

Version covered: **v0.1.0** (BET 1 — the minimal portable core). This
handbook describes only what exists and has been tested in this version.
Where something is a documented convention rather than a scripted,
enforced behavior, that distinction is called out explicitly — do not
assume a convention is mechanically enforced unless this handbook says so.

---

# PART I — LEARN

## What is engineering-workflow

`engineering-workflow` is a portable, versioned, agent-agnostic
development methodology, plus a small amount of deterministic bash
tooling that operationalizes it. It is not a framework your code depends
on, and it is not an AI agent itself — it's a convention for how
DISCOVER-through-HANDOFF work gets done, backed by a handful of scripts
that create/check the durable artifacts that convention relies on.

The core idea (see `methodology/OVERVIEW.md` principle 1): **durable
state lives in the project's git repository, not in an agent's memory.**
Everything else in this handbook exists to make that true in practice —
so that a different agent, a different person, or the same agent days
later, can pick up exactly where things were left off by reading the
repository, not by remembering a conversation.

## Relationship to Claude Code, Codex, codex-plugin-cc, OpenSpec, Git, and tests

None of these are dependencies of the methodology itself. Only `git`,
`bash` (3.2+), and `jq` are required to use the core (`install.sh`,
`doctor.sh`, `init-project.sh`, the handoff scripts). Everything else is
an optional capability that `doctor.sh` detects and reports on, never
requires:

| Thing | Role | Required? |
|---|---|---|
| **Git** | source of truth for change history; also the transport for `HANDOFF.md` between machines/agents | yes |
| **A project's own test/verify command** | the only thing that counts as VERIFY | yes (declared per-project in `workflow.config.json`) |
| **Claude Code** | one possible agent to do the work; gets a `CLAUDE.md` adapter | no |
| **Codex CLI** | another possible agent; gets an `AGENTS.md` adapter | no |
| **codex-plugin-cc** | a Claude Code plugin that, if installed, offers `/codex:review`, `/codex:adversarial-review`, `/codex:rescue`, `/codex:transfer` as concrete review/handoff *enhancers* | no |
| **OpenSpec** | one possible way to represent SPEC; a project's `workflow.config.json` can name it via `spec_tool.type: "openspec"` | no |

If you strip away Claude Code, Codex, codex-plugin-cc, and OpenSpec
entirely, a project initialized with `engineering-workflow` still works:
a human with a shell can follow `adapters/generic/CLI-FALLBACK.md`,
`methodology/OVERVIEW.md`, and `methodology/RISK-MODEL.md` directly.

## The lifecycle

```
DISCOVER → SHAPE → SPEC → IMPLEMENT → VERIFY → REVIEW → DOCUMENT → HANDOFF / COMMIT
```

- **DISCOVER** — understand the current state before proposing changes.
- **SHAPE** — turn an ambiguous request into a bounded proposal: what's in
  scope, what's out, what trade-offs are being made.
- **SPEC** — write down what will change and why, durably enough to
  survive a context reset. OpenSpec (or plain prose in an issue/ADR) can
  represent this; nothing requires it.
- **IMPLEMENT** — make the change.
- **VERIFY** — run the project's own declared command and check its exit
  code. Never an agent's own assertion.
- **REVIEW** — assess the change at a depth proportional to its risk.
- **DOCUMENT** — update durable docs for anything that outlives this
  change (README, ADRs, operational docs) — never for the disposable
  `HANDOFF.md`.
- **HANDOFF / COMMIT** — persist the change in git; if work is
  incomplete, leave (and commit) an updated `HANDOFF.md` for whoever
  continues.

Full text and all 14 principles: `methodology/OVERVIEW.md`.

## VERIFY vs. REVIEW vs. ADVERSARIAL REVIEW

These three are easy to conflate. They are not the same thing:

- **VERIFY** is deterministic and binary. It means: run the command in
  `workflow.config.json`'s `commands.verify`, and look at its exit code.
  There is no judgment involved. A change that fails VERIFY is not done,
  full stop.
- **REVIEW** is qualitative. Someone (or some agent) reads the change and
  judges correctness, design, and fit — at a depth set by the risk level
  (see below). In this reference implementation, `/codex:review` (when
  codex-plugin-cc is installed) is one concrete way to get a review from
  an agent independent of the one that implemented the change.
- **ADVERSARIAL REVIEW** is a *stricter, challenge-oriented* pass. It
  doesn't just look for defects — it questions the chosen approach,
  design trade-offs, and assumptions, and actively looks for things like
  hidden lock-in, unsafe defaults, and scope creep. `/codex:adversarial-review`
  (when codex-plugin-cc is installed) is the concrete mechanism used in
  this repository's own BET 1 closure. CRITICAL-risk work requires this
  level, not plain REVIEW.

Neither REVIEW nor ADVERSARIAL REVIEW is mechanically enforced by any
script in v0.1 — there is no gate that blocks a commit if a review didn't
happen. It is a process discipline the methodology asks you (human or
agent) to follow, backed by the one gate that *is* scripted: CRITICAL-risk
work cannot get a handoff written without `--approved-by` (see Risk
levels, below).

## Risk levels

| Level | Examples | Required gates |
|---|---|---|
| **LOW** | Docs, comments, trivial/cosmetic changes | `verify` |
| **MEDIUM** | Ordinary application code, no security/data/infra boundary crossed | `verify` + review |
| **HIGH** | Persistence/schema changes, security-relevant code, infrastructure | `verify` + independent review |
| **CRITICAL** | Production data, privilege escalation, production deployment, recovery/rollback | `verify` + independent adversarial review + **durable human approval** |

Full table and rules: `methodology/RISK-MODEL.md`. The only mechanically
enforced part of this table in v0.1 is the CRITICAL gate:
`scripts/handoff/generate-handoff.sh --risk CRITICAL` refuses to run
(exit `1`, writes nothing) unless `--approved-by "<name>"` is given, and
when it is given, the approval is appended to a durable, append-only
`.engineering-workflow/APPROVALS.log` — never recorded only in the
disposable `HANDOFF.md`. LOW/MEDIUM/HIGH review depth is a convention, not
a script-enforced gate, in this version.

**Be precise about what this gate actually proves.** `--approved-by` is
free text the caller supplies — nothing authenticates it. It is durable
accountability (like a git commit's author field), not cryptographic
identity proof; an agent could type a plausible name just as easily as a
human could. For CRITICAL work where that distinction actually matters,
pair it with a real approval channel your organization already trusts
(a protected PR review, a signed commit). v0.1 does not provide, and does
not claim to provide, identity verification.

## Handling findings

Every finding from a review gets exactly one outcome:

- **ACCEPT** → reopen IMPLEMENT for that finding only → fix → VERIFY with
  real evidence → RE-REVIEW the fix before moving on.
- **REJECT** → document the rationale (commit message, ADR, or the
  record of the conversation) instead of fixing it. Never just ignore a
  finding silently.
- **HUMAN DECISION** → stop and ask. Don't decide unilaterally when the
  right call depends on judgment only a human should make.

An ACCEPTED finding left unresolved means the work is not done, no matter
what else is finished — see the Definition of Done in
`methodology/OVERVIEW.md`.

---

# PART II — OPERATE

## Preparing a new machine

Hard requirements for `engineering-workflow` itself: `git`, `bash` 3.2+
(already present on macOS and virtually every Linux distribution), and
`jq`.

```bash
# macOS
brew install jq
# Debian/Ubuntu
sudo apt-get update && sudo apt-get install -y jq git
```

Everything below this point is optional — install only what you intend
to use.

## Installing Claude Code

Follow Anthropic's current official installation instructions for your
OS. Once installed, confirm it's on `PATH`:

```bash
claude --version
```

## Installing Codex

The Codex CLI is distributed as an npm package:

```bash
npm install -g @openai/codex
codex login
```

Confirm it's working:

```bash
codex --version
```

## Installing codex-plugin-cc

`codex-plugin-cc` is a Claude Code plugin (from `openai/codex-plugin-cc`),
not a standalone binary. Install it through Claude Code's own plugin
mechanism (from inside a Claude Code session):

```
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
/reload-plugins
```

Then check readiness:

```
/codex:setup
```

This reports whether Node, Codex, and Codex authentication are all in
place, and offers to run `npm install -g @openai/codex` for you if Codex
itself isn't installed yet.

## Keeping the review gate disabled

codex-plugin-cc ships an *optional* stop-time review gate: a hook that,
if enabled, automatically runs a Codex review at the end of every Claude
Code turn that made edits, and can block the turn from ending if it finds
something. This is separate from `/codex:review`, which you invoke
explicitly.

`engineering-workflow`'s own REVIEW step is something you invoke
deliberately, at a point you choose (see Risk levels) — not an automatic
per-turn gate. **The recommended posture is to leave this gate disabled**
(it is disabled by default) so it doesn't interfere with the explicit
VERIFY → REVIEW → RE-REVIEW cycle this methodology already asks for.
Check and control it with:

```
/codex:setup                       # reports reviewGateEnabled: true/false
/codex:setup --disable-review-gate # make sure it stays off
/codex:setup --enable-review-gate  # only if you deliberately want the automatic gate
```

## Installing OpenSpec

Optional. Only needed if a project's `workflow.config.json` sets
`spec_tool.type` to `"openspec"`.

```bash
npm install -g @fission-ai/openspec
openspec --version
```

`engineering-workflow` v0.1 does not orchestrate OpenSpec itself — it only
recognizes the `spec_tool.type` field in the contract and mentions
`openspec/` as a place to look, in the adapters and
`adapters/generic/CLI-FALLBACK.md`. Running `openspec init`, creating
changes, and reading specs are entirely manual, independent of this tool.

## Installing engineering-workflow

```bash
git clone <this-repo> engineering-workflow
cd engineering-workflow
./scripts/install.sh
./scripts/doctor.sh
```

`install.sh` links `~/.local/bin/engineering-workflow` to this clone's
`bin/engineering-workflow` dispatcher and records the clone's path and
version in `~/.config/engineering-workflow/install.json`. It refuses (exit
`1`) rather than silently overwrite anything already at that path that
isn't recognizably its own — a real file/directory, or a symlink pointing
somewhere that isn't some clone's `bin/engineering-workflow`. `doctor.sh`
reports required-dependency status plus every optional capability above,
without ever failing the exit code because an optional one is missing.

## Starting a new project

Inside any existing git repository:

```bash
engineering-workflow init /path/to/project
# equivalent, without installing: <clone>/scripts/init-project.sh /path/to/project
```

The target must already be a git repo (`git init` it first if not — this
tool never creates one for you). This creates `AGENTS.md`, `CLAUDE.md`,
and `.engineering-workflow/{VERSION,methodology/OVERVIEW.md,methodology/RISK-MODEL.md,workflow.config.json,.gitignore,HANDOFF.md}`.
The methodology docs are a real vendored copy, not a reference back to the
clone — `AGENTS.md`/`CLAUDE.md` point at them locally, so the project
stays followable even where `engineering-workflow` was never installed.
Edit `commands.verify`/`test`/`build` in `workflow.config.json` — it ships
with `REPLACE_ME` placeholders, on purpose, so VERIFY is never silently a
no-op.

If `AGENTS.md` or `CLAUDE.md` already exists and wasn't created by this
tool, nothing is overwritten: the existing file is backed up, a proposal
is written next to it, and `init-project.sh` exits `2` to signal the
conflict needs manual resolution. Full detail: `docs/OPERATIONS.md`.

## Resuming an existing project

Read, in this order (this is literally what the generated `AGENTS.md`/
`CLAUDE.md` tell any agent to do):

1. `.engineering-workflow/workflow.config.json` — the contract.
2. `openspec/`, if `spec_tool.type` is `openspec`.
3. `git log` / `git status`.
4. Actually run `commands.verify` — don't assume prior test results still
   hold.
5. `.engineering-workflow/HANDOFF.md`, if present — disposable, but a
   useful accelerant. If it disagrees with git/tests/docs, they win.

## Using OpenSpec

Manual, v0.1 does not wire this up beyond the contract field. Typical
flow: `openspec init` in the project, author changes under `openspec/`,
reference `spec_tool.type: "openspec"` in `workflow.config.json` so
adapters point agents at the `openspec/` directory during DISCOVER/SPEC.

## Using `/codex:review`

Runs a Codex review over the current working-tree diff (or a branch diff
with `--base <ref>`). Review-only — it never applies fixes. Use it as the
REVIEW step for MEDIUM/HIGH-risk work when codex-plugin-cc is available.
Supports `--wait` (foreground) / `--background`; without either, Claude
Code estimates the diff size and asks which to use.

## Using `/codex:adversarial-review`

Same underlying mechanism, but frames the review as a challenge to the
implementation's design choices, trade-offs, and assumptions — not just a
stricter defect scan. Use it for HIGH/CRITICAL-risk work, and for closing
out a significant unit of work (as this repository's own BET 1 closure
did). Accepts free-form focus text describing what to challenge.

## Using `/codex:rescue`

Delegates investigation or an explicit fix/follow-up task to a Codex
subagent, when you want a second implementation or diagnosis pass, or
when Claude Code is stuck. Supports `--wait`/`--background` and
`--resume`/`--fresh`.

## Using `/codex:transfer`

Converts the *current Claude Code session* into a resumable Codex thread,
by parsing this session's own transcript. This is a Claude-Code-specific
accelerant for the HANDOFF stage — it only exists, and only works, inside
a Claude Code session with codex-plugin-cc installed. It is never the
primary handoff mechanism (see below); when it's unavailable, nothing is
lost, because the file-based handoff always works.

## Continuing when an agent hits its limit

This is the HANDOFF protocol, and it works with or without any specific
agent or plugin:

```bash
scripts/handoff/generate-handoff.sh /path/to/project \
  --stage implement \
  --risk MEDIUM \
  --note "what's done, what's next, anything a fresh agent needs to know"
```

`--stage` is free-form text, not validated — using one of the lifecycle
names (`discover`, `shape`, `spec`, `implement`, `verify`, `review`,
`document`, `handoff`) is a convention, not an enforced enum. `--risk`, in
contrast, *is* validated and must be exactly one of `LOW`/`MEDIUM`/`HIGH`/`CRITICAL`.

This stamps in the current git branch/HEAD/status automatically and backs
up the previous `HANDOFF.md`. The next agent — same one in a new session,
or a different one entirely — reads it with:

```bash
scripts/handoff/read-handoff.sh /path/to/project
```

and, per "Resuming an existing project" above, treats it as an
accelerant, not authority. When Claude Code + codex-plugin-cc are both
available, `/codex:transfer` can additionally hand the *conversation
itself* to Codex — but the file-based handoff above is what makes the
protocol work everywhere else too.

## Closing a task

1. VERIFY: run `commands.verify` for real, check the exit code.
2. REVIEW at the depth the risk level demands; resolve every finding
   (ACCEPT/REJECT/HUMAN DECISION — see Part I).
3. DOCUMENT anything durable that changed.
4. Update (or clear) `HANDOFF.md`; commit everything, including the
   contract/docs changes, to git.

This exact sequence is how BET 1 of this repository was closed — see the
closure report in this repository's git history for a worked example.

---

# PART III — MAINTAIN

## `doctor`

```bash
engineering-workflow doctor
# or: ./scripts/doctor.sh
```

Reports required dependencies (`git`, `jq`, `bash`) with a hard exit `1`
if any are missing; install state (does `~/.config/engineering-workflow/install.json`
match this clone, does the version match); and every optional capability
(Claude Code, Codex CLI, codex-plugin-cc, OpenSpec) with version info when
detected. Exit code is `0` whenever required dependencies are present,
regardless of optional gaps.

## Upgrade (explicit, v0.1 has no automation)

There is no `upgrade` subcommand. `doctor.sh` and `init-project.sh` will
tell you when a project's vendored `.engineering-workflow/VERSION` differs
from the clone's `VERSION`, but nothing bumps it for you. To pull in a
newer methodology version: re-run `init-project.sh` (already-managed
files are left alone; only the version mismatch is reported), then
manually review `methodology/`, `contract/`, and the adapter templates
for what you want to adopt. This is deliberate — see
`docs/MAINTENANCE.md`.

## Portability

Designed for macOS, Ubuntu Desktop, and Ubuntu Server. Hard dependencies
are `git`, `bash` 3.2+, and `jq` only — no Node/Python/Ruby required by
the core tooling. All scripts avoid bash-4-only features (no associative
arrays, no `${var,,}`, no `mapfile`) because macOS ships bash 3.2 by
default. **As of this version, only macOS has actually been exercised.**
Ubuntu compatibility is a design constraint the scripts were written
against, not yet an empirically verified fact — see
`docs/PORTABILITY.md`.

## Troubleshooting

Common issues and their resolutions: `docs/TROUBLESHOOTING.md` — covers
missing `jq`, `PATH` issues, `init-project.sh` conflicts, the CRITICAL
handoff gate, install-state drift, and the install/uninstall refusal
behavior described next.

## Uninstall

```bash
engineering-workflow uninstall
# or: ./scripts/uninstall.sh
```

Removes the `~/.local/bin/engineering-workflow` symlink and
`~/.config/engineering-workflow/install.json` — nothing else. It never
deletes this repo clone, never touches any project's
`.engineering-workflow/` directory, and never deletes anything at the
install path that isn't recognizably its own symlink (a foreign file, or
a foreign symlink pointing elsewhere, is left in place with a warning,
never removed). Idempotent — safe to re-run.

## Compatibility

- `bash` 3.2+ (no bash-4-only syntax anywhere in `scripts/` or `bin/`).
- `jq` is a hard, deliberate dependency — no grep/sed/awk JSON-parsing
  fallback exists or is planned for it.
- No script writes outside of `$HOME/.local/bin`,
  `$HOME/.config/engineering-workflow`, or the target project's own
  `.engineering-workflow/`/`AGENTS.md`/`CLAUDE.md` — this is what keeps
  `install.sh`/`init-project.sh`/`uninstall.sh` safe to run without a
  sandbox.

## Updating the methodology without breaking existing projects

Every project vendors its own copy of the contract
(`.engineering-workflow/VERSION`, `workflow.config.json`, its own
`AGENTS.md`/`CLAUDE.md`) at `init-project.sh` time — it does not symlink
back to the `engineering-workflow` clone. Consequences:

- Changing `methodology/`, `contract/`, or the adapter templates in this
  repo has **zero effect** on any already-initialized project until that
  project explicitly re-runs `init-project.sh`.
- A project stays fully usable even on a machine where
  `engineering-workflow` was never cloned — only `init`/`doctor` require
  the clone.
- `doctor.sh`/`init-project.sh` surface version drift as information, not
  as a forced action — you decide when (and whether) to pull in a newer
  version, project by project.
