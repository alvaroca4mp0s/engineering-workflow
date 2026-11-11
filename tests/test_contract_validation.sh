#!/usr/bin/env bash
# Version-1 structure, fail-closed init/generation, and extension compatibility.
set -eu
TESTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
. "$TESTS_DIR/lib/assert.sh"
. "$TESTS_DIR/lib/fixtures.sh"
. "$REPO_ROOT/scripts/lib/common.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME"
PROJ="$SANDBOX/project"
ew_test_mk_git_project "$PROJ"
"$REPO_ROOT/scripts/init-project.sh" "$PROJ" >/dev/null
CONFIG="$PROJ/.engineering-workflow/workflow.config.json"
cp "$CONFIG" "$SANDBOX/valid.json"
ew_validate_contract "$CONFIG"
jq '.extra = {"project_extension": true} | .spec_tool.type = "openspec"' "$SANDBOX/valid.json" > "$CONFIG"
ew_validate_contract "$CONFIG"
# Every mandatory leaf, plus representative wrong container types/enums.
for filter in \
  'del(.contract_version)' '.contract_version = 1' '.contract_version = "2"' \
  'del(.project_name)' '.project_name = " \t\n"' '.project_name = false' \
  'del(.commands)' '.commands = []' \
  'del(.commands.verify)' '.commands.verify = null' '.commands.verify = " "' \
  'del(.commands.test)' '.commands.test = 5' \
  'del(.commands.build)' '.commands.build = []' \
  'del(.risk)' '.risk = "HIGH"' 'del(.risk.default)' '.risk.default = "high"' \
  'del(.spec_tool)' 'del(.spec_tool.type)' '.spec_tool.type = "unknown"' \
  'del(.spec_tool.path)' '.spec_tool.path = {}' \
  'del(.handoff)' 'del(.handoff.path)' '.handoff.path = ""' \
  '. = null' '. = []'; do
  jq "$filter" "$SANDBOX/valid.json" > "$CONFIG"
  before=$(cksum "$CONFIG")
  handoff_before=$(cksum "$PROJ/.engineering-workflow/HANDOFF.md")
  if "$REPO_ROOT/scripts/init-project.sh" "$PROJ" > "$SANDBOX/out" 2>&1; then
    echo "invalid contract accepted by init: $filter"; exit 1
  fi
  assert_contains "$SANDBOX/out" 'invalid workflow contract'
  assert_eq "$before" "$(cksum "$CONFIG")" 'invalid contract preserved'
  if "$REPO_ROOT/scripts/handoff/generate-handoff.sh" "$PROJ" --risk CRITICAL --approved-by QA > "$SANDBOX/out" 2>&1; then
    echo "invalid contract accepted by generator: $filter"; exit 1
  fi
  assert_contains "$SANDBOX/out" 'invalid workflow contract'
  assert_eq "$handoff_before" "$(cksum "$PROJ/.engineering-workflow/HANDOFF.md")"
  assert_file_missing "$PROJ/.engineering-workflow/APPROVALS.log"
done
for content in '' '{broken' '{} {}'; do
  printf '%s' "$content" > "$CONFIG"
  if ew_validate_contract "$CONFIG" > "$SANDBOX/out" 2>&1; then
    echo 'invalid JSON stream accepted'; exit 1
  fi
  assert_contains "$SANDBOX/out" 'invalid workflow contract'
done
rm "$CONFIG"
if "$REPO_ROOT/scripts/handoff/generate-handoff.sh" "$PROJ" > "$SANDBOX/out" 2>&1; then
  echo 'missing contract accepted'; exit 1
fi
assert_contains "$SANDBOX/out" 'missing workflow contract'
cp "$SANDBOX/valid.json" "$CONFIG"
"$REPO_ROOT/scripts/init-project.sh" "$PROJ" >/dev/null
printf 'PASS test_contract_validation\n'
