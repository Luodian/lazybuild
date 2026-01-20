local function activate_venv()
  local cwd = vim.fn.getcwd()
  local venv = cwd .. "/.venv"
  if vim.fn.isdirectory(venv) == 1 then
    vim.env.VIRTUAL_ENV = venv
    vim.env.PATH = venv .. "/bin:" .. vim.env.PATH
    vim.g.python3_host_prog = venv .. "/bin/python"
    return
  end
  vim.g.python3_host_prog = "/opt/homebrew/bin/python3"
end

activate_venv()
vim.api.nvim_create_autocmd("DirChanged", { callback = activate_venv })

require("config.lazy")
