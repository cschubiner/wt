#!/usr/bin/env bash
# Source this file in your shell rc:
#   source ~/wt/wt.sh

unalias wt 2>/dev/null || true

if [[ -n "${ZSH_VERSION:-}" ]]; then
  _WT_SH_SOURCE="${(%):-%N}"
else
  _WT_SH_SOURCE="${BASH_SOURCE[0]}"
fi
_WT_SH_DIR="$(cd "$(dirname "$_WT_SH_SOURCE")" && pwd -P)"
_WT_BIN="${WT_BIN:-$_WT_SH_DIR/wt}"

wt() {
  local wt_bin="${WT_BIN:-$_WT_BIN}"
  [[ -x "$wt_bin" ]] || {
    echo "wt: executable not found at $wt_bin (set WT_BIN to override)" >&2
    return 1
  }

  if [[ "${1:-}" == "cd" ]]; then
    shift
    local dir
    dir="$("$wt_bin" pickdir "$@")" || return $?
    [[ -n "$dir" ]] || return 0
    builtin cd "$dir" || return 1
    return 0
  fi

  if [[ "${1:-}" == "pick" ]]; then
    local action_file action_line action dir rc=0
    action_file="$(mktemp)"
    WT_PICK_ACTION_FILE="$action_file" "$wt_bin" "$@" || rc=$?

    if [[ "$rc" -eq 0 && -s "$action_file" ]]; then
      action_line="$(head -n1 "$action_file")"
      action="${action_line%%$'\t'*}"
      if [[ "$action_line" == *$'\t'* ]]; then
        dir="${action_line#*$'\t'}"
      else
        dir=""
      fi

      if [[ "$action" == "cd" && -n "$dir" ]]; then
        builtin cd "$dir" || rc=$?
      fi
    fi

    rm -f "$action_file"
    return "$rc"
  fi

  "$wt_bin" "$@"
}
