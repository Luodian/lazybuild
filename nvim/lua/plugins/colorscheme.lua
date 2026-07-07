-- Lucario colorscheme for Neovim, generated from the theme's 16-color palette
-- via mini.base16 so every highlight group (treesitter / LSP / plugins) stays
-- consistent. Pairs with the tmux + Ghostty + Claude Code Lucario setup.
-- Palette source: terminalcolors.com Lucario (default) == Ghostty theme file.
return {
  -- base16 generator: turns 16 hex colors into a full, consistent theme.
  { "nvim-mini/mini.base16", lazy = false, priority = 1000 },

  -- Apply our Lucario palette. Function form (not a string) because mini.base16
  -- applies the scheme directly — there is no named colorscheme file to load,
  -- and this overrides LazyVim's default tokyonight.
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        require("mini.base16").setup({
          palette = {
            base00 = "#2b3e50", -- background
            base01 = "#34495e", -- lighter bg (statusline, cursorline)
            base02 = "#3e556e", -- selection
            base03 = "#6d7f91", -- comments, line numbers
            base04 = "#b0bcca", -- dark foreground
            base05 = "#f8f8f2", -- default foreground
            base06 = "#fbfbf8", -- light foreground
            base07 = "#ffffff", -- lightest foreground
            base08 = "#e94b35", -- red (variables, errors)
            base09 = "#ff6541", -- orange (constants, numbers)
            base0A = "#f0cc04", -- yellow (classes, search)
            base0B = "#72cc5a", -- green (strings)
            base0C = "#8be0fd", -- teal (escapes, support)
            base0D = "#5c98cd", -- blue (functions)
            base0E = "#ca94ff", -- purple (keywords)
            base0F = "#e94b35", -- deprecated
          },
        })
      end,
    },
  },
}
