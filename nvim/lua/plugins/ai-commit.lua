-- AI-powered git commit message generator via OpenRouter API
-- Usage: <leader>gc in normal mode (stages all + generates commit message)
-- Requires: OPENROUTER_API_KEY env var

return {
  "nvim-lua/plenary.nvim",
  keys = {
    {
      "<leader>ac",
      function()
        local api_key = os.getenv("OPENROUTER_API_KEY")
        if not api_key then
          vim.notify("OPENROUTER_API_KEY not set", vim.log.levels.ERROR)
          return
        end

        -- Get staged diff first; if nothing staged, stage everything
        local diff = vim.fn.system("git diff --cached")
        if vim.v.shell_error ~= 0 then
          vim.notify("Not a git repository", vim.log.levels.ERROR)
          return
        end
        if diff == "" then
          vim.fn.system("git add -A")
          diff = vim.fn.system("git diff --cached")
        end
        if diff == "" then
          vim.notify("No changes to commit", vim.log.levels.WARN)
          return
        end

        -- Truncate massive diffs to avoid token limits
        local max_len = 12000
        if #diff > max_len then
          diff = diff:sub(1, max_len) .. "\n... (truncated)"
        end

        vim.notify("Generating commit message...", vim.log.levels.INFO)

        local curl = require("plenary.curl")
        local body = vim.json.encode({
          model = "bytedance-seed/seed-1.6-flash",
          messages = {
            {
              role = "system",
              content = "You are a git commit message generator. "
                .. "Write a concise conventional commit message (feat/fix/refactor/docs/chore/style/test/perf/ci/build). "
                .. "Format: <type>(<optional scope>): <description>\\n\\n<optional body>. "
                .. "The first line MUST be under 72 characters. "
                .. "Return ONLY the commit message, nothing else.",
            },
            {
              role = "user",
              content = "Generate a commit message for this diff:\n\n" .. diff,
            },
          },
          max_tokens = 256,
        })

        curl.post("https://openrouter.ai/api/v1/chat/completions", {
          body = body,
          headers = {
            content_type = "application/json",
            authorization = "Bearer " .. api_key,
          },
          callback = vim.schedule_wrap(function(res)
            if res.status ~= 200 then
              vim.notify("OpenRouter API error: " .. (res.status or "unknown"), vim.log.levels.ERROR)
              return
            end

            local ok, data = pcall(vim.json.decode, res.body)
            if not ok or not data.choices or not data.choices[1] then
              vim.notify("Failed to parse API response", vim.log.levels.ERROR)
              return
            end

            local msg = data.choices[1].message.content
            msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
            msg = msg:gsub("^```%w*\n?", ""):gsub("\n?```$", "")

            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(msg, "\n"))
            vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")
            vim.api.nvim_buf_set_option(buf, "filetype", "gitcommit")
            vim.api.nvim_buf_set_name(buf, "AI Commit Message")

            local width = math.min(80, vim.o.columns - 4)
            local height = math.min(20, #vim.split(msg, "\n") + 2)
            local win = vim.api.nvim_open_win(buf, true, {
              relative = "editor",
              width = width,
              height = height,
              col = math.floor((vim.o.columns - width) / 2),
              row = math.floor((vim.o.lines - height) / 2),
              style = "minimal",
              border = "rounded",
              title = " AI Commit - Edit & :w to commit, :q to cancel ",
              title_pos = "center",
            })

            vim.api.nvim_create_autocmd("BufWriteCmd", {
              buffer = buf,
              once = true,
              callback = function()
                local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                local final_msg = table.concat(lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
                if final_msg == "" then
                  vim.notify("Empty commit message, aborted", vim.log.levels.WARN)
                  return
                end
                vim.api.nvim_win_close(win, true)
                local result = vim.fn.system({ "git", "commit", "-m", final_msg })
                if vim.v.shell_error == 0 then
                  vim.notify("Committed: " .. vim.split(final_msg, "\n")[1], vim.log.levels.INFO)
                else
                  vim.notify("Commit failed: " .. result, vim.log.levels.ERROR)
                end
              end,
            })

            vim.notify("Edit the message, then :w to commit or :q to cancel", vim.log.levels.INFO)
          end),
        })
      end,
      desc = "AI Commit (OpenRouter)",
    },
    {
      "<leader>aC",
      function()
        local api_key = os.getenv("OPENROUTER_API_KEY")
        if not api_key then
          vim.notify("OPENROUTER_API_KEY not set", vim.log.levels.ERROR)
          return
        end

        local diff = vim.fn.system("git diff --cached")
        if vim.v.shell_error ~= 0 then
          vim.notify("Not a git repository", vim.log.levels.ERROR)
          return
        end
        if diff == "" then
          vim.fn.system("git add -A")
          diff = vim.fn.system("git diff --cached")
        end
        if diff == "" then
          vim.notify("No changes to commit", vim.log.levels.WARN)
          return
        end

        local max_len = 12000
        if #diff > max_len then
          diff = diff:sub(1, max_len) .. "\n... (truncated)"
        end

        vim.notify("Generating commit message...", vim.log.levels.INFO)

        local curl = require("plenary.curl")
        local body = vim.json.encode({
          model = "bytedance-seed/seed-1.6-flash",
          messages = {
            {
              role = "system",
              content = "You are a git commit message generator. "
                .. "Write a concise conventional commit message (feat/fix/refactor/docs/chore/style/test/perf/ci/build). "
                .. "Format: <type>(<optional scope>): <description>\\n\\n<optional body>. "
                .. "The first line MUST be under 72 characters. "
                .. "Return ONLY the commit message, nothing else.",
            },
            {
              role = "user",
              content = "Generate a commit message for this diff:\n\n" .. diff,
            },
          },
          max_tokens = 256,
        })

        curl.post("https://openrouter.ai/api/v1/chat/completions", {
          body = body,
          headers = {
            content_type = "application/json",
            authorization = "Bearer " .. api_key,
          },
          callback = vim.schedule_wrap(function(res)
            if res.status ~= 200 then
              vim.notify("OpenRouter API error: " .. (res.status or "unknown"), vim.log.levels.ERROR)
              return
            end

            local ok, data = pcall(vim.json.decode, res.body)
            if not ok or not data.choices or not data.choices[1] then
              vim.notify("Failed to parse API response", vim.log.levels.ERROR)
              return
            end

            local msg = data.choices[1].message.content
            msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
            msg = msg:gsub("^```%w*\n?", ""):gsub("\n?```$", "")

            if msg == "" then
              vim.notify("Empty commit message, aborted", vim.log.levels.WARN)
              return
            end

            local result = vim.fn.system({ "git", "commit", "-m", msg })
            if vim.v.shell_error == 0 then
              vim.notify("✓ Auto-committed: " .. vim.split(msg, "\n")[1], vim.log.levels.INFO)
            else
              vim.notify("Commit failed: " .. result, vim.log.levels.ERROR)
            end
          end),
        })
      end,
      desc = "AI Commit (Auto, no confirm)",
    },
  },
}
