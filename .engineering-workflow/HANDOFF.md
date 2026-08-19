<!-- engineering-workflow:handoff v0.1.0 -->
<!--
  THIS FILE IS DISPOSABLE. It is a temporary operational artifact, not a
  durable source of truth. Durable decisions belong in ADRs/docs. Durable
  approvals belong in .engineering-workflow/APPROVALS.log (or a commit
  trailer), never only here. This file may be regenerated or discarded at
  any time — see methodology/OVERVIEW.md principle 7.
-->

# Handoff

- Generated at: 2026-08-19T15:35:35Z
- Stage: document
- Risk: LOW
- Git branch: main
- Git HEAD: 758e66d

## Note

Fixed two risks found during self-dogfooding: (1) GitHub repo was public, contradicting the approved 'private' decision -- corrected to private via gh. (2) .engineering-workflow/backups/ and proposals/ had no retention policy and would grow unbounded if committed -- fixed at the source in init-project.sh, which now creates a .gitignore scoped to .engineering-workflow/ (never touching the project's own root .gitignore). Verified: backups/ confirmed excluded via git check-ignore, full test suite green (7/7), self-init idempotent. Ready to commit this fix + the self-hosting artifacts (AGENTS.md, CLAUDE.md, .engineering-workflow/{VERSION,workflow.config.json,HANDOFF.md,.gitignore}).

## Git status at generation time

```
 M docs/OPERATIONS.md
 M scripts/init-project.sh
 M tests/test_idempotency.sh
 M tests/test_init_project.sh
?? .engineering-workflow/
?? AGENTS.md
?? CLAUDE.md
?? templates/EW-GITIGNORE.template
```
