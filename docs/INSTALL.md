# Install

## Requirements

| Dependency | Required? | Notes |
|---|---|---|
| `bash` | yes | 3.2+ (macOS default). No bash-4-only features are used. |
| `git` | yes | any reasonably recent version |
| `jq` | yes | macOS: `brew install jq`. Debian/Ubuntu: `apt-get install -y jq`. `install.sh` and `doctor.sh` refuse to proceed without it — there is no fallback parser. |
| Claude Code / Codex CLI | no | optional agent adapters, core works without either |
| `codex-plugin-cc` | no | optional review/transfer enhancer, detected by `doctor.sh` |
| OpenSpec CLI | no | only needed if a project's `spec_tool.type` is `openspec` |

## Install

```bash
git clone <this-repo-url> engineering-workflow
cd engineering-workflow
./scripts/install.sh
./scripts/doctor.sh
```

`install.sh`:
- Verifies `git` and `jq` are present (hard failure otherwise).
- Symlinks `~/.local/bin/engineering-workflow` to `bin/engineering-workflow`
  in this clone.
- Writes `~/.config/engineering-workflow/install.json` recording this
  clone's path and version (used by `doctor.sh` to detect drift).
- Warns (does not fail, does not edit shell rc files) if
  `~/.local/bin` is not on your `PATH`.

It is idempotent — re-running it just updates the symlink and the state
file.

`doctor.sh` reports on required dependencies, install state, and optional
capabilities. It exits `0` if all *required* dependencies are present,
regardless of which optional capabilities are missing.

## Using without installing

Every script also works directly from the clone, without `install.sh`
having been run — this is what makes the methodology usable even on a
machine where you don't want a global install:

```bash
./scripts/doctor.sh
./scripts/init-project.sh /path/to/project
./scripts/handoff/generate-handoff.sh /path/to/project --stage implement --risk MEDIUM
```

## Uninstall

```bash
./scripts/uninstall.sh
```

Removes the `~/.local/bin/engineering-workflow` symlink and
`~/.config/engineering-workflow/install.json`. Idempotent — safe to
re-run. Does **not**:
- delete this repo clone (remove it yourself with `rm -rf` if you want to),
- touch any project you previously ran `init-project.sh` on — a project's
  `.engineering-workflow/` directory (contract, handoff, approvals log) is
  that project's own state, independent of whether the tool is installed.

## Environment overrides (used mainly by the test suite)

- `EW_INSTALL_PREFIX` — where the symlink is created (default `~/.local/bin`)
- `EW_CONFIG_HOME` — where install state is recorded (default `~/.config/engineering-workflow`)
