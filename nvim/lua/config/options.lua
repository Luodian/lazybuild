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
