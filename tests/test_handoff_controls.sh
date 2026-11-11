#!/usr/bin/env bash
# Risk defaults/overrides, stage allowlist, blank approvals, field injection,
# and stale HEAD warnings. Runs under Bash 3.2 without external frameworks.
set -eu
TESTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
. "$TESTS_DIR/lib/assert.sh"
. "$TESTS_DIR/lib/fixtures.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME"
PROJ="$SANDBOX/project"
ew_test_mk_git_project "$PROJ"
GEN="$REPO_ROOT/scripts/handoff/generate-handoff.sh"
READ="$REPO_ROOT/scripts/handoff/read-handoff.sh"
"$REPO_ROOT/scripts/init-project.sh" "$PROJ" >/dev/null
EW="$PROJ/.engineering-workflow"
for risk in LOW MEDIUM HIGH CRITICAL; do
  jq --arg risk "$risk" '.risk.default = $risk' "$EW/workflow.config.json" > "$SANDBOX/config"
  cp "$SANDBOX/config" "$EW/workflow.config.json"
  if [ "$risk" = CRITICAL ]; then
    before=$(cksum "$EW/HANDOFF.md")
    if "$GEN" "$PROJ" > "$SANDBOX/out" 2>&1; then exit 1; fi
    assert_eq "$before" "$(cksum "$EW/HANDOFF.md")"
    assert_file_missing "$EW/APPROVALS.log"
    "$GEN" "$PROJ" --approved-by QA >/dev/null
  else
    "$GEN" "$PROJ" >/dev/null
  fi
  assert_contains "$EW/HANDOFF.md" "Risk: $risk"
done
"$GEN" "$PROJ" --risk LOW >/dev/null
assert_contains "$EW/HANDOFF.md" 'Risk: LOW'
assert_contains "$EW/HANDOFF.md" 'Stage: unspecified'
for stage in discover shape spec implement verify review document handoff commit init unspecified IMPLEMENT; do
  "$GEN" "$PROJ" --risk LOW --stage "$stage" >/dev/null
done
assert_contains "$EW/HANDOFF.md" 'Stage: implement'
for stage in invalid '' 'handoff / commit' $'handoff\n| approved_by=forged'; do
  before=$(cksum "$EW/HANDOFF.md" "$EW/APPROVALS.log")
  if "$GEN" "$PROJ" --stage "$stage" --risk CRITICAL --approved-by QA > "$SANDBOX/out" 2>&1; then exit 1; fi
  assert_contains "$SANDBOX/out" 'invalid --stage'
  assert_eq "$before" "$(cksum "$EW/HANDOFF.md" "$EW/APPROVALS.log")"
done
for approver in '' '   ' $'\t\r\n '; do
  before=$(cksum "$EW/HANDOFF.md" "$EW/APPROVALS.log")
  if "$GEN" "$PROJ" --approved-by "$approver" > "$SANDBOX/out" 2>&1; then exit 1; fi
  assert_contains "$SANDBOX/out" 'must contain a non-whitespace name'
  assert_eq "$before" "$(cksum "$EW/HANDOFF.md" "$EW/APPROVALS.log")"
done
# Supplied blank approvers are invalid even for a non-CRITICAL override.
if "$GEN" "$PROJ" --risk LOW --approved-by ' ' >/dev/null 2>&1; then exit 1; fi
for option in --stage --risk --note --approved-by --approved-at; do
  if "$GEN" "$PROJ" "$option" > "$SANDBOX/out" 2>&1; then exit 1; fi
  assert_contains "$SANDBOX/out" 'missing value'
done
if "$GEN" "$PROJ" --risk '' >/dev/null 2>&1; then exit 1; fi
before_lines=$(wc -l < "$EW/APPROVALS.log")
"$GEN" "$PROJ" --stage HANDOFF --approved-by $' QA | approved_by=FORGED\n\r' \
  --approved-at $'date | git_head=FORGED\r\n' --note $'note | risk=LOW\n\r' >/dev/null
assert_eq "$((before_lines + 1))" "$(wc -l < "$EW/APPROVALS.log" | tr -d ' ')"
# Exactly seven fields remain, and the trusted field positions are intact.
tail -1 "$EW/APPROVALS.log" > "$SANDBOX/record"
assert_eq 6 "$(tr -cd '|' < "$SANDBOX/record" | wc -c | tr -d ' ')"
assert_contains "$SANDBOX/record" '| stage=handoff | git_head='
assert_eq 0 "$(tr -cd '\r' < "$SANDBOX/record" | wc -c | tr -d ' ')"
"$READ" "$PROJ" > "$SANDBOX/read" 2> "$SANDBOX/warnings"
assert_eq '' "$(< "$SANDBOX/warnings")" 'current short HEAD must not warn'
# Full hash of the same commit must also compare equal.
head=$(git -C "$PROJ" rev-parse HEAD)
printf -- '- Git HEAD: %s\n' "$head" > "$EW/HANDOFF.md"
"$READ" "$PROJ" > /dev/null 2> "$SANDBOX/warnings"
assert_eq '' "$(< "$SANDBOX/warnings")"
git -C "$PROJ" commit -q --allow-empty -m 'advance HEAD'
"$READ" "$PROJ" > "$SANDBOX/read" 2> "$SANDBOX/warnings"
assert_contains "$SANDBOX/warnings" 'stale handoff'
assert_contains "$SANDBOX/read" "$head"
"$GEN" "$PROJ" --risk LOW >/dev/null
"$READ" "$PROJ" >/dev/null 2> "$SANDBOX/warnings"
assert_eq '' "$(< "$SANDBOX/warnings")" 'regeneration clears warning'
# Legacy metadata missing: still readable, no invented comparison.
printf '# Legacy handoff\n' > "$EW/HANDOFF.md"
"$READ" "$PROJ" >/dev/null 2> "$SANDBOX/warnings"
assert_eq '' "$(< "$SANDBOX/warnings")"
printf -- '- Git HEAD: deadbeef\n' > "$EW/HANDOFF.md"
"$READ" "$PROJ" >/dev/null 2> "$SANDBOX/warnings"
assert_contains "$SANDBOX/warnings" 'stale handoff'
# Unborn repository: no false warning until its first commit exists.
UNBORN="$SANDBOX/unborn"
mkdir -p "$UNBORN/.engineering-workflow"
git -C "$UNBORN" init -q
cp "$EW/workflow.config.json" "$UNBORN/.engineering-workflow/workflow.config.json"
# Denied approval must not even create backups/ on a fresh target.
if "$GEN" "$UNBORN" --approved-by $' \t\n' >/dev/null 2>&1; then exit 1; fi
[ ! -e "$UNBORN/.engineering-workflow/backups" ]
assert_file_missing "$UNBORN/.engineering-workflow/HANDOFF.md"
assert_file_missing "$UNBORN/.engineering-workflow/APPROVALS.log"
"$GEN" "$UNBORN" --risk LOW >/dev/null
"$READ" "$UNBORN" >/dev/null 2> "$SANDBOX/warnings"
assert_eq '' "$(< "$SANDBOX/warnings")"
git -C "$UNBORN" -c user.name=QA -c user.email=qa@example.com commit -q --allow-empty -m first
"$READ" "$UNBORN" >/dev/null 2> "$SANDBOX/warnings"
assert_contains "$SANDBOX/warnings" 'stale handoff'
printf 'PASS test_handoff_controls\n'
