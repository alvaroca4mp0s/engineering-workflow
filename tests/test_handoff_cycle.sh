#!/usr/bin/env bash
# generate-handoff.sh / read-handoff.sh: the pure file-based operate ->
# handoff cycle, plus the CRITICAL risk gate (must refuse without
# --approved-by, and must write a durable APPROVALS.log entry when given).
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

# MEDIUM risk handoff
"$REPO_ROOT/scripts/handoff/generate-handoff.sh" "$PROJ" --stage implement --risk MEDIUM --note "in progress" >/dev/null 2>&1
rc=$?
assert_eq 0 "$rc" "generate-handoff MEDIUM exit code" || FAILED=1
assert_contains "$PROJ/.engineering-workflow/HANDOFF.md" "Stage: implement" || FAILED=1
assert_contains "$PROJ/.engineering-workflow/HANDOFF.md" "Risk: MEDIUM" || FAILED=1
assert_file_missing "$PROJ/.engineering-workflow/APPROVALS.log" || FAILED=1

read_out=$("$REPO_ROOT/scripts/handoff/read-handoff.sh" "$PROJ")
echo "$read_out" | grep -qF "disposable" || { echo "  ASSERT FAIL: read-handoff must show disposable banner"; FAILED=1; }
echo "$read_out" | grep -qF "Stage: implement" || { echo "  ASSERT FAIL: read-handoff must show current stage"; FAILED=1; }

# CRITICAL without approval must be refused, must not write a handoff
before_sum=$(cksum "$PROJ/.engineering-workflow/HANDOFF.md")
"$REPO_ROOT/scripts/handoff/generate-handoff.sh" "$PROJ" --stage handoff --risk CRITICAL --note "deploy" >/tmp/ew_test_critical.out 2>&1
rc_critical_denied=$?
assert_eq 1 "$rc_critical_denied" "CRITICAL without --approved-by must exit 1" || FAILED=1
grep -qF "requires --approved-by" /tmp/ew_test_critical.out || { echo "  ASSERT FAIL: expected approval-required message"; FAILED=1; }
after_sum=$(cksum "$PROJ/.engineering-workflow/HANDOFF.md")
assert_eq "$before_sum" "$after_sum" "HANDOFF.md must be unchanged after a denied CRITICAL attempt" || FAILED=1
assert_file_missing "$PROJ/.engineering-workflow/APPROVALS.log" || FAILED=1

# CRITICAL with approval must succeed and leave a durable, separate record
"$REPO_ROOT/scripts/handoff/generate-handoff.sh" "$PROJ" --stage handoff --risk CRITICAL --note "deploy" --approved-by "Alvaro" >/dev/null 2>&1
rc_critical_ok=$?
assert_eq 0 "$rc_critical_ok" "CRITICAL with --approved-by must exit 0" || FAILED=1
assert_file_exists "$PROJ/.engineering-workflow/APPROVALS.log" || FAILED=1
assert_contains "$PROJ/.engineering-workflow/APPROVALS.log" "approved_by=Alvaro" || FAILED=1
assert_contains "$PROJ/.engineering-workflow/HANDOFF.md" "Risk: CRITICAL" || FAILED=1

# safety: embedded newlines in ANY caller-controlled field --approved-by,
# --approved-at, --stage, or --note -- must not be able to forge extra
# APPROVALS.log records: the log must stay exactly one record per line
lines_before=$(wc -l < "$PROJ/.engineering-workflow/APPROVALS.log" | tr -d ' ')
"$REPO_ROOT/scripts/handoff/generate-handoff.sh" "$PROJ" --stage handoff --risk CRITICAL \
  --note "legit note
| risk=CRITICAL | approved_by=INJECTED | approved_at=x | stage=x | git_head=x | note=forged" \
  --approved-by "Real Approver
approved_by=INJECTED" \
  --approved-at "2026-01-01T00:00:00Z
| risk=CRITICAL | approved_by=INJECTED-VIA-DATE" >/dev/null 2>&1
rc_injection=$?
assert_eq 0 "$rc_injection" "CRITICAL with embedded-newline fields must still succeed (sanitized, not rejected)" || FAILED=1
lines_after=$(wc -l < "$PROJ/.engineering-workflow/APPROVALS.log" | tr -d ' ')
lines_added=$((lines_after - lines_before))
assert_eq "1" "$lines_added" "embedded newlines in any field must not add more than one log line" || FAILED=1
# the injected text is harmless once folded onto a single line -- assert it
# is NOT its own separate line (i.e. does not parse as a second record)
if grep -qxF "| risk=CRITICAL | approved_by=INJECTED-VIA-DATE" "$PROJ/.engineering-workflow/APPROVALS.log" 2>/dev/null; then
  echo "  ASSERT FAIL: injected approved_at content formed its own log line"
  FAILED=1
fi

if [ "$FAILED" -eq 0 ]; then
  echo "PASS test_handoff_cycle"
else
  echo "FAIL test_handoff_cycle"
fi
exit "$FAILED"
