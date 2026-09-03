-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- TELESCOPE
local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Telescope find files" })
vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Telescope live grep" })
vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Telescope buffers" })
vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Telescope help tags" })

-- BACKLINKS (markdown/vimwiki, via the markdown_oxide LSP)
-- Querying position (0,0) resolves to that line's *heading* referenceable
-- when line 1 is itself a heading, instead of the file as a whole, so the
-- first non-heading, non-blank line is used to reliably target the file.
local function backlinks_query_position(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i, line in ipairs(lines) do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" and not trimmed:match("^#") then
      return { line = i - 1, character = 0 }
    end
  end
  return { line = 0, character = 0 }
end

local function show_backlinks()
  local source_buf = vim.api.nvim_get_current_buf()
  local source_win = vim.api.nvim_get_current_win()

  local clients = vim.lsp.get_clients({ bufnr = source_buf, name = "markdown_oxide" })
  if #clients == 0 then
    vim.notify("Backlinks: markdown_oxide isn't attached to this buffer", vim.log.levels.WARN)
    return
  end

  local params = vim.lsp.util.make_position_params(source_win, clients[1].offset_encoding)
  params.position = backlinks_query_position(source_buf)
  params.context = { includeDeclaration = false }

  vim.lsp.buf_request(source_buf, "textDocument/references", params, function(err, result)
    if err then
      vim.notify("Backlinks: " .. err.message, vim.log.levels.ERROR)
      return
    end

    local lines, locations = {}, {}
    for _, loc in ipairs(result or {}) do
      local fname = vim.uri_to_fname(loc.uri)
      local lnum = loc.range.start.line
      local text = (vim.fn.readfile(fname, "", lnum + 1)[lnum + 1] or ""):gsub("^%s+", "")
      table.insert(lines, string.format("%s: %s", vim.fn.fnamemodify(fname, ":t:r"), text))
      table.insert(locations, { fname = fname, lnum = lnum + 1, col = loc.range.start.character + 1 })
    end
    if #lines == 0 then
      lines = { "(no backlinks)" }
    end

    local buf = vim.fn.bufnr("Backlinks")
    if buf == -1 then
      buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(buf, "Backlinks")
    end
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "backlinks"
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    local win = vim.fn.bufwinid(buf)
    if win == -1 then
      vim.cmd("botright 5split")
      win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, buf)
    else
      vim.api.nvim_set_current_win(win)
    end
    vim.api.nvim_win_set_height(win, 5)
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].wrap = false

    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true, desc = "Close backlinks" })
    vim.keymap.set("n", "<CR>", function()
      local loc = locations[vim.api.nvim_win_get_cursor(win)[1]]
      if not loc then
        return
      end
      vim.api.nvim_set_current_win(source_win)
      vim.cmd("edit " .. vim.fn.fnameescape(loc.fname))
      vim.api.nvim_win_set_cursor(0, { loc.lnum, loc.col - 1 })
    end, { buffer = buf, silent = true, desc = "Jump to backlink" })
  end)
end

local function attach_backlinks_keymap(bufnr)
  vim.keymap.set("n", "<leader>bl", show_backlinks, { buffer = bufnr, desc = "Show backlinks" })
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "vimwiki" },
  group = vim.api.nvim_create_augroup("config_backlinks", { clear = true }),
  callback = function(args)
    attach_backlinks_keymap(args.buf)
  end,
})

-- keymaps.lua loads on VeryLazy, which fires after the FileType event of
-- whichever buffer was opened from the command line, so that first buffer
-- would otherwise miss the mapping above; catch it here.
for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
  local ft = vim.bo[bufnr].filetype
  if ft == "markdown" or ft == "vimwiki" then
    attach_backlinks_keymap(bufnr)
  end
end
