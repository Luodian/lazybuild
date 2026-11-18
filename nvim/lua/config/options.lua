-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Override LazyVim default (conceallevel=2).
-- We want raw markdown in the editor; preview only in browser.
vim.opt.conceallevel = 0

-- Absolute line numbers (override LazyVim's relativenumber default)
vim.opt.relativenumber = false

-- force system clipboard even over SSH (LazyVim disables it when SSH_CONNECTION is set)
vim.opt.clipboard = "unnamedplus"

-- Over SSH there is no usable system clipboard tool (the cc-clip xclip shim only
-- handles image paste), so copy through OSC 52 to the local terminal. Paste reads
-- the unnamed register instead of querying the terminal, which many terminals
-- answer slowly or not at all; terminal paste (Cmd-V) still works as usual.
if vim.env.SSH_CONNECTION then
  local osc52 = require("vim.ui.clipboard.osc52")
  local function paste()
    return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
  end
  vim.g.clipboard = {
    name = "OSC 52 (copy only)",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = paste, ["*"] = paste },
  }
end
