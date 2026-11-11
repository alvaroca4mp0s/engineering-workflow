#!/usr/bin/env bash
# EW-GOV-01B: actual execution, atomic latest-result evidence, advisory/strict
# handoff checks, and dispatcher (direct and installed symlink).
set -eu
TESTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
. "$TESTS_DIR/lib/assert.sh"
. "$TESTS_DIR/lib/fixtures.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME"
PROJ="$SANDBOX/project with spaces"
ew_test_mk_git_project "$PROJ"
RUN="$REPO_ROOT/scripts/verify-project.sh"
CLI="$REPO_ROOT/bin/engineering-workflow"
GEN="$REPO_ROOT/scripts/handoff/generate-handoff.sh"
READ="$REPO_ROOT/scripts/handoff/read-handoff.sh"
"$REPO_ROOT/scripts/init-project.sh" "$PROJ" >/dev/null
EW="$PROJ/.engineering-workflow"
CONFIG="$EW/workflow.config.json"
cp "$CONFIG" "$SANDBOX/config"

expect_exit() {
  local expected_code="$1" code=0
  shift
  "$@" > "$SANDBOX/out" 2>&1 || code=$?
  assert_eq "$expected_code" "$code" "exit code for $*"
}
set_command() {
  jq --arg command "$1" '.commands.verify = $command' "$SANDBOX/config" > "$CONFIG"
}
commit_project() {
  git -C "$PROJ" add .
  git -C "$PROJ" commit -q -m "$1"
}
# Snapshot outputs to prove strict denial precedes even a CRITICAL append.
check_denied() {
  local before after
  before=$(cksum "$EW/HANDOFF.md" "$EW/APPROVALS.log"; find "$EW/backups" -type f | sort)
  expect_exit 1 "$GEN" "$PROJ" --stage handoff --risk CRITICAL --approved-by QA --require-verify
  assert_contains "$SANDBOX/out" 'require-verify'
  after=$(cksum "$EW/HANDOFF.md" "$EW/APPROVALS.log"; find "$EW/backups" -type f | sort)
  assert_eq "$before" "$after" 'strict denial must not write approval/handoff/backups'
}
check_advisory() {
  "$GEN" "$PROJ" --stage review --risk LOW > "$SANDBOX/out" 2>&1
  assert_contains "$SANDBOX/out" 'WARN: VERIFY'
  "$READ" "$PROJ" > "$SANDBOX/out" 2>&1
  if [ -e "$EW/VERIFY.json" ]; then assert_contains "$SANDBOX/out" 'WARN: VERIFY'; fi
}
expect_exit 1 "$RUN" "$PROJ"
assert_contains "$SANDBOX/out" REPLACE_ME
assert_file_missing "$EW/VERIFY.json"
set_command 'touch SHOULD_NOT_EXECUTE # REPLACE_ME'
expect_exit 1 "$RUN" "$PROJ"
assert_file_missing "$PROJ/SHOULD_NOT_EXECUTE"
assert_file_missing "$EW/VERIFY.json"
printf '{}\n' > "$CONFIG"
expect_exit 1 "$RUN" "$PROJ"
assert_contains "$SANDBOX/out" 'invalid workflow contract'
rm "$CONFIG"
expect_exit 1 "$RUN" "$PROJ"
assert_contains "$SANDBOX/out" 'missing workflow contract'
expect_exit 1 "$RUN" "$SANDBOX/nonexistent"
expect_exit 1 "$RUN" "$HOME"
expect_exit 1 "$RUN" "$PROJ" extra
jq '.commands.verify = "touch SHOULD_NOT_EXECUTE\u0000ignored"' "$SANDBOX/config" > "$CONFIG"
expect_exit 1 "$RUN" "$PROJ"
assert_contains "$SANDBOX/out" 'unsupported NUL'
assert_file_missing "$PROJ/SHOULD_NOT_EXECUTE"
set_command ':'
mkdir "$EW/VERIFY.json"
expect_exit 1 "$RUN" "$PROJ"
assert_contains "$SANDBOX/out" 'must not be a directory'
rmdir "$EW/VERIFY.json"

# Exact command survives quotes, pipes and trailing newlines in JSON.
command=$'test -f README.md && printf \'verified | "ok"\\n\'\n\n'
set_command "$command"
"$GEN" "$PROJ" --risk CRITICAL --approved-by QA >/dev/null
commit_project 'configured project'
"$RUN" "$PROJ" > "$SANDBOX/out"
assert_contains "$SANDBOX/out" 'verified | "ok"'
jq -e --arg command "$command" --arg head "$(git -C "$PROJ" rev-parse HEAD)" '
  .schema_version == "1" and .status == "PASS" and .exit_code == 0 and
  .command == $command and .git_head == $head and .git_tree_dirty == false and
  (.verified_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))
' "$EW/VERIFY.json" >/dev/null
# No temporary files after successful write, and only snapshots changed.
assert_eq '' "$(find "$EW" -name '.VERIFY.json.*' -print)"
"$GEN" "$PROJ" --stage review --risk LOW --require-verify > "$SANDBOX/out" 2>&1
assert_not_contains "$SANDBOX/out" 'WARN: VERIFY'
"$READ" "$PROJ" > "$SANDBOX/out" 2>&1
assert_not_contains "$SANDBOX/out" 'WARN: VERIFY'
# Default target and dispatcher both execute in the target directory.
(cd "$PROJ" && "$CLI" verify) >/dev/null
"$CLI" handoff generate "$PROJ" --stage review --risk LOW --require-verify >/dev/null
"$CLI" handoff read "$PROJ" > "$SANDBOX/out"
assert_contains "$SANDBOX/out" 'Stage: review'
expect_exit 1 "$CLI" handoff
assert_contains "$SANDBOX/out" 'invalid handoff subcommand'
expect_exit 1 "$CLI" handoff bogus

