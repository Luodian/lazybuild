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
        vim.defer_fn(function()
          vim.cmd("checktime")
        end, 100)
      else
        vim.notify("Failed to switch branch", vim.log.levels.ERROR)
      end
    end
  end)
end, { desc = "Git: Switch branch" })

map("n", "<leader>gw", function()
  local worktrees = vim.fn.systemlist("git worktree list | awk '{print $1}'")
  if vim.v.shell_error ~= 0 or #worktrees == 0 then
    vim.notify("No worktrees found", vim.log.levels.WARN)
    return
  end
  vim.ui.select(worktrees, {
    prompt = "Switch to worktree:",
  }, function(choice)
    if choice then
      vim.cmd("cd " .. vim.fn.fnameescape(choice))
      vim.notify("Switched to worktree: " .. choice, vim.log.levels.INFO)
      vim.cmd("checktime")
    end
  end)
end, { desc = "Git: Switch worktree" })

map("n", "<leader>gW", function()
  local worktrees = vim.fn.systemlist("git worktree list | tail -n +2 | awk '{print $1}'")
  if #worktrees == 0 then
    vim.notify("No additional worktrees to remove", vim.log.levels.WARN)
    return
  end
  vim.ui.select(worktrees, {
    prompt = "Remove worktree:",
  }, function(choice)
    if choice then
      vim.fn.system("git worktree remove " .. vim.fn.shellescape(choice))
      if vim.v.shell_error == 0 then
        vim.notify("Removed worktree: " .. choice, vim.log.levels.INFO)
      else
        vim.notify("Failed to remove worktree", vim.log.levels.ERROR)
      end
    end
  end)
end, { desc = "Git: Remove worktree" })
