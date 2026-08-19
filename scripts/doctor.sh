#!/usr/bin/env bash
# Diagnoses the environment. Never fails because an OPTIONAL capability is
# missing — only REQUIRED dependencies affect the exit code.
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

EW_REPO_ROOT=$(ew_repo_root "${BASH_SOURCE[0]}")
EW_VERSION=$(cat "$EW_REPO_ROOT/VERSION")
: "${EW_CONFIG_HOME:=$HOME/.config/engineering-workflow}"

status=0
ok()   { printf '  [ok]   %s\n' "$1"; }
warn() { printf '  [warn] %s\n' "$1"; }
bad()  { printf '  [fail] %s\n' "$1"; }

echo "engineering-workflow doctor — v$EW_VERSION"
echo "repo root: $EW_REPO_ROOT"
echo

echo "REQUIRED"
if command -v git >/dev/null 2>&1; then
  ok "git present ($(git --version))"
else
  bad "git not found"
  status=1
fi

if command -v jq >/dev/null 2>&1; then
  ok "jq present ($(jq --version))"
else
  bad "jq not found — required. macOS: brew install jq | Debian/Ubuntu: apt-get install -y jq"
  status=1
fi

bash_version=$("${BASH:-bash}" --version | head -1)
ok "bash: $bash_version"

echo
echo "INSTALL STATE"
if [ -f "$EW_CONFIG_HOME/install.json" ]; then
  installed_root=$(jq -r '.repo_root' "$EW_CONFIG_HOME/install.json" 2>/dev/null || echo "")
  installed_version=$(jq -r '.version' "$EW_CONFIG_HOME/install.json" 2>/dev/null || echo "")
  if [ "$installed_root" != "$EW_REPO_ROOT" ]; then
    warn "install.json points to a different clone: $installed_root"
  else
    ok "install.json matches this clone"
  fi
  if [ "$installed_version" != "$EW_VERSION" ]; then
    warn "installed version ($installed_version) differs from this clone's VERSION ($EW_VERSION) — run install.sh again or upgrade explicitly"
  else
    ok "installed version matches this clone ($EW_VERSION)"
  fi
else
  warn "not installed via install.sh yet (optional — scripts/*.sh work directly without it)"
fi

echo
echo "OPTIONAL CAPABILITIES"
if command -v claude >/dev/null 2>&1; then
  ok "claude (Claude Code) present ($(claude --version 2>/dev/null || echo 'version unknown'))"
else
  warn "claude (Claude Code) not found — Claude Code adapter unusable, core still works"
fi

if command -v codex >/dev/null 2>&1; then
  ok "codex (Codex CLI) present ($(codex --version 2>/dev/null || echo 'version unknown'))"
else
  warn "codex (Codex CLI) not found — Codex adapter unusable, core still works"
fi

plugin_file="$HOME/.claude/plugins/installed_plugins.json"
if [ -f "$plugin_file" ] && command -v jq >/dev/null 2>&1 && jq -e '.plugins | keys[] | select(startswith("codex@"))' "$plugin_file" >/dev/null 2>&1; then
  ok "codex-plugin-cc detected — /codex:review, /codex:adversarial-review available as review enhancers"
else
  warn "codex-plugin-cc not detected — independent review must use another agent or a human"
fi

if command -v openspec >/dev/null 2>&1; then
  ok "openspec CLI present ($(openspec --version 2>/dev/null || echo 'version unknown'))"
else
  warn "openspec CLI not found — optional, only needed if a project's spec_tool.type is 'openspec'"
fi

echo
if [ "$status" -eq 0 ]; then
  echo "Result: OK (all required dependencies present)"
else
  echo "Result: FAIL (missing required dependencies — see above)"
fi
exit "$status"
