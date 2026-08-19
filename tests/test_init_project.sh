#!/usr/bin/env bash
# init-project.sh: on a clean git project, creates the expected files, all
# marked as engineering-workflow-managed.
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

# init-project.sh on a non-git dir must fail hard
NON_GIT=$(mktemp -d)
"$REPO_ROOT/scripts/init-project.sh" "$NON_GIT" >/tmp/ew_test_init_nongit.out 2>&1
rc_nongit=$?
assert_eq 1 "$rc_nongit" "init-project on non-git dir must exit 1" || FAILED=1

out=$("$REPO_ROOT/scripts/init-project.sh" "$PROJ" 2>&1)
rc=$?
assert_eq 0 "$rc" "init-project.sh exit code on clean project" || FAILED=1

assert_file_exists "$PROJ/.engineering-workflow/VERSION" || FAILED=1
assert_eq "$(cat "$REPO_ROOT/VERSION")" "$(cat "$PROJ/.engineering-workflow/VERSION")" "vendored VERSION matches clone" || FAILED=1

assert_file_exists "$PROJ/.engineering-workflow/workflow.config.json" || FAILED=1
jq empty "$PROJ/.engineering-workflow/workflow.config.json" 2>/dev/null
assert_eq 0 $? "workflow.config.json is valid JSON" || FAILED=1
proj_name=$(jq -r '.project_name' "$PROJ/.engineering-workflow/workflow.config.json")
assert_eq "proj" "$proj_name" "project_name derived from directory name" || FAILED=1

assert_file_exists "$PROJ/AGENTS.md" || FAILED=1
assert_contains "$PROJ/AGENTS.md" "engineering-workflow:managed" || FAILED=1
assert_file_exists "$PROJ/CLAUDE.md" || FAILED=1
assert_contains "$PROJ/CLAUDE.md" "engineering-workflow:managed" || FAILED=1

assert_file_exists "$PROJ/.engineering-workflow/HANDOFF.md" || FAILED=1
assert_contains "$PROJ/.engineering-workflow/HANDOFF.md" "Stage: init" || FAILED=1

if [ "$FAILED" -eq 0 ]; then
  echo "PASS test_init_project"
else
  echo "FAIL test_init_project"
fi
exit "$FAILED"
