-- Dirs that flood search results once hidden+ignored are on: duplicate
-- checkouts (.worktrees), python envs (.venv, any site-packages), vendored
-- deps and caches. Each entry is a basename glob matched at any depth:
-- fd gets `-E <e>`, rg gets `-g '!<e>'`, and command-line globs win over
-- --hidden/--no-ignore. The explorer shares the list (plus .git): its search
-- runs the same fd recursion, so without these it dives into worktrees/venvs/
-- caches once hidden+ignored are toggled on. Trade-off: excluded dirs also drop
-- from the tree (exclude has no toggle), fine here since you open a worktree or
-- .venv file directly rather than by expanding it in the tree.
local search_exclude = {
  ".worktrees",
  ".venv",
  "site-packages",
  "node_modules",
  "__pycache__",
  ".pytest_cache",
  ".ruff_cache",
}

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
            exclude = search_exclude,
          },
          grep = {
            hidden = true,
            ignored = true,
            -- hidden+ignored let grep descend into dot-dirs and gitignored paths;
            -- the shared excludes keep that reach but drop the noisy ones.
            exclude = search_exclude,
          },
          -- smart is a multi source (buffers/recent/files); its opts are passed
          -- through to each child finder, so exclude reaches the files child.
          smart = {
            hidden = true,
            ignored = true,
            exclude = search_exclude,
          },
          explorer = {
            hidden = true,
            ignored = true,
            exclude = vim.list_extend({ ".git", ".DS_Store" }, search_exclude),
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
                elseif char == "g" then
                  -- GitHub permalink for the highlighted item.
                  -- Run git from the item's own dir so a file in a submodule
                  -- resolves to that submodule's repo/remote/commit; --show-prefix
                  -- yields the repo-root-relative path with no toplevel stripping.
                  local dir = item.dir and path or vim.fn.fnamemodify(path, ":h")
                  local function git(...)
                    local out = vim.fn.system({ "git", "-C", dir, ... })
                    return vim.v.shell_error == 0 and vim.trim(out) or nil
                  end
                  -- Pin to the commit that last touched this item (file or folder),
                  -- like a true permalink; fall back to HEAD for a never-committed
                  -- path so we never emit an empty-commit url.
                  local commit = git("log", "-n", "1", "--pretty=format:%H", "--", path)
                  if not commit or commit == "" then
                    commit = git("rev-parse", "HEAD")
                  end
                  local remote = git("remote", "get-url", "origin")
                  local prefix = git("rev-parse", "--show-prefix")
                  if not (commit and remote and prefix) then
                    Snacks.notify.error("Not a git repo, or no 'origin' remote", { title = "Git Browse" })
                    return
                  end
                  local repo = Snacks.gitbrowse.get_repo(remote)
                  if item.dir then
                    local rel = prefix:gsub("/$", "")
                    value = rel == "" and ("%s/tree/%s"):format(repo, commit)
                      or ("%s/tree/%s/%s"):format(repo, commit, rel)
                  else
                    value = ("%s/blob/%s/%s%s"):format(repo, commit, prefix, vim.fn.fnamemodify(path, ":t"))
                  end
                  label = "GitHub permalink"
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
                  ["y"] = { "yank_path", mode = { "n", "x" }, desc = "Copy path (yr=rel, ya=abs, yf=name, yd=dir, yg=permalink)" },
                },
              },
            },
          },
        },
      },
    },
    keys = {
      {
        "<leader>yg",
        function()
          local function yank(url)
            vim.fn.setreg("+", url)
            Snacks.notify.info("Copied GitHub permalink:\n" .. url, { title = "Git Browse" })
          end

          -- snacks.gitbrowse only supports regular files: for any non-file buffer it
          -- sets file=nil, so permalink mode emits a broken .../blob/<HEAD>/{file} url.
          -- When the current buffer is a directory (e.g. netrw), build a
          -- /tree/<commit>/<dir> link ourselves, reusing snacks' remote parser so
          -- git@/https/ssh remotes normalize the same way the file path does.
          local bufname = vim.api.nvim_buf_get_name(0)
          local uv = vim.uv or vim.loop
          local stat = bufname ~= "" and uv.fs_stat(bufname) or nil
          if stat and stat.type == "directory" then
            local function git(...)
              local out = vim.fn.system({ "git", "-C", bufname, ... })
              return vim.v.shell_error == 0 and vim.trim(out) or nil
            end
            local commit = git("rev-parse", "HEAD")
            local remote = git("remote", "get-url", "origin")
            local prefix = git("rev-parse", "--show-prefix")
            if not (commit and remote and prefix) then
              Snacks.notify.error("Not a git dir, or no 'origin' remote", { title = "Git Browse" })
              return
            end
            local rel = prefix:gsub("/$", "")
            local repo = Snacks.gitbrowse.get_repo(remote)
            yank(rel == "" and ("%s/tree/%s"):format(repo, commit) or ("%s/tree/%s/%s"):format(repo, commit, rel))
            return
          end

          -- A saved, on-disk file is the only buffer snacks.gitbrowse resolves: it
          -- derives `file` from `git ls-files`, and for anything else (no-name,
          -- neo-tree, terminal, picker buffers) it leaves file=nil, so the pattern
          -- emits a literal `.../{file}#L..`. Gate on a real file and report instead.
          if not (stat and stat.type == "file") then
            Snacks.notify.error("No file to permalink — current buffer isn't a saved file", { title = "Git Browse" })
            return
          end

          Snacks.gitbrowse({ what = "permalink", notify = false, open = yank })
        end,
        desc = "Yank GitHub permalink (file line/selection, or dir tree)",
        mode = { "n", "x" },
      },
    },
  },
}
