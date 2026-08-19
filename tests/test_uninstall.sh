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

# safety: a foreign (non-symlink) file at the install path must never be
# deleted by uninstall.sh
HOME2=$(ew_test_mk_home)
mkdir -p "$HOME2/.local/bin"
FOREIGN_CONTENT="not engineering-workflow, do not delete me"
printf '%s\n' "$FOREIGN_CONTENT" > "$HOME2/.local/bin/engineering-workflow"
out_foreign=$(HOME="$HOME2" "$REPO_ROOT/scripts/uninstall.sh" 2>&1)
rc_foreign=$?
assert_eq 0 "$rc_foreign" "uninstall.sh exit code with a foreign file present" || FAILED=1
assert_file_exists "$HOME2/.local/bin/engineering-workflow" || FAILED=1
foreign_after=$(cat "$HOME2/.local/bin/engineering-workflow")
assert_eq "$FOREIGN_CONTENT" "$foreign_after" "foreign file content must be untouched by uninstall" || FAILED=1
echo "$out_foreign" | grep -qF "not managed by this tool" || { echo "  ASSERT FAIL: expected a clear skip message"; FAILED=1; }

# safety: a foreign SYMLINK (pointing somewhere that is not any
# engineering-workflow's bin/engineering-workflow) must also be left alone
HOME3=$(ew_test_mk_home)
mkdir -p "$HOME3/.local/bin" "$HOME3/somewhere-else"
printf '#!/bin/sh\necho unrelated tool\n' > "$HOME3/somewhere-else/unrelated-cli"
ln -s "$HOME3/somewhere-else/unrelated-cli" "$HOME3/.local/bin/engineering-workflow"
out_foreign_symlink=$(HOME="$HOME3" "$REPO_ROOT/scripts/uninstall.sh" 2>&1)
rc_foreign_symlink=$?
assert_eq 0 "$rc_foreign_symlink" "uninstall.sh exit code with a foreign symlink present" || FAILED=1
if [ ! -L "$HOME3/.local/bin/engineering-workflow" ]; then
  echo "  ASSERT FAIL: foreign symlink must still be present"
  FAILED=1
fi
foreign_symlink_target_after=$(readlink "$HOME3/.local/bin/engineering-workflow")
assert_eq "$HOME3/somewhere-else/unrelated-cli" "$foreign_symlink_target_after" "foreign symlink target must be untouched by uninstall" || FAILED=1
echo "$out_foreign_symlink" | grep -qF "not managed by this tool" || { echo "  ASSERT FAIL: expected a clear skip message for foreign symlink"; FAILED=1; }

# safety (deeper): a foreign symlink whose path *coincidentally* ends in
# "/bin/engineering-workflow" but lacks this tool's dispatcher marker must
# not be deleted -- path suffix alone must not be treated as ownership
HOME4=$(ew_test_mk_home)
mkdir -p "$HOME4/.local/bin" "$HOME4/unrelated-project/bin"
printf '#!/bin/sh\necho totally unrelated project, not engineering-workflow\n' \
  > "$HOME4/unrelated-project/bin/engineering-workflow"
ln -s "$HOME4/unrelated-project/bin/engineering-workflow" "$HOME4/.local/bin/engineering-workflow"
out_lookalike=$(HOME="$HOME4" "$REPO_ROOT/scripts/uninstall.sh" 2>&1)
rc_lookalike=$?
assert_eq 0 "$rc_lookalike" "uninstall.sh exit code with a lookalike foreign symlink present" || FAILED=1
if [ ! -L "$HOME4/.local/bin/engineering-workflow" ]; then
  echo "  ASSERT FAIL: lookalike foreign symlink must still be present"
  FAILED=1
fi
lookalike_target_after=$(readlink "$HOME4/.local/bin/engineering-workflow")
assert_eq "$HOME4/unrelated-project/bin/engineering-workflow" "$lookalike_target_after" "lookalike foreign symlink target must be untouched" || FAILED=1
echo "$out_lookalike" | grep -qF "not managed by this tool" || { echo "  ASSERT FAIL: expected a clear skip message for lookalike symlink"; FAILED=1; }

if [ "$FAILED" -eq 0 ]; then
  echo "PASS test_uninstall"
else
  echo "FAIL test_uninstall"
fi
exit "$FAILED"
