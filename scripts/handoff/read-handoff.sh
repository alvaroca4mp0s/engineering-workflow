#!/usr/bin/env bash
# Prints the current .engineering-workflow/HANDOFF.md for a project, with a
# reminder that it is a disposable artifact, not a source of truth.
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

TARGET="${1:-.}"
if [ ! -d "$TARGET" ]; then
  ew_log_error "target directory does not exist: $TARGET"
  exit 1
fi
TARGET=$(cd "$TARGET" && pwd)
handoff_file="$TARGET/.engineering-workflow/HANDOFF.md"

if [ ! -f "$handoff_file" ]; then
  ew_log_error "no handoff found at $handoff_file"
  ew_log_error "generate one with: scripts/handoff/generate-handoff.sh $TARGET --stage <stage> --risk <level>"
  exit 1
fi

echo "=== HANDOFF (disposable — see methodology/OVERVIEW.md principle 7) ==="
cat "$handoff_file"
