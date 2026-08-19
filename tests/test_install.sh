#!/usr/bin/env bash
# install.sh: creates the PATH symlink + install.json, and is idempotent.
set -u
TESTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
. "$TESTS_DIR/lib/assert.sh"
. "$TESTS_DIR/lib/fixtures.sh"

FAILED=0
export HOME
HOME=$(ew_test_mk_home)

"$REPO_ROOT/scripts/install.sh" >/tmp/ew_test_install.out 2>&1
rc=$?
assert_eq 0 "$rc" "install.sh first run exit code" || FAILED=1

assert_file_exists "$HOME/.local/bin/engineering-workflow" || FAILED=1
link_target=$(readlink "$HOME/.local/bin/engineering-workflow")
assert_eq "$REPO_ROOT/bin/engineering-workflow" "$link_target" "symlink target" || FAILED=1

assert_file_exists "$HOME/.config/engineering-workflow/install.json" || FAILED=1
repo_in_json=$(jq -r '.repo_root' "$HOME/.config/engineering-workflow/install.json")
assert_eq "$REPO_ROOT" "$repo_in_json" "install.json repo_root" || FAILED=1
version_in_json=$(jq -r '.version' "$HOME/.config/engineering-workflow/install.json")
assert_eq "$(cat "$REPO_ROOT/VERSION")" "$version_in_json" "install.json version" || FAILED=1

# idempotency: second run succeeds and leaves equivalent state
"$REPO_ROOT/scripts/install.sh" >/tmp/ew_test_install2.out 2>&1
rc2=$?
assert_eq 0 "$rc2" "install.sh second run exit code" || FAILED=1
link_target2=$(readlink "$HOME/.local/bin/engineering-workflow")
assert_eq "$link_target" "$link_target2" "symlink target unchanged after re-install" || FAILED=1

# dispatcher works end to end (invoked via the installed symlink)
ew_version=$("$HOME/.local/bin/engineering-workflow" version)
assert_eq "$(cat "$REPO_ROOT/VERSION")" "$ew_version" "dispatcher 'version' output" || FAILED=1

if [ "$FAILED" -eq 0 ]; then
  echo "PASS test_install"
else
  echo "FAIL test_install"
fi
exit "$FAILED"
