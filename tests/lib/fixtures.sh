#!/usr/bin/env bash
# Test fixtures. Every test gets its own throwaway HOME and, where needed,
# its own throwaway git project — nothing touches the real environment.

# ew_test_mk_home -> prints path to a fresh, empty $HOME replacement
ew_test_mk_home() {
  dir=$(mktemp -d)/home
  mkdir -p "$dir"
  printf '%s' "$dir"
}

# ew_test_mk_git_project <dir> -> git-inits <dir> with one commit
ew_test_mk_git_project() {
  dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test User"
  printf '# demo\n' > "$dir/README.md"
  git -C "$dir" add README.md
  git -C "$dir" commit -q -m "initial commit"
}
