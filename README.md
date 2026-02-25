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
echo 'alias wt="$HOME/wt/wt"' >> ~/.zshrc
```

Then:

```bash
wt pick
```

## Backend Selection

- default: `zellij`
- fallback: `WT_BACKEND=tmux wt pick`

## Commands

```text
wt here
wt codex
wt claude
wt pick
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

## License

MIT
