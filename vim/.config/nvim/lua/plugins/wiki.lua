return {
  "vimwiki/vimwiki",
  init = function()
    vim.g.vimwiki_path = "~/notes/"
    vim.g.vimwiki_syntax = "markdown"
    vim.g.vimwiki_ext = "md"
    vim.g.vimwiki_global_ext = 0
    vim.g.vimwiki_diary_rel_path = "/"
  end,
}
