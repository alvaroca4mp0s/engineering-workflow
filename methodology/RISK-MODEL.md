# Risk Model

Every unit of work declares a risk level. The level determines which gates
must pass before the work is considered done. Risk is declared explicitly
(in `workflow.config.json` defaults, or per-change via the handoff tooling)
— it is never silently inferred by an agent without leaving a record of
the decision.

| Level | Examples | Required gates |
|---|---|---|
| **LOW** | Documentation, comments, trivial/cosmetic changes, non-functional config | `verify` |
| **MEDIUM** | Ordinary application code, no security/data/infra boundary crossed | `verify` + review |
| **HIGH** | Persistence/schema changes, security-relevant code, infrastructure | `verify` + independent review (a different agent or a human, not self-review) |
| **CRITICAL** | Production data, privilege escalation, production deployment, recovery/rollback procedures | `verify` + independent (adversarial) review + **explicit human approval, recorded as a durable artifact** |

## Rules

- **Gates are deterministic where possible.** `verify` always means: run
  the project's declared command and check its exit code. It never means
  an agent asserting success.
- **CRITICAL approval must be durable and separate from `HANDOFF.md`.**
  `HANDOFF.md` is disposable (see `OVERVIEW.md` principle 7); an approval
  for CRITICAL work must not live only there. The reference implementation
  in this repository appends CRITICAL approvals to
  `.engineering-workflow/APPROVALS.log` inside the target project (an
  append-only, durable file — see `docs/OPERATIONS.md`). A commit trailer
  (e.g. `Approved-by:`) is an acceptable alternative or complement.
- **Independent review** means a reviewer that did not write the change:
  another agent, another person, or a dedicated adversarial-review pass.
  Self-review by the same agent that implemented the change does not
  satisfy HIGH or CRITICAL.
- **Escalate, don't downgrade.** If unsure between two levels, use the
  higher one. The cost of an unnecessary review pass is much lower than
  the cost of an unreviewed CRITICAL change.
- **Risk level is a property of the change, not of the agent.** The same
  gates apply regardless of which agent or human performs the work.
