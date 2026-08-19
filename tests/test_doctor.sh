#!/usr/bin/env bash
# doctor.sh: exits 0 when required deps present (regardless of optional
# capabilities being absent), exits 1 when a required dep (jq) is missing,
# and correctly reports codex-plugin-cc presence/absence.
set -u
TESTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
. "$TESTS_DIR/lib/assert.sh"
. "$TESTS_DIR/lib/fixtures.sh"

FAILED=0
export HOME
HOME=$(ew_test_mk_home)

# --- scenario 1: full environment, nothing installed yet, no optional
#     capabilities present (fresh sandbox HOME has no ~/.claude) ----------
out=$("$REPO_ROOT/scripts/doctor.sh" 2>&1)
rc=$?
assert_eq 0 "$rc" "doctor exit code with git+jq present" || FAILED=1
echo "$out" | grep -qF "not installed via install.sh yet" || { echo "  ASSERT FAIL: expected 'not installed' notice"; FAILED=1; }
echo "$out" | grep -qF "codex-plugin-cc not detected" || { echo "  ASSERT FAIL: expected plugin-absent notice"; FAILED=1; }
echo "$out" | grep -qF "Result: OK" || { echo "  ASSERT FAIL: expected overall OK"; FAILED=1; }

# --- scenario 2: codex-plugin-cc IS present (faked) ----------------------
mkdir -p "$HOME/.claude/plugins"
cat > "$HOME/.claude/plugins/installed_plugins.json" <<'EOF'
{"version":2,"plugins":{"codex@openai-codex":[{"scope":"user","version":"1.0.6"}]}}
EOF
out2=$("$REPO_ROOT/scripts/doctor.sh" 2>&1)
echo "$out2" | grep -qF "codex-plugin-cc detected" || { echo "  ASSERT FAIL: expected plugin-detected notice"; FAILED=1; }

# --- scenario 3: required dependency (jq) missing -------------------------
FAKE_BIN=$(mktemp -d)
for tool in bash git uname date grep basename dirname mkdir cat cp head env sh; do
  real=$(command -v "$tool" 2>/dev/null) || continue
  ln -sf "$real" "$FAKE_BIN/$tool"
done
# deliberately do NOT link jq
out3=$(PATH="$FAKE_BIN" "$REPO_ROOT/scripts/doctor.sh" 2>&1)
rc3=$?
assert_eq 1 "$rc3" "doctor exit code with jq missing" || FAILED=1
echo "$out3" | grep -qF "jq not found" || { echo "  ASSERT FAIL: expected 'jq not found'"; FAILED=1; }
echo "$out3" | grep -qF "Result: FAIL" || { echo "  ASSERT FAIL: expected overall FAIL"; FAILED=1; }

if [ "$FAILED" -eq 0 ]; then
  echo "PASS test_doctor"
else
  echo "FAIL test_doctor"
fi
exit "$FAILED"
