return {
  {
    "iamcco/markdown-preview.nvim",
    enabled = function()
      -- Avoid loading if node is unavailable (prevents noisy startup issues)
      return vim.fn.executable("node") == 1
    end,
    ft = { "markdown" },
    cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
    init = function()
      -- Scope strictly to markdown
      vim.g.mkdp_filetypes = { "markdown" }
      vim.g.mkdp_command_for_global = 0

      -- Localhost-only preview
      vim.g.mkdp_open_to_the_world = 0
      vim.g.mkdp_open_ip = "127.0.0.1"
      vim.g.mkdp_port = "8080"

      -- Use a local stylesheet that keeps wide tables readable.
      vim.g.mkdp_markdown_css = vim.fn.stdpath("config") .. "/styles/markdown-preview.css"

      -- Realtime preview, but keep behavior conservative/stable
      vim.g.mkdp_auto_start = 0
      vim.g.mkdp_auto_close = 1
      vim.g.mkdp_refresh_slow = 0
      vim.g.mkdp_combine_preview = 0
      vim.g.mkdp_echo_preview_url = 1
    end,
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown Preview Toggle" },
      { "<leader>ms", "<cmd>MarkdownPreviewStop<cr>", desc = "Markdown Preview Stop" },
    },
  },
}
