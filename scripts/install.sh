#!/usr/bin/env bash
# Install engineering-workflow: wires up a `engineering-workflow` command on
# PATH and records where this clone lives, for `doctor.sh` to check later.
#
# Does NOT touch any project. Does NOT modify shell rc files. Idempotent —
# safe to re-run.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

EW_REPO_ROOT=$(ew_repo_root "${BASH_SOURCE[0]}")
EW_VERSION=$(cat "$EW_REPO_ROOT/VERSION")

: "${EW_INSTALL_PREFIX:=$HOME/.local/bin}"
: "${EW_CONFIG_HOME:=$HOME/.config/engineering-workflow}"

ew_log_info "engineering-workflow v$EW_VERSION"
ew_log_info "repo root: $EW_REPO_ROOT"

fail=0
ew_require_cmd git "https://git-scm.com/downloads" || fail=1
ew_require_cmd jq  "macOS: brew install jq | Debian/Ubuntu: apt-get install -y jq" || fail=1
if [ "$fail" -ne 0 ]; then
  ew_log_error "install aborted: missing required dependencies"
  exit 1
fi

if [ ! -x "$EW_REPO_ROOT/bin/engineering-workflow" ]; then
  ew_log_error "dispatcher not found or not executable: $EW_REPO_ROOT/bin/engineering-workflow"
  exit 1
fi

link="$EW_INSTALL_PREFIX/engineering-workflow"
if [ -e "$link" ] && [ ! -L "$link" ]; then
  ew_log_error "refusing to overwrite $link: it exists and is not a symlink managed by this tool"
  ew_log_error "  remove it manually, or set EW_INSTALL_PREFIX to install elsewhere"
  exit 1
fi
if [ -L "$link" ] && ! ew_is_own_symlink "$link"; then
  ew_log_error "refusing to overwrite $link: it is a symlink not managed by this tool (target: $(readlink "$link"))"
  ew_log_error "  remove it manually, or set EW_INSTALL_PREFIX to install elsewhere"
  exit 1
fi

mkdir -p "$EW_INSTALL_PREFIX"
ln -sf "$EW_REPO_ROOT/bin/engineering-workflow" "$link"
ew_log_info "linked: $link -> $EW_REPO_ROOT/bin/engineering-workflow"

mkdir -p "$EW_CONFIG_HOME"
jq -n \
  --arg repo_root "$EW_REPO_ROOT" \
  --arg version "$EW_VERSION" \
  --arg installed_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg os "$(ew_os_name)" \
  '{repo_root: $repo_root, version: $version, installed_at: $installed_at, os: $os}' \
  > "$EW_CONFIG_HOME/install.json"
ew_log_info "wrote install state: $EW_CONFIG_HOME/install.json"

case ":$PATH:" in
  *":$EW_INSTALL_PREFIX:"*) : ;;
  *)
    ew_log_warn "$EW_INSTALL_PREFIX is not on PATH."
    ew_log_warn "  add this to your shell profile: export PATH=\"$EW_INSTALL_PREFIX:\$PATH\""
    ;;
esac

ew_log_info "install complete. Run: engineering-workflow doctor"
