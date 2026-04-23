#!/usr/bin/env bash
# Bootstrap the lazybuild nvim + tmux config on a fresh machine.
# Idempotent: safe to re-run. Existing real files/dirs are backed up to
# "<path>.bak.<timestamp>" before being replaced by symlinks into this repo.
#
# Usage:  ./install.sh

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  • %s\n' "$*"; }
warn() { printf '\033[33m  ! %s\033[0m\n' "$*"; }
ok()   { printf '\033[32m  ✓ %s\033[0m\n' "$*"; }

# ─────────────────────────────────────────────────
# 1. Sanity checks
# ─────────────────────────────────────────────────
bold "[1/5] sanity checks"
if [[ "$(uname -s)" != "Darwin" ]]; then
  warn "non-macOS detected; Brewfile assumes Homebrew on macOS — review before continuing"
fi
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Install from https://brew.sh first." >&2
  exit 1
fi
ok "brew present at $(command -v brew)"

# ─────────────────────────────────────────────────
# 2. Brew packages
# ─────────────────────────────────────────────────
bold "[2/5] brew bundle"
brew bundle --file="$REPO/Brewfile"

# ─────────────────────────────────────────────────
# 3. Symlink configs
# ─────────────────────────────────────────────────
bold "[3/5] symlink configs"

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then
    if [[ "$(readlink "$dst")" == "$src" ]]; then
      ok "$dst -> $src (already linked)"
      return
    fi
    info "replacing existing symlink at $dst (was $(readlink "$dst"))"
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    local bak="${dst}.bak.${TS}"
    warn "backing up existing $dst -> $bak"
    mv "$dst" "$bak"
  fi
  ln -s "$src" "$dst"
  ok "$dst -> $src"
}

link "$REPO/nvim"             "$HOME/.config/nvim"
link "$REPO/tmux/tmux.conf"   "$HOME/.tmux.conf"
link "$REPO/bin/popuptmux"    "$HOME/.local/bin/popuptmux"

# ─────────────────────────────────────────────────
# 4. tmux plugin manager (TPM) + plugin sync
# ─────────────────────────────────────────────────
bold "[4/5] tmux plugin manager"
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ -d "$TPM_DIR/.git" ]]; then
  ok "TPM already cloned at $TPM_DIR"
else
  git clone --depth=1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
  ok "cloned TPM"
fi
# Install/update declared plugins headlessly when possible.
if [[ -x "$TPM_DIR/scripts/install_plugins.sh" ]]; then
  "$TPM_DIR/scripts/install_plugins.sh" >/dev/null && ok "TPM plugins installed"
fi

# ─────────────────────────────────────────────────
# 5. Neovim plugins (lazy.nvim sync)
# ─────────────────────────────────────────────────
bold "[5/5] neovim plugin sync (this can take a minute)"
nvim --headless "+Lazy! sync" +qa 2>&1 | tail -20 || warn "lazy sync exited non-zero — open nvim and run :Lazy"
ok "nvim plugins synced"

# ─────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────
bold "done."
cat <<EOF

Next steps:
  • Set OPENROUTER_API_KEY in your shell profile if you use <leader>ac:
        export OPENROUTER_API_KEY="sk-or-v1-..."
  • If you use Copilot:  open nvim, run  :Copilot auth
  • Optional Python provider for nvim plugins:
        python3 -m venv ~/.local/share/nvim/python3
        ~/.local/share/nvim/python3/bin/pip install pynvim
  • Reload tmux if it's already running:
        tmux source ~/.tmux.conf
        # then prefix + I  inside a tmux session to fetch plugins

Backups (if any) live at <path>.bak.${TS}
EOF
