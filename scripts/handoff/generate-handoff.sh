#!/usr/bin/env bash
# Generates/updates the disposable .engineering-workflow/HANDOFF.md for a
# project. CRITICAL risk requires --approved-by, and CRITICAL approvals
# are additionally appended to a durable, append-only
# .engineering-workflow/APPROVALS.log — never recorded only in HANDOFF.md
# (see methodology/RISK-MODEL.md).
#
# Usage:
#   generate-handoff.sh <target-dir> [--stage STAGE] [--risk LEVEL]
#                        [--note TEXT] [--approved-by NAME] [--approved-at WHEN]
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

EW_REPO_ROOT=$(ew_repo_root "${BASH_SOURCE[0]}")
EW_VERSION=$(cat "$EW_REPO_ROOT/VERSION")

TARGET="${1:-}"
if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
  ew_log_error "usage: generate-handoff.sh <target-dir> [--stage STAGE] [--risk LEVEL] [--note TEXT] [--approved-by NAME] [--approved-at WHEN]"
  exit 1
fi
TARGET=$(cd "$TARGET" && pwd)
shift

stage="unspecified"
risk=""
risk_provided=0
approval_provided=0
note=""
approved_by=""
approved_at=""

while [ $# -gt 0 ]; do
  case "$1" in
    --stage|--risk|--note|--approved-by|--approved-at)
      if [ $# -lt 2 ]; then
        ew_log_error "missing value for $1"
        exit 1
      fi ;;
  esac
  case "$1" in
    --stage) stage="$2"; shift 2 ;;
    --risk) risk="$2"; risk_provided=1; shift 2 ;;
    --note) note="$2"; shift 2 ;;
    --approved-by) approved_by="$2"; approval_provided=1; shift 2 ;;
    --approved-at) approved_at="$2"; shift 2 ;;
    *) ew_log_error "unknown argument: $1"; exit 1 ;;
  esac
done

EW_DIR="$TARGET/.engineering-workflow"
ew_validate_contract "$EW_DIR/workflow.config.json" || exit 1
if [ "$risk_provided" -eq 0 ]; then
  risk=$(jq -r '.risk.default' "$EW_DIR/workflow.config.json") || exit 1
fi

# CLI spelling has historically been lowercase; accept canonical uppercase
# too, but write one stable lowercase representation (no new lifecycle).
stage=$(printf '%s' "$stage" | tr '[:upper:]' '[:lower:]')
case "$stage" in
  discover|shape|spec|implement|verify|review|document|handoff|commit|init|unspecified) : ;;
  *) ew_log_error "invalid --stage '$stage' (see methodology/OVERVIEW.md)"; exit 1 ;;
esac

if [ "$approval_provided" -eq 1 ] && ! [[ "$approved_by" =~ [^[:space:]] ]]; then
  ew_log_error "--approved-by must contain a non-whitespace name"
  exit 1
fi

case "$risk" in
  LOW|MEDIUM|HIGH|CRITICAL) : ;;
  *) ew_log_error "invalid --risk '$risk' (must be LOW, MEDIUM, HIGH, or CRITICAL)"; exit 1 ;;
esac

# --- CRITICAL gate: require a durable approval, recorded outside HANDOFF.md
if [ "$risk" = "CRITICAL" ]; then
  if [ -z "$approved_by" ]; then
    ew_log_error "risk=CRITICAL requires --approved-by \"<name>\" (see methodology/RISK-MODEL.md)"
    ew_log_error "a CRITICAL handoff was NOT generated"
    exit 1
  fi
  [ -n "$approved_at" ] || approved_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  approvals_log="$EW_DIR/APPROVALS.log"
  git_head_for_log=$(git -C "$TARGET" rev-parse --short HEAD 2>/dev/null || echo "no-commits")
  # Sanitize every caller-controlled free-text field before writing it into
  # this line-oriented log: an embedded newline in any of them must never
  # be able to forge what looks like a second, separate approval record.
  safe_approved_by=$(ew_sanitize_log_field "$approved_by")
  safe_approved_at=$(ew_sanitize_log_field "$approved_at")
  safe_stage=$(ew_sanitize_log_field "$stage")
  safe_note=$(ew_sanitize_log_field "$note")
  printf '%s | risk=CRITICAL | approved_by=%s | approved_at=%s | stage=%s | git_head=%s | note=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$safe_approved_by" "$safe_approved_at" "$safe_stage" "$git_head_for_log" "$safe_note" \
    >> "$approvals_log" || exit 1
  ew_log_info "CRITICAL approval appended to durable log: $approvals_log"
fi

mkdir -p "$EW_DIR/backups" || exit 1

git_branch=$(git -C "$TARGET" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "no-branch")
git_head=$(git -C "$TARGET" rev-parse --short HEAD 2>/dev/null || echo "no-commits")
git_status=$(git -C "$TARGET" status --short 2>/dev/null || echo "")
[ -n "$git_status" ] || git_status="(clean)"

handoff_file="$EW_DIR/HANDOFF.md"
ew_backup_file "$handoff_file" "$EW_DIR/backups"

ew_render_template "$EW_REPO_ROOT/templates/HANDOFF.md.template" "$handoff_file" \
  "EW_VERSION=$EW_VERSION" \
  "GENERATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  "STAGE=$stage" \
  "RISK=$risk" \
  "GIT_BRANCH=$git_branch" \
  "GIT_HEAD=$git_head" \
  "NOTE=$note" \
  "GIT_STATUS=$git_status"

ew_log_info "wrote $handoff_file (stage=$stage risk=$risk)"
