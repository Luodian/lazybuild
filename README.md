# lazybuild

My development environment setup - Ghostty, Neovim (LazyVim), and OpenCode.

![screenshot](screenshot.png)

## Ghostty

Modern, fast terminal emulator.

**macOS**:
```bash
brew install --cask ghostty
```

**Linux**:
```bash
# Build from source
git clone https://github.com/ghostty-org/ghostty.git
cd ghostty
zig build -Doptimize=ReleaseFast
```

Config location: `~/.config/ghostty/config`

- [Ghostty Documentation](https://ghostty.org/docs)

---

## Neovim + LazyVim

### Install Neovim (>= 0.9.0)

**macOS**:
```bash
brew install neovim
```

**Linux**:
```bash
# Ubuntu/Debian
sudo add-apt-repository ppa:neovim-ppa/unstable
sudo apt update
sudo apt install neovim

# Arch
sudo pacman -S neovim
```

### Install Dependencies

**macOS**:
```bash
brew install git ripgrep fd lazygit node python3
pip3 install pynvim
npm install -g neovim
```

**Linux**:
```bash
sudo apt install git ripgrep fd-find nodejs npm python3-pip
pip3 install pynvim
npm install -g neovim
# lazygit - https://github.com/jesseduffield/lazygit#installation
```

### Installation

```bash
# Backup existing config (if any)
mv ~/.config/nvim ~/.config/nvim.bak
mv ~/.local/share/nvim ~/.local/share/nvim.bak
mv ~/.local/state/nvim ~/.local/state/nvim.bak
mv ~/.cache/nvim ~/.cache/nvim.bak

# Clone this config
git clone https://github.com/Luodian/lazybuild.git ~/.config/nvim

# Start Neovim - plugins will auto-install
nvim
```

### Update

```bash
cd ~/.config/nvim && git pull
```

- [LazyVim](https://lazyvim.github.io/)
- [Neovim](https://neovim.io/doc/)

---

## OpenCode + Oh-My-OpenCode

AI-powered coding assistant in terminal.

### Install OpenCode

```bash
# macOS/Linux
curl -fsSL https://opencode.ai/install.sh | bash

# Or via Go
go install github.com/opencode-ai/opencode@latest
```

### Install Oh-My-OpenCode

```bash
# Clone oh-my-opencode
git clone https://github.com/ohmyopencode/oh-my-opencode.git ~/.oh-my-opencode

# Add to shell config (~/.zshrc or ~/.bashrc)
echo 'source ~/.oh-my-opencode/oh-my-opencode.sh' >> ~/.zshrc
source ~/.zshrc
```

### Configuration

```bash
opencode auth
```

- [OpenCode](https://github.com/opencode-ai/opencode)
- [Oh-My-OpenCode](https://github.com/ohmyopencode/oh-my-opencode)
