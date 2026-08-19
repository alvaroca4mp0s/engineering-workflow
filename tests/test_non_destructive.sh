#!/usr/bin/env bash
# init-project.sh must never overwrite a pre-existing, unmanaged AGENTS.md
# or CLAUDE.md. It must back it up, write a separate proposal, and signal
# an explicit conflict (exit 2) instead of merging automatically.
set -u
TESTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
. "$TESTS_DIR/lib/assert.sh"
. "$TESTS_DIR/lib/fixtures.sh"

FAILED=0
export HOME
HOME=$(ew_test_mk_home)
PROJ=$(mktemp -d)/proj
ew_test_mk_git_project "$PROJ"

ORIGINAL_CONTENT="# Mis instrucciones custom, escritas a mano"
printf '%s\n' "$ORIGINAL_CONTENT" > "$PROJ/AGENTS.md"
git -C "$PROJ" add AGENTS.md
git -C "$PROJ" commit -q -m "custom agents.md"

out=$("$REPO_ROOT/scripts/init-project.sh" "$PROJ" 2>&1)
rc=$?
assert_eq 2 "$rc" "init-project.sh must exit 2 on conflict" || FAILED=1
echo "$out" | grep -qF "CONFLICT" || { echo "  ASSERT FAIL: expected CONFLICT in output"; FAILED=1; }

actual_content=$(cat "$PROJ/AGENTS.md")
assert_eq "$ORIGINAL_CONTENT" "$actual_content" "original AGENTS.md must be untouched" || FAILED=1

backup_count=$(find "$PROJ/.engineering-workflow/backups" -name 'AGENTS.md.bak-*' | wc -l | tr -d ' ')
if [ "$backup_count" -lt 1 ]; then
  echo "  ASSERT FAIL: expected at least one AGENTS.md backup"
  FAILED=1
fi

assert_file_exists "$PROJ/.engineering-workflow/proposals/AGENTS.md.proposed" || FAILED=1
assert_contains "$PROJ/.engineering-workflow/proposals/AGENTS.md.proposed" "engineering-workflow:managed" || FAILED=1

# CLAUDE.md had no conflict — should have been created normally
assert_file_exists "$PROJ/CLAUDE.md" || FAILED=1
assert_contains "$PROJ/CLAUDE.md" "engineering-workflow:managed" || FAILED=1

if [ "$FAILED" -eq 0 ]; then
  echo "PASS test_non_destructive"
else
  echo "FAIL test_non_destructive"
fi
exit "$FAILED"
