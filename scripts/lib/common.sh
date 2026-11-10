#!/usr/bin/env bash
# Shared helpers for engineering-workflow scripts.
# bash 3.2 compatible on purpose (macOS ships 3.2 by default).
# Not meant to be executed directly — sourced by other scripts.

EW_MARKER_PREFIX="<!-- engineering-workflow:"

ew_log_info()  { printf '[ew] %s\n' "$*"; }
ew_log_warn()  { printf '[ew] WARN: %s\n' "$*" >&2; }
ew_log_error() { printf '[ew] ERROR: %s\n' "$*" >&2; }

# Keep the legacy pipe-separated log format: free text cannot contain a
# record separator (CR/LF) or field separator (|).
ew_sanitize_log_field() {
  printf '%s' "$1" | tr '\n\r|' '   '
}

# Validate exactly one version-1 contract. Unknown keys are allowed for
# forwards-compatible project extensions. Never execute declared commands.
ew_validate_contract() {
  local config="$1"
  ew_require_cmd jq "macOS: brew install jq | Debian/Ubuntu: apt-get install -y jq" || return 1
  if [ ! -f "$config" ]; then
    ew_log_error "missing workflow contract: $config"
    return 1
  fi
  if ! jq -e -s '
    def text: type == "string" and test("[^\\s]");
    length == 1 and (.[0] |
      type == "object" and
      .contract_version == "1" and
      (.project_name | text) and
      (.commands | type == "object") and
      (.commands.verify | text) and
      (.commands.test | text) and
      (.commands.build | text) and
      (.risk | type == "object") and
      (.risk.default | . == "LOW" or . == "MEDIUM" or . == "HIGH" or . == "CRITICAL") and
      (.spec_tool | type == "object") and
      (.spec_tool.type | . == "none" or . == "openspec") and
      (.spec_tool.path | text) and
      (.handoff | type == "object") and
      (.handoff.path | text)
    )' "$config" >/dev/null 2>&1; then
    ew_log_error "invalid workflow contract: $config (expected version 1 structure; see docs/OPERATIONS.md)"
    return 1
  fi
}

# Advisory only: compare commit identities, not short-hash string lengths.
# HANDOFF.md is disposable, so absence of metadata is not a hard error.
ew_warn_stale_handoff() {
  local target="$1" handoff="$2" recorded current resolved line
  recorded=""
  while IFS= read -r line; do
    case "$line" in
      '- Git HEAD: '*) recorded="${line#- Git HEAD: }"; break ;;
    esac
  done < "$handoff"
  [ -n "$recorded" ] || return 0
  current=$(git -C "$target" rev-parse --verify HEAD 2>/dev/null || printf 'no-commits')
  if [ "$recorded" = "no-commits" ]; then
    resolved="no-commits"
  else
    resolved=$(git -C "$target" rev-parse --verify "${recorded}^{commit}" 2>/dev/null || printf 'unresolved')
  fi
  if [ "$resolved" != "$current" ]; then
    ew_log_warn "stale handoff: recorded Git HEAD=$recorded differs from current Git HEAD=$current; prefer git/tests/docs"
  fi
}

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

# ew_is_own_symlink <path> -> exit 0 if <path> is a symlink whose target
# looks like one of this tool's dispatcher symlinks, exit 1 otherwise
# (including if <path> is not a symlink at all, or is a foreign symlink
# pointing elsewhere). Two checks, both required when the target exists:
# (1) the stored target path ends in "/bin/engineering-workflow", and
# (2) the target file actually contains this tool's dispatcher marker —
# path suffix alone could coincidentally match an unrelated file. Falls
# back to the path-suffix check alone for a broken symlink (target
# missing), since there's no file content left to verify.
ew_is_own_symlink() {
  path="$1"
  [ -L "$path" ] || return 1
  target=$(readlink "$path")
  case "$target" in
    */bin/engineering-workflow) : ;;
    *) return 1 ;;
  esac
  case "$target" in
    /*) resolved="$target" ;;
    *) resolved="$(dirname "$path")/$target" ;;
  esac
  if [ -e "$resolved" ]; then
    grep -qF "engineering-workflow:dispatcher-marker" "$resolved" 2>/dev/null
    return $?
  fi
  return 0
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
