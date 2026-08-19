#!/usr/bin/env bash
# Runs every tests/test_*.sh in isolation and reports a summary. Each test
# manages its own throwaway HOME/project — nothing here touches the real
# environment. Bash-only, no bats-core or other test-framework dependency.
set -u

TESTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

total=0
failed=0
failed_names=""

for t in "$TESTS_DIR"/test_*.sh; do
  name=$(basename "$t")
  total=$((total + 1))
  echo "=== $name ==="
  if bash "$t"; then
    :
  else
    failed=$((failed + 1))
    failed_names="$failed_names $name"
  fi
  echo
done

echo "-----------------------------------------"
echo "Total: $total  Failed: $failed"
if [ "$failed" -gt 0 ]; then
  echo "Failing tests:$failed_names"
  exit 1
fi
echo "All tests passed."
exit 0
