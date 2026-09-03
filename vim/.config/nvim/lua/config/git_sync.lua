-- Auto-syncs a fixed list of git repos (pull, commit any local changes, push)
-- when Neovim opens, every 5 minutes, and when Neovim closes. Only repos
-- listed in M.repos are touched.
--
-- Every sync runs as a fully detached background job (git_sync.sh next to
-- this file), so Neovim is never blocked waiting on git -- including the
-- one fired on quit, which keeps running after Neovim's process exits.
-- vim.system's `detach` was tried first, but per :h vim.system() a detached
-- child "will still keep the parent's event loop alive unless the parent
-- calls uv.unref()", which vim.system doesn't expose a way to do; jobstart's
-- `detach` is the one actually documented to survive Neovim exiting.
local M = {}

M.repos = {
  vim.fn.expand("~/notes"),
}

local SYNC_INTERVAL_MS = 5 * 60 * 1000
local SCRIPT = vim.fn.stdpath("config") .. "/lua/config/git_sync.sh"
local LOG = vim.fn.stdpath("state") .. "/git-sync.log"

local function is_git_repo(path)
  return vim.fn.isdirectory(path .. "/.git") == 1
end

local function sync_repo(path)
  if not is_git_repo(path) then
    return
  end
  vim.fn.jobstart({ "sh", SCRIPT, path, LOG }, {
    detach = true,
    on_exit = function(_, code)
      -- Only fires if Neovim is still around when the job finishes (e.g.
      -- the open/timer syncs, not the one fired on quit) -- check LOG for
      -- anything that happens after Neovim has already exited.
      if code ~= 0 then
        vim.notify(string.format("git-sync: sync failed for %s, see %s", path, LOG), vim.log.levels.WARN)
      end
    end,
  })
end

function M.sync_all()
  for _, path in ipairs(M.repos) do
    sync_repo(path)
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("config_git_sync", { clear = true })

  local timer = (vim.uv or vim.loop).new_timer()
  timer:start(SYNC_INTERVAL_MS, SYNC_INTERVAL_MS, vim.schedule_wrap(M.sync_all))

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      timer:stop()
      timer:close()
      M.sync_all()
    end,
  })

  -- "On opening nvim": this file loads on the VeryLazy event, which itself
  -- fires from a VimEnter callback -- so VimEnter has already happened by
  -- the time we could register an autocmd for it. Sync directly instead.
  M.sync_all()
end

return M
