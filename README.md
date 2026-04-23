# lazybuild

Reproducible Neovim (LazyVim) + tmux setup. One command on a fresh macOS box.

## Install

```bash
git clone <this-repo> ~/Github/lazybuild
cd ~/Github/lazybuild
./install.sh
```

`install.sh` is idempotent. It:

1. `brew bundle` — installs neovim, tmux, lazygit, gh, ripgrep, fd, fzf, jq, bat, node@22.
2. Symlinks `~/.config/nvim`, `~/.tmux.conf`, `~/.local/bin/popuptmux` into this repo. Existing real files are moved to `<path>.bak.<timestamp>` first.
3. Clones [TPM](https://github.com/tmux-plugins/tpm) into `~/.tmux/plugins/tpm` and installs declared plugins.
4. Runs `nvim --headless +Lazy! sync` so plugins are ready on first open.

After install:
- Set `OPENROUTER_API_KEY` for `<leader>ac` AI commit.
- `:Copilot auth` inside nvim if you use Copilot.
- Optional python provider:
  ```bash
  python3 -m venv ~/.local/share/nvim/python3
  ~/.local/share/nvim/python3/bin/pip install pynvim
  ```

## Layout

```
lazybuild/
├── install.sh                  bootstrap script
├── Brewfile                    brew dependencies
├── nvim/                       → ~/.config/nvim
│   ├── init.lua
│   ├── lazyvim.json            LazyVim extras pin list
│   ├── lazy-lock.json          plugin version pins (committed for reproducibility)
│   ├── stylua.toml
│   ├── .neoconf.json
│   ├── styles/markdown-preview.css
│   └── lua/
│       ├── config/             options, keymaps, autocmds, lazy bootstrap
│       └── plugins/            plugin specs & overrides
├── tmux/
│   └── tmux.conf               → ~/.tmux.conf
└── bin/
    └── popuptmux               → ~/.local/bin/popuptmux  (used by tmux M-u / M-j)
```

## Custom keymaps & features

### Neovim
- `<leader>ac` — AI commit message via OpenRouter, opens floating buffer to edit before committing
- `<leader>aC` — AI commit, no confirmation (auto-commit)
- `<leader>gb` — Switch git branch (sorted by recent commits)
- `<leader>gw` / `<leader>gW` — Switch / remove git worktree
- `<leader>gg` — LazyGit TUI
- `<leader>xx` — Format current buffer with `jq`
- `<leader>/` (visual) — Grep selected text project-wide
- `/` (visual) — Search selected text in current buffer
- `<C-S-f>` / `<C-S-h>` — Global search & replace via grug-far
- `<leader>gp{l,c,d}` — Octo PR list / checkout / diff
- `<leader>gd{o,c,h,H}` — Diffview open / close / file history / branch history
- `<leader>mp` / `<leader>ms` — Markdown preview toggle / stop

### tmux (prefix `C-Space`)
- Zellij-style no-prefix nav: `M-h/j/k/l` move panes, `M-H/J/K/L` resize, `M-1..9` windows
- `M--` / `M-\\` split horizontal / vertical, `M-t` new window, `M-w` kill pane, `M-z` zoom
- `M-m` merge all windows into current, then cycle layouts; `M-M` reverse (break out)
- `prefix + w` — fzf window switcher with preview
- `prefix + j` / `M-j` — floating scratch terminal (popuptmux)
- `prefix + J` — floating opencode session
- `prefix + u` / `M-u` — fzf URL picker
- Auto-restore sessions across reboot via `tmux-resurrect` + `tmux-continuum`
- AI-named windows via `Luodian/tmux-autoname-agent-sessions`

## Updating

This repo is the source of truth. Edit files in place — they're symlinked to `~/.config/nvim` etc., so changes take effect immediately. After editing:

```bash
cd ~/Github/lazybuild
git diff
git commit -am "..."
git push
```

To pull on another machine: `git pull` and (if plugin set changed) `nvim +Lazy +qa`.

## Dependencies

Installed by `Brewfile`:
- neovim, tmux, git, lazygit, gh
- ripgrep, fd, fzf, jq, bat
- node@22 (Copilot pins this version)
