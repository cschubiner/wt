#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

home_dir="$tmpdir/home"
discover_root="$tmpdir/worktrees"
bin_dir="$tmpdir/bin"
mkdir -p "$home_dir" "$discover_root" "$bin_dir"

repo_dir="$discover_root/recent-repo"
mkdir -p "$repo_dir"
git -C "$repo_dir" init -q
expected_repo_dir="$(cd "$repo_dir" && pwd -P)"

cat > "$bin_dir/zellij" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "list-sessions" ]]; then
  echo "No active zellij sessions found."
  exit 0
fi

exit 0
EOF
chmod +x "$bin_dir/zellij"

output="$(
  HOME="$home_dir" \
  WT_DISCOVER_ROOTS="$discover_root" \
  WT_REGISTRY_FILE="$home_dir/.wt_registry" \
  WT_ZELLIJ_STATE_DIR="$home_dir/.wt_zellij" \
  PATH="$bin_dir:$PATH" \
  "$REPO_DIR/wt-zellij" _list \
  | sed -E 's/\x1b\[[0-9;]*m//g'
)"

if ! grep -Fq "$expected_repo_dir" <<<"$output"; then
  echo "FAIL: expected discovered directory to appear in wt-zellij _list output"
  echo "Expected: $expected_repo_dir"
  echo "Actual output:"
  printf '%s\n' "$output"
  exit 1
fi

echo "PASS: discovered directory appears in wt-zellij _list output"
