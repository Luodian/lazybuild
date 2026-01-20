return {
  {
    "folke/snacks.nvim",
    opts = {
      explorer = {
        replace_netrw = true,
      },
      picker = {
        sources = {
          explorer = {
            hidden = true,    -- show hidden files
            ignored = true,   -- show gitignored files
          },
        },
      },
    },
  },
}
