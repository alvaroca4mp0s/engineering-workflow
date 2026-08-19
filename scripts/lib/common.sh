#!/usr/bin/env bash
# Shared helpers for engineering-workflow scripts.
# bash 3.2 compatible on purpose (macOS ships 3.2 by default).
# Not meant to be executed directly — sourced by other scripts.

EW_MARKER_PREFIX="<!-- engineering-workflow:"

ew_log_info()  { printf '[ew] %s\n' "$*"; }
ew_log_warn()  { printf '[ew] WARN: %s\n' "$*" >&2; }
ew_log_error() { printf '[ew] ERROR: %s\n' "$*" >&2; }

# ew_require_cmd <cmd> <install-hint>
# Exits 1 if <cmd> is not on PATH.
ew_require_cmd() {
  cmd="$1"
  hint="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    ew_log_error "required dependency not found: $cmd"
    if [ -n "$hint" ]; then
      ew_log_error "  install hint: $hint"
    fi
    return 1
  fi
  return 0
}

# ew_os_name -> prints one of: macos, linux, unknown
ew_os_name() {
  case "$(uname -s)" in
    Darwin) printf 'macos\n' ;;
    Linux)  printf 'linux\n' ;;
    *)      printf 'unknown\n' ;;
  esac
}

# ew_repo_root -> prints the absolute path of the engineering-workflow
# clone this script lives in, given $1 = path to the calling script.
ew_repo_root() {
  script_path="$1"
  script_dir=$(cd "$(dirname "$script_path")" && pwd)
  # scripts/ and scripts/handoff/ are both one or two levels under repo root
  if [ -f "$script_dir/../VERSION" ]; then
    (cd "$script_dir/.." && pwd)
  elif [ -f "$script_dir/../../VERSION" ]; then
    (cd "$script_dir/../.." && pwd)
  else
    ew_log_error "could not locate engineering-workflow repo root from $script_path"
    return 1
  fi
}

# ew_has_marker <file> -> exit 0 if file contains an engineering-workflow
# managed marker comment, exit 1 otherwise (including if file is missing).
ew_has_marker() {
  file="$1"
  [ -f "$file" ] || return 1
  grep -qF "$EW_MARKER_PREFIX" "$file" 2>/dev/null
}

# ew_ensure_line <file> <line> -> ensures <line> is present in <file> as
# an exact line (grep -xF match). Appends it if missing; no-op (and no
# duplicate) if already present. Preserves all existing content and
# ordering. Creates <file> (and its parent dir) if it does not exist.
# Ensures the file ends with a newline before appending, so the new line
# never gets concatenated onto an existing last line.
ew_ensure_line() {
  file="$1"
  line="$2"
  if [ -f "$file" ] && grep -qxF "$line" "$file" 2>/dev/null; then
    return 0
  fi
  mkdir -p "$(dirname "$file")"
  if [ -f "$file" ] && [ -s "$file" ]; then
    last_byte=$(tail -c 1 "$file")
    [ -n "$last_byte" ] && printf '\n' >> "$file"
  fi
  printf '%s\n' "$line" >> "$file"
}

# ew_backup_file <file> <backup-dir> -> copies <file> into <backup-dir>
# with a timestamp suffix. No-op if <file> does not exist.
ew_backup_file() {
  file="$1"
  backup_dir="$2"
  [ -f "$file" ] || return 0
  mkdir -p "$backup_dir"
  ts=$(date +%Y%m%d%H%M%S)
  base=$(basename "$file")
  cp "$file" "$backup_dir/${base}.bak-${ts}"
}

# ew_render_template <template-file> <output-file> VAR=value VAR2=value ...
# Placeholder substitution using pure bash string replacement (no sed/awk
# escaping pitfalls, and safely handles multi-line values).
# Placeholders in the template look like __NAME__. VAR=value pairs whose
# value spans multiple lines are supported.
ew_render_template() {
  template="$1"
  output="$2"
  shift 2
  content=$(cat "$template")
  for pair in "$@"; do
    key="${pair%%=*}"
    val="${pair#*=}"
    placeholder="__${key}__"
    content="${content//$placeholder/$val}"
  done
  printf '%s\n' "$content" > "$output"
}
