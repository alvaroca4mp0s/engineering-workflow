# Generic / No-Agent Fallback

This project can be worked on by a plain human, a shell session, or any
coding agent not covered by a dedicated adapter — no Claude Code, no
Codex, no plugin required.

Read, in order:

1. `.engineering-workflow/workflow.config.json` (contract)
2. `openspec/` if present
3. `git log` / `git status`
4. Run the `commands.verify` command from the contract yourself and read
   its exit code and output — do not trust a summary of it.
5. `.engineering-workflow/HANDOFF.md` if present (disposable note, not a
   source of truth)

Follow the lifecycle and risk gates in `methodology/OVERVIEW.md` and
`methodology/RISK-MODEL.md`. Nothing in this repository requires any
specific agent, model, or plugin to be present.
