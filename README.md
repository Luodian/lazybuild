# LazyBuild - LazyVim Configuration

## Features

### AI-Powered Git Commit
- `<leader>ac` - Generate commit message with OpenRouter API (manual confirm)
- `<leader>aC` - Auto-commit without confirmation
- Model: `bytedance-seed/seed-1.6-flash`
- Requires: `OPENROUTER_API_KEY` env var

### Git Branch Management
- `<leader>gb` - Quick branch switcher (sorted by recent commits)
- `<leader>gg` - LazyGit TUI (full git interface)

## Installation

```bash
# Copy plugins
cp -r nvim/lua/plugins/* ~/.config/nvim/lua/plugins/

# Copy keymaps
cp nvim/lua/config/keymaps.lua ~/.config/nvim/lua/config/

# Set API key
export OPENROUTER_API_KEY="sk-or-v1-xxxxx"
```

## File Structure

```
nvim/
├── lua/
│   ├── plugins/
│   │   ├── ai-commit.lua  # AI commit message generator
│   │   └── lazygit.lua    # LazyGit integration
│   └── config/
│       └── keymaps.lua    # Custom keybindings
```

## Dependencies

- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [lazygit](https://github.com/jesseduffield/lazygit) (install via `brew install lazygit`)
- OpenRouter API key (sign up at https://openrouter.ai)
