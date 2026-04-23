return {
  {
    "folke/snacks.nvim",
    init = function()
      -- Make untracked files visually distinct from ignored files in the explorer.
      -- Default Snacks maps both to "NonText" (gray), which is confusing.
      vim.api.nvim_set_hl(0, "SnacksPickerGitStatusUntracked", { link = "DiagnosticInfo" })
    end,
    opts = {
      picker = {
        -- Fix: prevent picker.main from falling back to terminal window
        -- when no "file" buffer window exists (snacks.nvim #1155, #1517, #1814)
        main = { file = false },
        sources = {
          -- Make gitignored/hidden files an explicit, visible policy.
          -- This affects file open/search pickers so ignored files are not silently filtered out.
          files = {
            hidden = true,
            ignored = true,
          },
          grep = {
            hidden = true,
            ignored = true,
          },
          smart = {
            hidden = true,
            ignored = true,
          },
          explorer = {
            hidden = true,
            ignored = true,
            exclude = { ".DS_Store" },
            actions = {
              -- Custom yank dispatcher: y + second key -> copy different path formats.
              -- Registered as a named action so it goes through Snacks' action
              -- resolution (M.wrap -> M.resolve) and receives (picker, item) correctly.
              -- Inline functions in keys receive the window object, not the picker.
              yank_path = function(picker, item)
                -- Visual mode: preserve default multi-file yank
                if vim.fn.mode():find("^[vV]") then
                  picker.list:select()
                  local files = {}
                  for _, sel in ipairs(picker:selected({ fallback = true })) do
                    table.insert(files, Snacks.picker.util.path(sel))
                  end
                  picker.list:set_selected()
                  local value = table.concat(files, "\n")
                  vim.fn.setreg("+", value, "l")
                  Snacks.notify.info("Yanked " .. #files .. " files")
                  return
                end

                -- Normal mode: block for second key
                local char = vim.fn.getcharstr()
                if not item then
                  return
                end
                local path = Snacks.picker.util.path(item)
                if not path then
                  return
                end

                local value, label
                if char == "r" then
                  value = vim.fn.fnamemodify(path, ":.")
                  label = "Relative path"
                elseif char == "a" then
                  value = path
                  label = "Absolute path"
                elseif char == "f" then
                  value = vim.fn.fnamemodify(path, ":t")
                  label = "Filename"
                elseif char == "d" then
                  value = item.dir and path or vim.fn.fnamemodify(path, ":h")
                  label = "Directory"
                else
                  -- yy or any unknown key: default to absolute path
                  value = path
                  label = "Path"
                end

                vim.fn.setreg("+", value, "c")
                Snacks.notify.info(label .. " copied: " .. value)
              end,
            },
            win = {
              list = {
                keys = {
                  ["<c-t>"] = false, -- disable default terminal action to avoid accidental triggers
                  ["y"] = { "yank_path", mode = { "n", "x" }, desc = "Copy path (yr=rel, ya=abs, yf=name, yd=dir)" },
                },
              },
            },
          },
        },
      },
    },
  },
}
