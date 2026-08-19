#!/usr/bin/env bash
# Minimal, dependency-free assertion helpers for tests/test_*.sh.
# Intentionally not using `set -e` here — callers check return codes
# explicitly so a failed assertion can be reported without killing the
# whole test file on the first failure.

assert_eq() {
  expected="$1"; actual="$2"; msg="${3:-}"
  if [ "$expected" != "$actual" ]; then
    echo "  ASSERT FAIL: expected [$expected] got [$actual] $msg" >&2
    return 1
  fi
}

assert_file_exists() {
  if [ ! -f "$1" ]; then
    echo "  ASSERT FAIL: file missing: $1" >&2
    return 1
  fi
}

assert_file_missing() {
  if [ -f "$1" ]; then
    echo "  ASSERT FAIL: file should not exist: $1" >&2
    return 1
  fi
}

assert_contains() {
  file="$1"; needle="$2"
  if ! grep -qF "$needle" "$file" 2>/dev/null; then
    echo "  ASSERT FAIL: '$needle' not found in $file" >&2
    return 1
  fi
}

assert_not_contains() {
  file="$1"; needle="$2"
  if grep -qF "$needle" "$file" 2>/dev/null; then
    echo "  ASSERT FAIL: '$needle' unexpectedly found in $file" >&2
    return 1
  fi
}
