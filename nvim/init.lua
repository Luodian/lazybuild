local python_host = vim.fn.expand("~/.local/share/nvim/python3/bin/python")
if vim.fn.executable(python_host) == 1 then
  vim.g.python3_host_prog = python_host
end

-- Neovide (0.15.x)
-- NOTE: `neovide_background_color` is deprecated on macOS in 0.15.x.
-- Use opacity knobs instead.
--
-- Want: fully opaque (no transparency).
vim.g.neovide_opacity = 1.0
vim.g.neovide_normal_opacity = 1.0

-- Neovide may query settings before your init finishes; re-apply on enter to trigger its watcher.
vim.api.nvim_create_autocmd({ "VimEnter", "UIEnter" }, {
  callback = function()
    vim.g.neovide_opacity = 1.0
    vim.g.neovide_normal_opacity = 1.0
  end,
})

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
