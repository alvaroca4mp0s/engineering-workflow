# Portability

## Target platforms

- macOS (tested: macOS 26, Apple Silicon, default `/bin/bash` 3.2.57)
- Ubuntu Desktop (not yet independently validated — see below)
- Ubuntu Server — validated on 24.04.4 LTS, x86_64
  (bash 5.2.21, git 2.43.0, jq 1.7, kernel 6.8), BET 2

The methodology's *content* (`methodology/`, `contract/`, `adapters/`) is
identical on every platform — there are no OS-specific branches in it.
Only `scripts/*.sh` contain a small amount of OS detection
(`scripts/lib/common.sh`'s `ew_os_name`), used purely for informational
labeling (e.g. in `install.json`), never to change behavior.

## Dependency policy

| Dependency | Policy |
|---|---|
| `bash` 3.2+ | required, assumed present | 
| `git` | required |
| `jq` | required — hard dependency, deliberately, no fallback parser |
| Node, Python, Ruby, etc. | never required by core tooling |
| Any specific coding agent | never required |
| `codex-plugin-cc` | never required |
| OpenSpec CLI | never required |

This means the three-command install (`git clone`, `./scripts/install.sh`,
`./scripts/doctor.sh`) works on a bare Ubuntu Server image with only
`git`, `bash`, and `jq` installed — no build toolchain, no language
runtime, no container engine.

## Why bash 3.2, specifically

macOS ships bash 3.2.57 by default and does not upgrade it (licensing).
Requiring a newer bash would mean either depending on Homebrew (adding a
package-manager dependency this tool otherwise avoids) or telling every
macOS user to install a second bash first. All scripts avoid bash-4+-only
features: no associative arrays (`declare -A`), no `${var,,}`/`${var^^}`,
no `mapfile`/`readarray`, no `[[ -v ... ]]`.

## Vendoring model

`init-project.sh` **copies** the contract, the core methodology docs
(`methodology/OVERVIEW.md`, `RISK-MODEL.md`), and the rendered adapter
templates into the target project's `.engineering-workflow/` directory and
root — it does not symlink to the `engineering-workflow` clone, and
`AGENTS.md`/`CLAUDE.md` reference the vendored copy, not the clone.
Consequences:

- A project keeps working (contract, methodology, handoff, approvals log
  all readable) even on a machine where `engineering-workflow` was never
  cloned — only `init`/`doctor`/upgrade tooling requires the clone.
- Moving a project to a new machine, or handing it to a different agent,
  never requires copying prompts or config by hand — everything the
  methodology needs travels with the project's own git history.
- The trade-off: picking up methodology improvements requires an explicit
  re-init/upgrade per project (see `docs/MAINTENANCE.md`) — nothing is
  shared automatically across projects on the same machine.

## Empirical validation status

- **macOS**: built and tested during BET 1 (macOS 26, Apple Silicon,
  bash 3.2.57).
- **Ubuntu Server 24.04.4 LTS (x86_64)**: validated in BET 2 — full core
  path (`install → doctor → init-project → operate → handoff →
  uninstall`), through both the direct-from-clone scripts and the
  installed dispatcher symlink, plus the deterministic suite (8/8). No
  Ubuntu-specific change and no dependency beyond the declared `bash`,
  `git`, `jq` was required. The scripts also assume a standard
  POSIX/coreutils userland (`date`, `tr`, `tail`, `readlink`, `mktemp`,
  etc.) — an environmental assumption present on any base macOS or Ubuntu
  image, not an additional hard dependency to install. Baseline: bash
  5.2.21, git 2.43.0, jq 1.7, kernel 6.8.

Still unverified (candidates for a future bet):
- Ubuntu on **arm64** (userland-difference risk is highest here).
- **Ubuntu Desktop** specifically (Server was the validated target).
