#!/usr/bin/env bash
# Prepares a project to use the engineering-workflow methodology, WITHOUT
# destroying existing configuration.
#
# Exit codes:
#   0 = done, no conflicts (includes idempotent no-op re-runs)
#   1 = hard error (bad target, not a git repo, missing dependency)
#   2 = completed, but one or more managed files already existed as
#       foreign (non-engineering-workflow) files — proposals were written,
#       nothing was overwritten, manual resolution required.
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

EW_REPO_ROOT=$(ew_repo_root "${BASH_SOURCE[0]}")
EW_VERSION=$(cat "$EW_REPO_ROOT/VERSION")

ew_require_cmd git "https://git-scm.com/downloads" || exit 1
ew_require_cmd jq  "macOS: brew install jq | Debian/Ubuntu: apt-get install -y jq" || exit 1

TARGET_ARG="${1:-.}"
if [ ! -d "$TARGET_ARG" ]; then
  ew_log_error "target directory does not exist: $TARGET_ARG"
  exit 1
fi
TARGET=$(cd "$TARGET_ARG" && pwd)

if ! git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  ew_log_error "not a git repository: $TARGET"
  ew_log_error "run 'git init' in the project first, then re-run init-project.sh"
  exit 1
fi

EW_DIR="$TARGET/.engineering-workflow"
mkdir -p "$EW_DIR/backups" "$EW_DIR/proposals"

ew_log_info "target: $TARGET"

# --- .gitignore (scoped to .engineering-workflow/, never touches the
#     project's own root .gitignore) — keeps backups/ and proposals/,
#     which have no retention policy, out of git history. If the file
#     doesn't exist yet, it's created from the template. If it already
#     exists (ours or foreign), existing content is preserved as-is and
#     only the required entries missing from it (exact-line match) are
#     appended — never duplicated, never reordered. ----------------------
gitignore_file="$EW_DIR/.gitignore"
if [ ! -f "$gitignore_file" ]; then
  cp "$EW_REPO_ROOT/templates/EW-GITIGNORE.template" "$gitignore_file"
  ew_log_info "created $gitignore_file (ignores backups/ and proposals/)"
else
  gitignore_added=0
  for gitignore_entry in "backups/" "proposals/"; do
    if grep -qxF "$gitignore_entry" "$gitignore_file" 2>/dev/null; then
      : # already present, leave as-is
    else
      ew_ensure_line "$gitignore_file" "$gitignore_entry"
      ew_log_info "added missing entry to $gitignore_file: $gitignore_entry"
      gitignore_added=$((gitignore_added + 1))
    fi
  done
  if [ "$gitignore_added" -eq 0 ]; then
    ew_log_info "$gitignore_file already has required entries — left untouched"
  fi
fi

# --- VERSION -----------------------------------------------------------
if [ -f "$EW_DIR/VERSION" ]; then
  existing_version=$(cat "$EW_DIR/VERSION")
  if [ "$existing_version" != "$EW_VERSION" ]; then
    ew_log_warn "project already initialized with version $existing_version (this clone is $EW_VERSION)"
    ew_log_warn "init-project.sh does not upgrade — see docs/MAINTENANCE.md"
  else
    ew_log_info "VERSION up to date ($EW_VERSION)"
  fi
else
  echo "$EW_VERSION" > "$EW_DIR/VERSION"
  ew_log_info "wrote $EW_DIR/VERSION ($EW_VERSION)"
fi

# --- workflow.config.json -----------------------------------------------
config_file="$EW_DIR/workflow.config.json"
if [ -f "$config_file" ]; then
  if jq empty "$config_file" >/dev/null 2>&1; then
    ew_log_info "workflow.config.json already present and valid — left untouched"
  else
    ew_log_warn "workflow.config.json exists but is not valid JSON — left untouched, please fix manually"
  fi
else
  project_name=$(basename "$TARGET")
  jq --arg name "$project_name" '.project_name = $name' \
    "$EW_REPO_ROOT/contract/workflow.config.example.json" > "$config_file"
  ew_log_info "created $config_file (edit commands.verify/test/build before relying on VERIFY)"
fi

# --- managed files (AGENTS.md, CLAUDE.md) -------------------------------
conflicts=0
created=0
skipped=0

init_managed_file() {
  dest_name="$1"
  template="$2"
  dest="$TARGET/$dest_name"

  if [ -f "$dest" ]; then
    if ew_has_marker "$dest"; then
      ew_log_info "$dest_name already managed by engineering-workflow — left untouched"
      skipped=$((skipped + 1))
    else
      ew_log_warn "$dest_name already exists and is NOT managed by engineering-workflow — CONFLICT"
      ew_backup_file "$dest" "$EW_DIR/backups"
      ew_render_template "$template" "$EW_DIR/proposals/${dest_name}.proposed" "EW_VERSION=$EW_VERSION"
      ew_log_warn "  backed up existing file to: $EW_DIR/backups/"
      ew_log_warn "  wrote proposal to:          $EW_DIR/proposals/${dest_name}.proposed"
      ew_log_warn "  no changes were made to $dest_name — resolve manually"
      conflicts=$((conflicts + 1))
    fi
  else
    ew_render_template "$template" "$dest" "EW_VERSION=$EW_VERSION"
    ew_log_info "created $dest_name"
    created=$((created + 1))
  fi
}

init_managed_file "AGENTS.md" "$EW_REPO_ROOT/adapters/codex/AGENTS.md.template"
init_managed_file "CLAUDE.md" "$EW_REPO_ROOT/adapters/claude-code/CLAUDE.md.template"

# --- HANDOFF.md ----------------------------------------------------------
handoff_file="$EW_DIR/HANDOFF.md"
if [ -f "$handoff_file" ]; then
  ew_log_info "HANDOFF.md already present — left untouched"
else
  "$SCRIPT_DIR/handoff/generate-handoff.sh" "$TARGET" \
    --stage init --risk LOW \
    --note "Project initialized by engineering-workflow init-project.sh v$EW_VERSION." \
    >/dev/null
  ew_log_info "created $handoff_file"
fi

echo
ew_log_info "summary: created=$created skipped(already-managed)=$skipped conflicts=$conflicts"

if [ "$conflicts" -gt 0 ]; then
  ew_log_warn "init finished WITH CONFLICTS — review $EW_DIR/proposals/ and resolve manually before relying on the adapters"
  exit 2
fi

ew_log_info "init complete"
exit 0