# Missing evidence is advisory by default; reader retains legacy silence.
cp "$EW/VERIFY.json" "$SANDBOX/pass"
rm "$EW/VERIFY.json"
check_denied
check_advisory
# Malformed streams and inconsistent results never count as valid evidence.
for content in '{bad' '{}' '{} {}' ''; do
  printf '%s' "$content" > "$EW/VERIFY.json"
  check_denied
  check_advisory
done
jq '.exit_code = 7' "$SANDBOX/pass" > "$EW/VERIFY.json"
check_denied
check_advisory

# Real failure replaces earlier PASS atomically and propagates exit 7.
set_command 'exit 7'
expect_exit 7 "$CLI" verify "$PROJ"
jq -e '.status == "FAIL" and .exit_code == 7 and .command == "exit 7"' "$EW/VERIFY.json" >/dev/null
check_denied
check_advisory
# A preflight error must not overwrite an existing FAIL with PASS.
before=$(cksum "$EW/VERIFY.json")
set_command REPLACE_ME
expect_exit 1 "$RUN" "$PROJ"
assert_eq "$before" "$(cksum "$EW/VERIFY.json")"

# Simulated rename failure must preserve the previous complete result and
# clean the temporary file rather than publish a partial PASS.
set_command ':'
mkdir "$SANDBOX/fake-bin"
printf '#!/usr/bin/env bash\nexit 1\n' > "$SANDBOX/fake-bin/mv"
chmod +x "$SANDBOX/fake-bin/mv"
expect_exit 1 env PATH="$SANDBOX/fake-bin:$PATH" "$RUN" "$PROJ"
assert_contains "$SANDBOX/out" 'could not persist VERIFY evidence'
assert_eq "$before" "$(cksum "$EW/VERIFY.json")"
assert_eq '' "$(find "$EW" -name '.VERIFY.json.*' -print)"

# A new HEAD makes prior evidence stale, even when previously clean.
set_command "$command"
commit_project 'new head'
cp "$SANDBOX/pass" "$EW/VERIFY.json"
check_denied
check_advisory
"$RUN" "$PROJ" >/dev/null
# Changes AFTER a clean verification also block strict mode.
printf 'dirty\n' >> "$PROJ/README.md"
check_denied
# Dirty evidence warns in both generator and reader, even on same HEAD.
"$RUN" "$PROJ" >/dev/null
jq -e '.status == "PASS" and .git_tree_dirty == true' "$EW/VERIFY.json" >/dev/null
check_denied
check_advisory
git -C "$PROJ" checkout -- README.md
# Untracked file is also dirty, excluding only generated handoff/evidence.
printf 'untracked\n' > "$PROJ/untracked.txt"
"$RUN" "$PROJ" >/dev/null
jq -e '.git_tree_dirty == true' "$EW/VERIFY.json" >/dev/null
rm "$PROJ/untracked.txt"
"$RUN" "$PROJ" >/dev/null
jq -e '.git_tree_dirty == false' "$EW/VERIFY.json" >/dev/null
"$GEN" "$PROJ" --stage handoff --risk LOW --require-verify >/dev/null
# Installed symlink exercises the real dispatcher path resolution.
export PATH="$HOME/.local/bin:$PATH"
"$REPO_ROOT/scripts/install.sh" >/dev/null
"$HOME/.local/bin/engineering-workflow" verify "$PROJ" >/dev/null
"$HOME/.local/bin/engineering-workflow" handoff generate "$PROJ" --risk LOW --require-verify >/dev/null
"$HOME/.local/bin/engineering-workflow" handoff read "$PROJ" > "$SANDBOX/out"
assert_contains "$SANDBOX/out" 'disposable'
# Unborn repo still produces a well-formed result, with dirty=true because
# its contract is not committed. No invented HEAD is recorded.
UNBORN="$SANDBOX/unborn"
mkdir -p "$UNBORN/.engineering-workflow"
git -C "$UNBORN" init -q
cp "$CONFIG" "$UNBORN/.engineering-workflow/workflow.config.json"
# This command needs README.md in cwd.
printf 'demo\n' > "$UNBORN/README.md"
"$RUN" "$UNBORN" >/dev/null
jq -e '.git_head == "no-commits" and .git_tree_dirty == true' "$UNBORN/.engineering-workflow/VERIFY.json" >/dev/null
# Nested targets must still account for changes elsewhere in the Git tree.
. "$REPO_ROOT/scripts/lib/common.sh"
NESTED="$PROJ/subproject"
mkdir -p "$NESTED/.engineering-workflow"
cp "$CONFIG" "$NESTED/.engineering-workflow/workflow.config.json"
commit_project 'nested contract'
printf 'outside target\n' > "$PROJ/outside.txt"
assert_eq true "$(ew_git_tree_dirty "$NESTED")"
rm "$PROJ/outside.txt"
printf '{}\n' > "$NESTED/.engineering-workflow/VERIFY.json"
printf '# disposable\n' > "$NESTED/.engineering-workflow/HANDOFF.md"
assert_eq false "$(ew_git_tree_dirty "$NESTED")"
printf 'PASS test_verify_evidence\n'
