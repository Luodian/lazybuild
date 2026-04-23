-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Disable Markdown concealment (URL/link hiding) — keep raw text visible.
-- Uses BufEnter in addition to FileType so late-loading plugins can't override.
vim.api.nvim_create_autocmd({ "FileType", "BufEnter", "BufWinEnter" }, {
  pattern = { "markdown", "markdown.mdx" },
  callback = function()
    vim.opt_local.conceallevel = 0
    vim.opt_local.concealcursor = ""
  end,
})

local jq_group = vim.api.nvim_create_augroup("jq_json_format", { clear = true })

local function format_json_with_jq(bufnr)
  if vim.fn.executable("jq") ~= 1 then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local input = table.concat(lines, "\n")

  if #lines > 0 then
    input = input .. "\n"
  end

  local output = vim.fn.systemlist({ "jq", "." }, input)
  if vim.v.shell_error ~= 0 then
    vim.notify("jq format failed - invalid JSON", vim.log.levels.WARN)
    return
  end

  if output[#output] == "" then
    table.remove(output, #output)
  end

  local view = vim.fn.winsaveview()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, output)
  vim.fn.winrestview(view)
end

vim.api.nvim_create_user_command("JqFormat", function()
  format_json_with_jq(vim.api.nvim_get_current_buf())
end, { desc = "Format current buffer with jq" })

vim.api.nvim_create_autocmd("BufWritePre", {
  group = jq_group,
  pattern = "*.json",
  callback = function(args)
    format_json_with_jq(args.buf)
  end,
})
