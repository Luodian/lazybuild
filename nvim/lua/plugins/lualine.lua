return {
  {
    "nvim-lualine/lualine.nvim",
    opts = {
      sections = {
        lualine_c = {
          {
            "filename",
            path = 3, -- 0: Just filename, 1: Relative path, 2: Absolute path, 3: Absolute path + Tilde
          },
        },
      },
    },
  },
}
