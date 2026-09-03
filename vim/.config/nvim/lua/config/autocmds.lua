-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- show file name at top of buffer
local winbar_excluded_filetypes = {
  "neo-tree",
  "lazy",
  "mason",
  "help",
  "qf",
  "toggleterm",
  "TelescopePrompt",
  "trouble",
  "notify",
  "snacks_dashboard",
}

local function set_winbar()
  if vim.bo.buftype ~= "" or vim.tbl_contains(winbar_excluded_filetypes, vim.bo.filetype) then
    vim.opt_local.winbar = nil
    return
  end
  vim.opt_local.winbar = " %t %m"
end

vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter", "BufEnter", "FileType" }, {
  group = vim.api.nvim_create_augroup("config_winbar", { clear = true }),
  callback = set_winbar,
})
