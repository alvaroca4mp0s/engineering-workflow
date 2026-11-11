#!/usr/bin/env bash
# Execute the project's trusted commands.verify; atomically retain the latest
# result, not an audit history. Bash 3.2 compatible; no implicit set -e.
set -uo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

if [ $# -gt 1 ]; then
  ew_log_error "usage: verify-project.sh [target-dir]"
  exit 1
fi
TARGET="${1:-.}"
if [ ! -d "$TARGET" ]; then
  ew_log_error "target directory does not exist: $TARGET"
  exit 1
fi
TARGET=$(cd "$TARGET" && pwd) || exit 1
ew_require_cmd git "https://git-scm.com/downloads" || exit 1
if ! git -C "$TARGET" rev-parse --is-inside-work-tree 2>/dev/null | grep -qx true; then
  ew_log_error "not a git working tree: $TARGET"
  exit 1
fi
EW_DIR="$TARGET/.engineering-workflow"
ew_validate_contract "$EW_DIR/workflow.config.json" || exit 1
if [ -d "$EW_DIR/VERIFY.json" ]; then
  ew_log_error "VERIFY.json must not be a directory"
  exit 1
fi
# Bash command arguments cannot represent NUL; refuse rather than silently
# executing a different command than the contract declared.
if jq -e '.commands.verify | contains("\u0000")' "$EW_DIR/workflow.config.json" >/dev/null; then
  ew_log_error "commands.verify contains an unsupported NUL byte"
  exit 1
fi
# Appending a sentinel preserves trailing newlines in the exact command.
verify_command=$(jq -jr '.commands.verify, "\u0001"' "$EW_DIR/workflow.config.json") || exit 1
verify_command="${verify_command%$'\001'}"
case "$verify_command" in
  *REPLACE_ME*) ew_log_error "commands.verify contains REPLACE_ME; configure it before VERIFY"; exit 1 ;;
esac

head_before=$(git -C "$TARGET" rev-parse --verify HEAD 2>/dev/null || printf 'no-commits')
(cd "$TARGET" && bash -c "$verify_command")
result=$?
git_head=$(git -C "$TARGET" rev-parse --verify HEAD 2>/dev/null || printf 'no-commits')
dirty=$(ew_git_tree_dirty "$TARGET") || exit 1
# A command which changes HEAD cannot certify a stable clean snapshot.
[ "$head_before" = "$git_head" ] || dirty=true
status=FAIL
[ "$result" -ne 0 ] || status=PASS
verified_at=$(date -u +%Y-%m-%dT%H:%M:%SZ) || exit 1
# Snapshot git status BEFORE creating the temporary file, so it cannot
# contaminate git_tree_dirty. Rename in the same directory is atomic.
tmp=$(mktemp "$EW_DIR/.VERIFY.json.XXXXXX") || exit 1
trap 'rm -f "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
if ! jq -n --arg verified_at "$verified_at" --arg head "$git_head" \
  --argjson dirty "$dirty" --arg command "$verify_command" \
  --argjson code "$result" --arg status "$status" \
  '{schema_version:"1", verified_at:$verified_at, git_head:$head,
    git_tree_dirty:$dirty, command:$command, exit_code:$code, status:$status}' > "$tmp"; then
  ew_log_error "could not serialize VERIFY evidence"
  exit 1
fi
if ! mv -f "$tmp" "$EW_DIR/VERIFY.json"; then
  ew_log_error "could not persist VERIFY evidence"
  exit 1
fi
ew_log_info "VERIFY $status (exit=$result dirty=$dirty): $EW_DIR/VERIFY.json"
exit "$result"
