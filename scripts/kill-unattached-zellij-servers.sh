#!/usr/bin/env bash
set -euo pipefail

# Kill zellij server processes that are not currently attached by a live
# `zellij attach ...` client process.
#
# Defaults are intentionally safe:
# - preserve sessions with detected live attach clients
# - abort if there are attach clients whose session name cannot be parsed
#   (override with --ignore-unknown-clients)
# - send TERM first, then KILL survivors
#
# Usage:
#   scripts/kill-unattached-zellij-servers.sh
#   scripts/kill-unattached-zellij-servers.sh --dry-run
#   scripts/kill-unattached-zellij-servers.sh --ignore-unknown-clients

DRY_RUN=0
FORCE_KILL=1
IGNORE_UNKNOWN_CLIENTS=0
WAIT_MS=400
MAX_LIST=30
QUIET=0

usage() {
  cat <<'EOF'
Usage: kill-unattached-zellij-servers.sh [options]

Kill zellij server processes for sessions that are not currently attached.

Options:
  -n, --dry-run                  Show what would be killed, do not kill
      --no-force                 Do not SIGKILL survivors after TERM
      --ignore-unknown-clients   Proceed even if some attach clients could not be parsed
      --wait-ms <ms>             Wait time between TERM and KILL (default: 400)
      --max-list <n>             Max rows shown in keep/kill previews (default: 30)
  -q, --quiet                    Minimal output
  -h, --help                     Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    --no-force)
      FORCE_KILL=0
      shift
      ;;
    --ignore-unknown-clients)
      IGNORE_UNKNOWN_CLIENTS=1
      shift
      ;;
    --wait-ms)
      [[ $# -ge 2 ]] || { echo "Missing value for --wait-ms" >&2; exit 1; }
      WAIT_MS="$2"
      shift 2
      ;;
    --max-list)
      [[ $# -ge 2 ]] || { echo "Missing value for --max-list" >&2; exit 1; }
      MAX_LIST="$2"
      shift 2
      ;;
    -q|--quiet)
      QUIET=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

[[ "$WAIT_MS" =~ ^[0-9]+$ ]] || { echo "--wait-ms must be an integer" >&2; exit 1; }
[[ "$MAX_LIST" =~ ^[0-9]+$ ]] || { echo "--max-list must be an integer" >&2; exit 1; }

tmp_dir="$(mktemp -d)"
attached_file="$tmp_dir/attached_sessions.txt"
unknown_client_file="$tmp_dir/unknown_clients.txt"
server_map_file="$tmp_dir/server_map.tsv"
keep_map_file="$tmp_dir/keep_map.tsv"
kill_map_file="$tmp_dir/kill_map.tsv"
kill_pids_file="$tmp_dir/kill_pids.txt"
trap 'rm -rf "$tmp_dir"' EXIT

: > "$attached_file"
: > "$unknown_client_file"
: > "$server_map_file"
: > "$keep_map_file"
: > "$kill_map_file"
: > "$kill_pids_file"

log() {
  [[ "$QUIET" == "1" ]] && return 0
  printf "%s\n" "$*"
}

# Parse session names from live attach client processes.
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  cmd="${line#* }"
  sess="$(
    printf '%s\n' "$cmd" | perl -ne '
      if (/\battach\b(.*)$/) {
        $rest = $1;
        @tok = split(/\s+/, $rest);
        for ($i = 0; $i < scalar(@tok); $i++) {
          $t = $tok[$i];
          next if $t eq "";
          if ($t =~ /^(--index|-i)$/) { $i++; next; }
          next if $t =~ /^-/;
          print "$t\n";
          exit;
        }
      }
    '
  )"
  if [[ -n "$sess" ]]; then
    printf "%s\n" "$sess" >> "$attached_file"
  else
    printf "%s\n" "$line" >> "$unknown_client_file"
  fi
done < <(pgrep -fl 'zellij attach|/zellij attach' || true)

sort -u "$attached_file" -o "$attached_file"

# Collect server pid -> session name mappings.
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  pid="${line%% *}"
  socket_path="$(
    printf '%s\n' "$line" | sed -E 's/^([0-9]+) .*--server[[:space:]]+([^[:space:]]+).*/\2/'
  )"
  sess="$(basename "$socket_path")"
  [[ -n "$pid" && -n "$sess" ]] || continue
  printf "%s\t%s\n" "$pid" "$sess" >> "$server_map_file"
