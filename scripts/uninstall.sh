#!/usr/bin/env bash
# Reverses install.sh: removes the `engineering-workflow` PATH symlink and
# the local install-state file. Does NOT delete this repo clone, and does
# NOT touch any project that was initialized with init-project.sh — a
# project's .engineering-workflow/ directory (contract, handoff, approvals
# log) is that project's own durable/operational state and is never
# removed by this script. Idempotent — safe to re-run.
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

: "${EW_INSTALL_PREFIX:=$HOME/.local/bin}"
: "${EW_CONFIG_HOME:=$HOME/.config/engineering-workflow}"

link="$EW_INSTALL_PREFIX/engineering-workflow"
did_something=0

if [ -L "$link" ] && ew_is_own_symlink "$link"; then
  rm -f "$link"
  ew_log_info "removed $link"
  did_something=1
elif [ -e "$link" ] || [ -L "$link" ]; then
  ew_log_warn "$link exists but is not managed by this tool — left untouched"
else
  ew_log_info "$link not present — nothing to remove"
fi

if [ -f "$EW_CONFIG_HOME/install.json" ]; then
  rm -f "$EW_CONFIG_HOME/install.json"
  ew_log_info "removed $EW_CONFIG_HOME/install.json"
  did_something=1
fi

if [ -d "$EW_CONFIG_HOME" ] && [ -z "$(ls -A "$EW_CONFIG_HOME" 2>/dev/null)" ]; then
  rmdir "$EW_CONFIG_HOME"
  ew_log_info "removed empty $EW_CONFIG_HOME"
fi

if [ "$did_something" -eq 0 ]; then
  ew_log_info "nothing to uninstall (already uninstalled, or never installed)"
fi

ew_log_info "note: this repo clone was NOT deleted, remove it manually if desired"
ew_log_info "note: projects initialized with init-project.sh keep their .engineering-workflow/ untouched"
