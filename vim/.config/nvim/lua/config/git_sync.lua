-- Auto-syncs a fixed list of git repos (pull, commit any local changes, push)
-- when Neovim opens, every 5 minutes, and when Neovim closes. Only repos
-- listed in M.repos are touched.
local M = {}

M.repos = {
  vim.fn.expand("~/notes"),
}

local SYNC_INTERVAL_MS = 5 * 60 * 1000
local GIT_TIMEOUT_MS = 15 * 1000

local function notify_failure(path, step, err)
  local msg = string.format("git-sync: %s failed in %s%s", step, path, err and ("\n" .. err) or "")
  -- The async path resumes from inside a vim.system callback (fast-event
  -- context), where most of the API is off-limits, so it must be deferred.
  -- The blocking VimLeavePre path is already on the main loop and must NOT
  -- defer: Neovim can finish exiting before a scheduled callback gets a
  -- turn, silently swallowing the warning.
  if vim.in_fast_event() then
    vim.schedule(function()
      vim.notify(msg, vim.log.levels.WARN)
    end)
  else
    vim.notify(msg, vim.log.levels.WARN)
  end
end

-- The pull/commit/push sequence, written as straight-line steps. `await`
-- abstracts running one git command and getting its result back, either
-- synchronously (blocking, used on exit) or via a coroutine (non-blocking,
-- used on open and on the timer) -- see the two callers below.
local function sync_steps(path, await)
  local pull = await({ "git", "-C", path, "pull", "--rebase", "--autostash" })
  if pull.code ~= 0 then
    return false, "pull", pull.stderr
  end

  -- `pull --autostash` can exit 0 while still leaving unresolved conflict
  -- markers behind, if reapplying the stashed local changes collided with
  -- what was just pulled. Stop here rather than committing those markers.
  local conflicts = await({ "git", "-C", path, "diff", "--name-only", "--diff-filter=U" })
  if conflicts.code == 0 and conflicts.stdout and conflicts.stdout:gsub("%s+", "") ~= "" then
    return false, "pull (conflict left by autostash, resolve manually)", conflicts.stdout
  end

  local status = await({ "git", "-C", path, "status", "--porcelain" })
  if status.code == 0 and status.stdout and status.stdout ~= "" then
    await({ "git", "-C", path, "add", "-A" })
    await({ "git", "-C", path, "commit", "-m", "auto sync: " .. os.date("%Y-%m-%d %H:%M:%S") })
  end

  local push = await({ "git", "-C", path, "push" })
  if push.code ~= 0 then
    return false, "push", push.stderr
  end

  return true
end

local function await_blocking(cmd)
  return vim.system(cmd, { text = true, timeout = GIT_TIMEOUT_MS }):wait()
end

local function await_async(cmd)
  local co = coroutine.running()
  vim.system(cmd, { text = true, timeout = GIT_TIMEOUT_MS }, function(result)
    coroutine.resume(co, result)
  end)
  return coroutine.yield()
end

local function is_git_repo(path)
  return vim.fn.isdirectory(path .. "/.git") == 1
end

-- Non-blocking: used on VimEnter and the periodic timer.
local function sync_async(path)
  if not is_git_repo(path) then
    return
  end
  coroutine.wrap(function()
    local ok, step, err = sync_steps(path, await_async)
    if not ok then
      notify_failure(path, step, err)
    end
  end)()
end

-- Blocking: used on VimLeavePre, so the sync finishes before Neovim exits.
local function sync_blocking(path)
  if not is_git_repo(path) then
    return
  end
  local ok, step, err = sync_steps(path, await_blocking)
  if not ok then
    notify_failure(path, step, err)
  end
end

function M.sync_all()
  for _, path in ipairs(M.repos) do
    sync_async(path)
  end
end

function M.sync_all_blocking()
  for _, path in ipairs(M.repos) do
    sync_blocking(path)
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("config_git_sync", { clear = true })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = M.sync_all_blocking,
  })

  local timer = (vim.uv or vim.loop).new_timer()
  timer:start(
    SYNC_INTERVAL_MS,
    SYNC_INTERVAL_MS,
    vim.schedule_wrap(M.sync_all)
  )
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      timer:stop()
      timer:close()
    end,
  })

  -- "On opening nvim": this file loads on the VeryLazy event, which itself
  -- fires from a VimEnter callback -- so VimEnter has already happened by
  -- the time we could register an autocmd for it. Sync directly instead.
  M.sync_all()
end

return M
