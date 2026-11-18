return {
  {
    "zbirenbaum/copilot.lua",
    opts = {
      -- Homebrew node@22 on the Mac, plain `node` from PATH elsewhere (Linux hosts).
      copilot_node_command = vim.fn.executable("/opt/homebrew/opt/node@22/bin/node") == 1
          and "/opt/homebrew/opt/node@22/bin/node"
        or "node",
    },
  },
}
