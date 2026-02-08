-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local map = vim.keymap.set

map("n", "<C-S-f>", function() require("grug-far").open() end, { desc = "Global Search & Replace" })
map("n", "<C-S-h>", function() require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } }) end, { desc = "Replace word under cursor" })
map("v", "<C-S-h>", function() require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } }) end, { desc = "Replace selection" })

map("n", "<leader>gb", function()
  local branches = vim.fn.systemlist("git branch --all --sort=-committerdate | sed 's/^[* ]*//' | sed 's#remotes/origin/##'")
  if vim.v.shell_error ~= 0 then
    vim.notify("Not a git repository", vim.log.levels.ERROR)
    return
  end
  vim.ui.select(branches, {
    prompt = "Switch to branch:",
  }, function(choice)
    if choice then
      local branch = choice:gsub("%s+", "")
      vim.fn.system("git checkout " .. vim.fn.shellescape(branch))
      if vim.v.shell_error == 0 then
        vim.notify("Switched to " .. branch, vim.log.levels.INFO)
        vim.cmd("checktime")
      else
        vim.notify("Failed to switch branch", vim.log.levels.ERROR)
      end
    end
  end)
end, { desc = "Git: Switch branch" })
