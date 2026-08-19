# Troubleshooting

## `jq not found`

`doctor.sh`/`install.sh`/`init-project.sh` refuse to run without `jq` — by
design, there is no fallback JSON parser. Install it:
- macOS: `brew install jq`
- Debian/Ubuntu: `apt-get install -y jq`

## `install.sh` refuses with "refusing to overwrite ..."

Expected safety behavior: something other than this tool already occupies
`~/.local/bin/engineering-workflow` — either a real file/directory, or a
symlink pointing somewhere that isn't a clone's `bin/engineering-workflow`
(e.g. an unrelated tool that happens to share the name). Installing would
have clobbered it. Move or remove that path yourself, or set
`EW_INSTALL_PREFIX` to a different directory, then re-run `install.sh`.

## `uninstall.sh` says "exists but is not managed by this tool"

Same safety behavior in reverse: `uninstall.sh` found something at
`~/.local/bin/engineering-workflow` that isn't its own symlink (a foreign
file, or a foreign symlink pointing elsewhere), so it left it in place
instead of deleting it. This is not an error — `uninstall.sh` still exits
`0`. If you expected `engineering-workflow` to be gone, check what's
actually at that path before removing it yourself.

## `engineering-workflow: command not found` after `install.sh`

`install.sh` never edits your shell rc files. If it printed a warning like:

```
[ew] WARN: /home/you/.local/bin is not on PATH.
```

add the suggested line to your `~/.bashrc`/`~/.zshrc` yourself, then open a
new shell (or `source` the file). Alternatively, always use the scripts
directly: `./scripts/doctor.sh`, `./scripts/init-project.sh`, etc. — no
install required.

## `not a git repository` from `init-project.sh`

`init-project.sh` requires the target to already be a git repo (principle:
"Git represents change"). Run `git init` in the target directory first,
then re-run `init-project.sh`.

## `init-project.sh` exits with code 2 ("CONFLICT")

This means `AGENTS.md` and/or `CLAUDE.md` already existed in the target
and were not created by this tool (no `engineering-workflow:managed`
marker found). Nothing was overwritten. Check:

- `.engineering-workflow/backups/` — a timestamped copy of your original file
- `.engineering-workflow/proposals/` — the template this tool would have written

Merge by hand, then decide whether to replace the original file with the
proposal (which will make future `init-project.sh` runs treat it as
managed) or keep your own file (the conflict warning will keep appearing
on every re-run — that's expected, not a bug, since there's no merge
tracking in v1).

## `generate-handoff.sh` refuses a CRITICAL handoff

Expected. CRITICAL risk requires `--approved-by "<name>"` — see
`docs/OPERATIONS.md#risk-gates`. This is a deliberate gate, not a bug:
CRITICAL work must have a durable, separate approval record
(`.engineering-workflow/APPROVALS.log`), never only a `HANDOFF.md` entry.

## `doctor.sh` reports "install.json points to a different clone"

You have `~/.config/engineering-workflow/install.json` pointing at a path
that doesn't match the clone you're currently running `doctor.sh` from —
usually because you moved or re-cloned the repo. Re-run
`./scripts/install.sh` from the clone you actually want to use.

## Tests fail locally

Run `./tests/run.sh` and read the `ASSERT FAIL` lines — each names the
exact expectation that didn't hold. Every test uses its own throwaway
`$HOME`/project via `mktemp`, so a failure should never be caused by
leftover state from a previous run; if you suspect otherwise, check
`/tmp` for `ew_test_*` leftovers from a crashed run and remove them.

## I ran `uninstall.sh` and now my project's `.engineering-workflow/` is gone

That should not happen — `uninstall.sh` only ever touches
`$HOME/.local/bin/engineering-workflow` and
`$HOME/.config/engineering-workflow/`. It never touches any project
directory. If you're seeing project state missing, it was not caused by
`uninstall.sh`; check `git status`/`git reflog` in the project itself.