done < <(pgrep -fl 'zellij --server ' || true)

# Partition keep vs kill based on attached session names.
while IFS=$'\t' read -r pid sess; do
  [[ -n "$pid" && -n "$sess" ]] || continue
  if grep -Fxq "$sess" "$attached_file"; then
    printf "%s\t%s\n" "$pid" "$sess" >> "$keep_map_file"
  else
    printf "%s\t%s\n" "$pid" "$sess" >> "$kill_map_file"
    printf "%s\n" "$pid" >> "$kill_pids_file"
  fi
done < "$server_map_file"

sort -u "$kill_pids_file" -o "$kill_pids_file"

attached_count="$(wc -l < "$attached_file" | tr -d ' ')"
unknown_client_count="$(wc -l < "$unknown_client_file" | tr -d ' ')"
server_count="$(wc -l < "$server_map_file" | tr -d ' ')"
keep_count="$(wc -l < "$keep_map_file" | tr -d ' ')"
kill_count="$(wc -l < "$kill_map_file" | tr -d ' ')"

log "attached_sessions=$attached_count"
log "server_processes=$server_count"
log "keep_servers=$keep_count"
log "kill_servers=$kill_count"
log "unknown_attach_clients=$unknown_client_count"

if [[ "$QUIET" != "1" ]]; then
  if [[ "$attached_count" -gt 0 ]]; then
    echo "--- attached sessions kept (first $MAX_LIST) ---"
    sed -n "1,${MAX_LIST}p" "$attached_file"
  fi
  if [[ "$kill_count" -gt 0 ]]; then
    echo "--- kill candidates pid<tab>session (first $MAX_LIST) ---"
    sed -n "1,${MAX_LIST}p" "$kill_map_file"
  fi
fi

if [[ "$unknown_client_count" -gt 0 && "$IGNORE_UNKNOWN_CLIENTS" != "1" ]]; then
  echo "Refusing to kill: found attach clients with unparseable session names." >&2
  echo "Re-run with --ignore-unknown-clients to proceed anyway." >&2
  echo "--- unknown attach clients (first $MAX_LIST) ---" >&2
  sed -n "1,${MAX_LIST}p" "$unknown_client_file" >&2
  exit 2
fi

if [[ "$kill_count" -eq 0 ]]; then
  log "No unattached zellij server processes to kill."
  exit 0
fi

if [[ "$DRY_RUN" == "1" ]]; then
  log "Dry run: no processes were killed."
  exit 0
fi

# TERM first.
xargs kill < "$kill_pids_file" 2>/dev/null || true

# Wait for graceful shutdown.
if [[ "$WAIT_MS" -gt 0 ]]; then
  perl -e 'select undef, undef, undef, ($ARGV[0] / 1000.0)' "$WAIT_MS"
fi

survivor_count=0
if [[ "$FORCE_KILL" == "1" ]]; then
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null || true
      survivor_count=$((survivor_count + 1))
    fi
  done < "$kill_pids_file"
fi

remaining_servers="$(pgrep -fl 'zellij --server ' | wc -l | tr -d ' ' || echo 0)"
remaining_clients="$(pgrep -fl 'zellij attach|/zellij attach' | wc -l | tr -d ' ' || echo 0)"

log "killed_unattached_servers=$kill_count"
log "force_killed_survivors=$survivor_count"
log "remaining_server_processes=$remaining_servers"
log "remaining_attach_clients=$remaining_clients"
