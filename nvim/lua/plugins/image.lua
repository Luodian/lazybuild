-- media files are opened with the system viewer via autocmd instead of in-terminal rendering
vim.api.nvim_create_autocmd("BufReadCmd", {
  pattern = {
    -- image
    "*.png", "*.jpg", "*.jpeg", "*.gif", "*.bmp", "*.webp", "*.svg", "*.ico", "*.tiff", "*.heic",
    -- video
    "*.mp4", "*.mkv", "*.webm", "*.avi", "*.mov", "*.flv", "*.wmv", "*.m4v", "*.265", "*.hevc",
    -- audio
    "*.mp3", "*.wav", "*.flac", "*.aac", "*.ogg", "*.m4a", "*.wma",
    -- document
    "*.pdf",
  },
  callback = function(ev)
    local path = vim.fn.expand("%:p")
    vim.fn.jobstart({ "open", path }, { detach = true })
    -- restore previous buffer then wipe the media buffer,
    -- so the window layout stays untouched
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(ev.buf) then
        return
      end
      local alt = vim.fn.bufnr("#")
      if alt > 0 and alt ~= ev.buf and vim.api.nvim_buf_is_valid(alt) then
        vim.api.nvim_set_current_buf(alt)
      else
        vim.cmd("enew")
      end
      vim.api.nvim_buf_delete(ev.buf, { force = true })
    end)
  end,
})

return {}
