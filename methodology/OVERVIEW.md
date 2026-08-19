# Methodology Overview

This document defines the core development lifecycle. It is intentionally
agnostic: it does not name any specific coding agent, model, or vendor.
Anything that reads this file — human or agent — should be able to follow
it without any other context.

## Lifecycle

```
DISCOVER → SHAPE → SPEC → IMPLEMENT → VERIFY → REVIEW → DOCUMENT → HANDOFF / COMMIT
```

- **DISCOVER** — understand the current state of the system and the problem
  before proposing changes. Read code, tests, docs, and prior decisions.
- **SHAPE** — turn an ambiguous request into a bounded proposal. Identify
  what is in scope, what is out, and what trade-offs are being made.
- **SPEC** — write down what will change and why, in a form durable enough
  to survive a context reset. A spec tool (e.g. OpenSpec) MAY be used here;
  it is never required.
- **IMPLEMENT** — make the change.
- **VERIFY** — run the project's own deterministic checks (build, lint,
  tests). An agent's own claim of correctness is never a substitute for
  running these checks and inspecting their exit codes.
- **REVIEW** — assess the change at a depth proportional to its risk (see
  `RISK-MODEL.md`). Review may be self-review, another agent, or a human.
- **DOCUMENT** — update durable documentation: README, ADRs, operational
  docs. Only decisions and behavior that outlive this change belong here.
- **HANDOFF / COMMIT** — persist the change (git) and, if the work is
  incomplete, leave a temporary operational note (`HANDOFF.md`) describing
  state and next steps for whoever continues — the same agent in a future
  session, or a different one entirely.

## Principles

1. Durable state lives in the repository, not in an agent's memory.
2. A spec tool (e.g. OpenSpec) MAY represent the specification of work. It
   is optional and never assumed to be present.
3. Git represents change history. It is the source of truth for "what
   changed."
4. Tests and deterministic checks represent verification. Nothing else
   does.
5. `AGENTS.md` represents project-specific instructions for agents.
6. Skills represent reusable procedures. They operationalize this document
   for a specific agent; they do not redefine it.
7. `HANDOFF.md` is a temporary, disposable operational artifact. It
   accelerates continuity across sessions/agents but is never treated as a
   durable source of truth — durable decisions belong in ADRs and docs,
   durable approvals belong in an approvals record, not in `HANDOFF.md`.
8. ADRs and documentation preserve durable decisions and their reasoning.
9. Any agent must be able to replace another without manually
   reconstructing context by hand — by reading the spec, git history,
   tests, docs, and handoff, in that order.
10. The methodology is independent of programming language and framework.
11. The concrete commands for verify/test/build belong to the project, and
    are declared in that project's `workflow.config.json` — never hardcoded
    into this tooling.
12. An LLM stating "PASS" is never equivalent to verification. Verification
    means running the project's declared deterministic command and
    inspecting its exit code and output.
13. Destructive or privileged operations require explicit, gated approval.
    See `RISK-MODEL.md`.
14. The depth of review must be proportional to risk. Not every change
    needs the same scrutiny.

## Optional capabilities

The following are capabilities the methodology can use *if present*, and
must never require:

- A spec tool such as OpenSpec.
- Any specific coding agent (Claude Code, Codex, or others).
- Any agent plugin or extension (e.g. a review/transfer plugin).

The core (this document, the risk model, the project contract, and the
deterministic scripts) must remain fully usable with none of the above
installed.
