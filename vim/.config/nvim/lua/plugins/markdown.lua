return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.nvim' }, -- if you use the mini.nvim suite
  },
  {
    -- markdown-oxide is a PKM language server: inside [[wikilinks]] and
    -- [text](links) it completes note file names, and once a file is named
    -- before a `#`, it switches to completing that file's own headings.
    -- Root is detected via .git/.obsidian/.moxide.toml, so it picks up
    -- ~/notes (an Obsidian vault under git) automatically.
    -- vimwiki sets `filetype=vimwiki` (not `markdown`) for files under its
    -- wiki path even with vimwiki_syntax = "markdown", so that filetype has
    -- to be added explicitly or the server never attaches there.
    'neovim/nvim-lspconfig',
    opts = {
      servers = {
        markdown_oxide = {
          filetypes = { "markdown", "vimwiki" },
          -- markdown-oxide is installed system-wide here rather than through
          -- Mason, so tell LazyVim to enable it directly instead of waiting
          -- on Mason to report it as installed (which it never will).
          mason = false,
        },
      },
    },
  },
}
