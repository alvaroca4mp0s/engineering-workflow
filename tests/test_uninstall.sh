#!/usr/bin/env bash
# uninstall.sh: reverses install.sh, is idempotent, and never touches the
# repo clone itself or any initialized project's .engineering-workflow/.
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

"$REPO_ROOT/scripts/install.sh" >/dev/null 2>&1
"$REPO_ROOT/scripts/init-project.sh" "$PROJ" >/dev/null 2>&1

"$REPO_ROOT/scripts/uninstall.sh" >/dev/null 2>&1
rc=$?
assert_eq 0 "$rc" "uninstall.sh exit code" || FAILED=1
assert_file_missing "$HOME/.local/bin/engineering-workflow" || FAILED=1
assert_file_missing "$HOME/.config/engineering-workflow/install.json" || FAILED=1

# idempotency: second uninstall is a clean no-op
"$REPO_ROOT/scripts/uninstall.sh" >/tmp/ew_test_uninstall2.out 2>&1
rc2=$?
assert_eq 0 "$rc2" "second uninstall.sh exit code" || FAILED=1
grep -qF "nothing to uninstall" /tmp/ew_test_uninstall2.out || { echo "  ASSERT FAIL: expected no-op notice on second uninstall"; FAILED=1; }

# repo clone itself must survive
assert_file_exists "$REPO_ROOT/VERSION" || FAILED=1

# the project initialized before uninstall must be completely untouched
assert_file_exists "$PROJ/.engineering-workflow/workflow.config.json" || FAILED=1
assert_file_exists "$PROJ/AGENTS.md" || FAILED=1
assert_contains "$PROJ/AGENTS.md" "engineering-workflow:managed" || FAILED=1

if [ "$FAILED" -eq 0 ]; then
  echo "PASS test_uninstall"
else
  echo "FAIL test_uninstall"
fi
exit "$FAILED"
