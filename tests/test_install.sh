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

# safety: a foreign (non-symlink) file already at the install path must
# never be silently clobbered -- install.sh must refuse and leave it alone
HOME2=$(ew_test_mk_home)
mkdir -p "$HOME2/.local/bin"
FOREIGN_CONTENT="#!/bin/sh
echo not engineering-workflow, do not touch me"
printf '%s\n' "$FOREIGN_CONTENT" > "$HOME2/.local/bin/engineering-workflow"
HOME="$HOME2" "$REPO_ROOT/scripts/install.sh" >/tmp/ew_test_install_foreign.out 2>&1
rc_foreign=$?
assert_eq 1 "$rc_foreign" "install.sh must refuse when destination is a foreign regular file" || FAILED=1
foreign_after=$(cat "$HOME2/.local/bin/engineering-workflow")
assert_eq "$FOREIGN_CONTENT" "$foreign_after" "foreign file content must be untouched" || FAILED=1
if [ -L "$HOME2/.local/bin/engineering-workflow" ]; then
  echo "  ASSERT FAIL: foreign file must not have been replaced by a symlink"
  FAILED=1
fi
grep -qF "refusing to overwrite" /tmp/ew_test_install_foreign.out || { echo "  ASSERT FAIL: expected a clear refusal message"; FAILED=1; }

# safety: a foreign SYMLINK (pointing somewhere that is not any
# engineering-workflow's bin/engineering-workflow) must also be refused,
# not silently replaced
HOME3=$(ew_test_mk_home)
mkdir -p "$HOME3/.local/bin" "$HOME3/somewhere-else"
printf '#!/bin/sh\necho unrelated tool\n' > "$HOME3/somewhere-else/unrelated-cli"
ln -s "$HOME3/somewhere-else/unrelated-cli" "$HOME3/.local/bin/engineering-workflow"
HOME="$HOME3" "$REPO_ROOT/scripts/install.sh" >/tmp/ew_test_install_foreign_symlink.out 2>&1
rc_foreign_symlink=$?
assert_eq 1 "$rc_foreign_symlink" "install.sh must refuse when destination is a foreign symlink" || FAILED=1
foreign_symlink_target_after=$(readlink "$HOME3/.local/bin/engineering-workflow")
assert_eq "$HOME3/somewhere-else/unrelated-cli" "$foreign_symlink_target_after" "foreign symlink target must be untouched" || FAILED=1
grep -qF "refusing to overwrite" /tmp/ew_test_install_foreign_symlink.out || { echo "  ASSERT FAIL: expected a clear refusal message for foreign symlink"; FAILED=1; }

# safety (deeper): a foreign symlink whose path *coincidentally* ends in
# "/bin/engineering-workflow" (the same suffix this tool's own dispatcher
# uses) but is NOT actually this tool's dispatcher (no marker inside) must
# still be refused -- path suffix alone must not be treated as ownership
HOME4=$(ew_test_mk_home)
mkdir -p "$HOME4/.local/bin" "$HOME4/unrelated-project/bin"
printf '#!/bin/sh\necho totally unrelated project, not engineering-workflow\n' \
  > "$HOME4/unrelated-project/bin/engineering-workflow"
ln -s "$HOME4/unrelated-project/bin/engineering-workflow" "$HOME4/.local/bin/engineering-workflow"
HOME="$HOME4" "$REPO_ROOT/scripts/install.sh" >/tmp/ew_test_install_lookalike.out 2>&1
rc_lookalike=$?
assert_eq 1 "$rc_lookalike" "install.sh must refuse a suffix-matching but markerless foreign symlink" || FAILED=1
lookalike_target_after=$(readlink "$HOME4/.local/bin/engineering-workflow")
assert_eq "$HOME4/unrelated-project/bin/engineering-workflow" "$lookalike_target_after" "lookalike foreign symlink target must be untouched" || FAILED=1
grep -qF "refusing to overwrite" /tmp/ew_test_install_lookalike.out || { echo "  ASSERT FAIL: expected a clear refusal message for lookalike symlink"; FAILED=1; }

if [ "$FAILED" -eq 0 ]; then
  echo "PASS test_install"
else
  echo "FAIL test_install"
fi
exit "$FAILED"
