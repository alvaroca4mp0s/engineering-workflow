#!/usr/bin/env bash
# init-project.sh's .engineering-workflow/.gitignore handling must
# idempotently guarantee both `backups/` and `proposals/` are present,
# without ever overwriting or duplicating existing content. Covers the
# Codex review P2 finding: a pre-existing scoped .gitignore missing one
# or both entries used to be left untouched.
set -u
TESTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
. "$TESTS_DIR/lib/assert.sh"
. "$TESTS_DIR/lib/fixtures.sh"

FAILED=0
export HOME
HOME=$(ew_test_mk_home)

count_occurrences() {
  # count_occurrences <file> <exact-line> -> number of exact-line matches
  grep -xF "$2" "$1" 2>/dev/null | wc -l | tr -d ' '
}

# --- Case 1: gitignore inexistente (no pre-existing .engineering-workflow/) ---
PROJ1=$(mktemp -d)/proj
ew_test_mk_git_project "$PROJ1"
"$REPO_ROOT/scripts/init-project.sh" "$PROJ1" >/dev/null 2>&1
assert_file_exists "$PROJ1/.engineering-workflow/.gitignore" || FAILED=1
assert_contains "$PROJ1/.engineering-workflow/.gitignore" "backups/" || FAILED=1
assert_contains "$PROJ1/.engineering-workflow/.gitignore" "proposals/" || FAILED=1

# --- Case 2: gitignore existente sin ninguna entrada requerida ---
PROJ2=$(mktemp -d)/proj
ew_test_mk_git_project "$PROJ2"
mkdir -p "$PROJ2/.engineering-workflow"
printf '*.log\n' > "$PROJ2/.engineering-workflow/.gitignore"
out2=$("$REPO_ROOT/scripts/init-project.sh" "$PROJ2" 2>&1)
rc2=$?
assert_eq 0 "$rc2" "case2 exit code" || FAILED=1
assert_contains "$PROJ2/.engineering-workflow/.gitignore" "*.log" || FAILED=1
assert_contains "$PROJ2/.engineering-workflow/.gitignore" "backups/" || FAILED=1
assert_contains "$PROJ2/.engineering-workflow/.gitignore" "proposals/" || FAILED=1
n=$(count_occurrences "$PROJ2/.engineering-workflow/.gitignore" "backups/")
assert_eq "1" "$n" "case2 backups/ appears exactly once" || FAILED=1
n=$(count_occurrences "$PROJ2/.engineering-workflow/.gitignore" "proposals/")
assert_eq "1" "$n" "case2 proposals/ appears exactly once" || FAILED=1

# --- Case 3: gitignore existente con una sola entrada (backups/ only) ---
PROJ3=$(mktemp -d)/proj
ew_test_mk_git_project "$PROJ3"
mkdir -p "$PROJ3/.engineering-workflow"
printf 'backups/\n' > "$PROJ3/.engineering-workflow/.gitignore"
"$REPO_ROOT/scripts/init-project.sh" "$PROJ3" >/dev/null 2>&1
assert_contains "$PROJ3/.engineering-workflow/.gitignore" "backups/" || FAILED=1
assert_contains "$PROJ3/.engineering-workflow/.gitignore" "proposals/" || FAILED=1
n=$(count_occurrences "$PROJ3/.engineering-workflow/.gitignore" "backups/")
assert_eq "1" "$n" "case3 backups/ not duplicated" || FAILED=1
n=$(count_occurrences "$PROJ3/.engineering-workflow/.gitignore" "proposals/")
assert_eq "1" "$n" "case3 proposals/ appears exactly once" || FAILED=1

# --- Case 4: gitignore existente con ambas entradas -> byte-identical, no-op ---
PROJ4=$(mktemp -d)/proj
ew_test_mk_git_project "$PROJ4"
mkdir -p "$PROJ4/.engineering-workflow"
printf 'backups/\nproposals/\n' > "$PROJ4/.engineering-workflow/.gitignore"
sum_before=$(cksum "$PROJ4/.engineering-workflow/.gitignore")
out4=$("$REPO_ROOT/scripts/init-project.sh" "$PROJ4" 2>&1)
sum_after=$(cksum "$PROJ4/.engineering-workflow/.gitignore")
assert_eq "$sum_before" "$sum_after" "case4 file byte-identical when both entries already present" || FAILED=1
echo "$out4" | grep -qF "already has required entries" || { echo "  ASSERT FAIL: expected 'already has required entries' notice"; FAILED=1; }
echo "$out4" | grep -qF "added missing entry" && { echo "  ASSERT FAIL: should not report adding anything in case4"; FAILED=1; }

# --- Case 5: contenido custom preservado (multi-line, comments, blank lines) ---
PROJ5=$(mktemp -d)/proj
ew_test_mk_git_project "$PROJ5"
mkdir -p "$PROJ5/.engineering-workflow"
cat > "$PROJ5/.engineering-workflow/.gitignore" <<'EOF'
# my custom ignores
node_modules/
*.log

dist/
EOF
original_first_lines=$(head -n 5 "$PROJ5/.engineering-workflow/.gitignore")
"$REPO_ROOT/scripts/init-project.sh" "$PROJ5" >/dev/null 2>&1
new_first_lines=$(head -n 5 "$PROJ5/.engineering-workflow/.gitignore")
assert_eq "$original_first_lines" "$new_first_lines" "case5 original content preserved verbatim, in order" || FAILED=1
assert_contains "$PROJ5/.engineering-workflow/.gitignore" "backups/" || FAILED=1
assert_contains "$PROJ5/.engineering-workflow/.gitignore" "proposals/" || FAILED=1

# --- Case 6: segunda ejecucion sin cambios (idempotency of the merge itself) ---
PROJ6=$(mktemp -d)/proj
ew_test_mk_git_project "$PROJ6"
mkdir -p "$PROJ6/.engineering-workflow"
printf 'backups/\n' > "$PROJ6/.engineering-workflow/.gitignore"
"$REPO_ROOT/scripts/init-project.sh" "$PROJ6" >/dev/null 2>&1   # 1st run: adds proposals/
sum_after_first=$(cksum "$PROJ6/.engineering-workflow/.gitignore")
out6_second=$("$REPO_ROOT/scripts/init-project.sh" "$PROJ6" 2>&1)  # 2nd run: no-op
sum_after_second=$(cksum "$PROJ6/.engineering-workflow/.gitignore")
assert_eq "$sum_after_first" "$sum_after_second" "case6 second run leaves file byte-identical" || FAILED=1
echo "$out6_second" | grep -qF "added missing entry" && { echo "  ASSERT FAIL: second run should not add anything"; FAILED=1; }

if [ "$FAILED" -eq 0 ]; then
  echo "PASS test_gitignore_merge"
else
  echo "FAIL test_gitignore_merge"
fi
exit "$FAILED"
