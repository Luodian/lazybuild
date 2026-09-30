-- oil.nvim: edit the filesystem like a normal Vim buffer.
--   move   : `dd` the file's line, open another dir in oil, `p`, then `:w`
--   rename : edit the line text, then `:w`
--   create : add a line (directory = trailing `/`), then `:w`
--   delete : delete the line, then `:w`
-- `:w` shows a confirm preview of every pending operation before applying.
-- Icons come from LazyVim's mini.icons (already loaded) -- no dependency needed.
return {
  {
    "stevearc/oil.nvim",
    -- Disabled: using snacks explorer instead. Flip back to re-enable (`-` opens parent dir).
    enabled = false,
    -- Lazy-loaded: on `-`, on `:Oil`, and (via init) only when nvim starts on a
    -- directory, so `nvim <dir>` still drops into oil without loading it at every
    -- startup. oil's netrw hijack only fires once oil is loaded, hence the init.
    lazy = true,
    cmd = "Oil",
    init = function()
      if vim.fn.argc(-1) == 1 then
        local stat = (vim.uv or vim.loop).fs_stat(vim.fn.argv(0))
        if stat and stat.type == "directory" then
          require("oil")
        end
      end
    end,
    ---@module "oil"
    ---@type oil.SetupOpts
    opts = {
      -- Match your snacks explorer: show hidden / dotfiles by default.
      view_options = { show_hidden = true },
    },
    keys = {
      { "-", "<cmd>Oil<cr>", mode = "n", desc = "Open parent dir (oil)" },
    },
  },
}
