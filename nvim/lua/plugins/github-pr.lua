return {
  {
    "pwntester/octo.nvim",
    cmd = "Octo",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      { "<leader>gpl", "<cmd>Octo pr list<cr>", desc = "List PRs" },
      { "<leader>gpc", "<cmd>Octo pr checkout<cr>", desc = "Checkout PR" },
      { "<leader>gpd", "<cmd>Octo pr diff<cr>", desc = "PR Diff" },
      { "<leader>grs", "<cmd>Octo review start<cr>", desc = "Start Review" },
      { "<leader>grS", "<cmd>Octo review submit<cr>", desc = "Submit Review" },
      { "<leader>grc", "<cmd>Octo review comments<cr>", desc = "Review Comments" },
    },
    opts = {
      default_remote = { "origin", "upstream" },
    },
  },
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      { "<leader>gdo", "<cmd>DiffviewOpen<cr>", desc = "Diffview Open" },
      { "<leader>gdc", "<cmd>DiffviewClose<cr>", desc = "Diffview Close" },
      { "<leader>gdh", "<cmd>DiffviewFileHistory %<cr>", desc = "File History" },
      { "<leader>gdH", "<cmd>DiffviewFileHistory<cr>", desc = "Branch History" },
    },
    opts = {},
  },
}
