#!/usr/bin/env bash
# init-project.sh run twice on the same clean project must be a no-op the
# second time: exit 0, and every managed file byte-identical to the first
# run's output.
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

"$REPO_ROOT/scripts/init-project.sh" "$PROJ" >/dev/null 2>&1
rc1=$?
assert_eq 0 "$rc1" "first init-project.sh run" || FAILED=1

checksum() { cksum "$1" | awk '{print $1, $2}'; }
sum_agents_1=$(checksum "$PROJ/AGENTS.md")
sum_claude_1=$(checksum "$PROJ/CLAUDE.md")
sum_config_1=$(checksum "$PROJ/.engineering-workflow/workflow.config.json")
sum_version_1=$(checksum "$PROJ/.engineering-workflow/VERSION")
sum_handoff_1=$(checksum "$PROJ/.engineering-workflow/HANDOFF.md")
sum_gitignore_1=$(checksum "$PROJ/.engineering-workflow/.gitignore")
sum_methodology_1=$(checksum "$PROJ/.engineering-workflow/methodology/OVERVIEW.md")

out2=$("$REPO_ROOT/scripts/init-project.sh" "$PROJ" 2>&1)
rc2=$?
assert_eq 0 "$rc2" "second init-project.sh run" || FAILED=1
echo "$out2" | grep -qF "created=0" || { echo "  ASSERT FAIL: second run should create nothing"; FAILED=1; }
echo "$out2" | grep -qF "conflicts=0" || { echo "  ASSERT FAIL: second run should have no conflicts"; FAILED=1; }

sum_agents_2=$(checksum "$PROJ/AGENTS.md")
sum_claude_2=$(checksum "$PROJ/CLAUDE.md")
sum_config_2=$(checksum "$PROJ/.engineering-workflow/workflow.config.json")
sum_version_2=$(checksum "$PROJ/.engineering-workflow/VERSION")
sum_handoff_2=$(checksum "$PROJ/.engineering-workflow/HANDOFF.md")
sum_gitignore_2=$(checksum "$PROJ/.engineering-workflow/.gitignore")
sum_methodology_2=$(checksum "$PROJ/.engineering-workflow/methodology/OVERVIEW.md")

assert_eq "$sum_agents_1" "$sum_agents_2" "AGENTS.md unchanged by second init" || FAILED=1
assert_eq "$sum_claude_1" "$sum_claude_2" "CLAUDE.md unchanged by second init" || FAILED=1
assert_eq "$sum_config_1" "$sum_config_2" "workflow.config.json unchanged by second init" || FAILED=1
assert_eq "$sum_version_1" "$sum_version_2" "VERSION unchanged by second init" || FAILED=1
assert_eq "$sum_handoff_1" "$sum_handoff_2" "HANDOFF.md unchanged by second init" || FAILED=1
assert_eq "$sum_gitignore_1" "$sum_gitignore_2" ".engineering-workflow/.gitignore unchanged by second init" || FAILED=1
assert_eq "$sum_methodology_1" "$sum_methodology_2" "vendored methodology/OVERVIEW.md unchanged by second init" || FAILED=1

if [ "$FAILED" -eq 0 ]; then
  echo "PASS test_idempotency"
else
  echo "FAIL test_idempotency"
fi
exit "$FAILED"
