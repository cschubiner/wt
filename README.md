# wt

`wt` is a worktree session picker/launcher for AI coding workflows.

It supports:
- Zellij backend (default)
- tmux backend (fallback with `WT_BACKEND=tmux`)
- fuzzy picker with preview
- `codex` / `claude` target selection from picker (`Left` / `Right`)
- session rehydrate from known worktree directories

## Quick Start

```bash
git clone https://github.com/cschubiner/wt.git ~/wt
chmod +x ~/wt/wt ~/wt/wt-zellij
echo 'source ~/wt/wt.sh' >> ~/.zshrc
```

Then:

```bash
wt pick
wt cd
```

`wt cd` needs the shell wrapper (`wt.sh`) so the directory change applies in your current shell.
If you previously set `alias wt="$HOME/wt/wt"`, remove it because aliases bypass the wrapper function.
Inside `wt pick`, `Enter` cds into the selected directory, and `Ctrl-g` does the default attach behavior.

## Backend Selection

- default: `zellij`
- fallback: `WT_BACKEND=tmux wt pick`

## Commands

```text
wt here
wt codex
wt claude
wt pick
wt cd
wt pickdir
wt revive
wt ls
wt kill
```

## Notes

- Registry file default: `~/.wt_registry`
- Zellij metadata cache: `~/.wt_zellij/sessions/*.meta`
- Discovery roots (default):
  - `~/Downloads/worktrees`
  - `~/.codex/worktrees`
  - `~/.openclaw/workspace`
  - current directory

Override roots with:

```bash
export WT_DISCOVER_ROOTS="/abs/path/one:/abs/path/two"
```

## Maintenance

Prune unattached zellij server processes (keeps sessions with live `zellij attach` clients):

```bash
~/wt/scripts/kill-unattached-zellij-servers.sh
```

Useful options:

```bash
~/wt/scripts/kill-unattached-zellij-servers.sh --dry-run
~/wt/scripts/kill-unattached-zellij-servers.sh --ignore-unknown-clients
```

## License

MIT
