-- ============================================================================
-- core/guard.lua — Large-File Runtime Protection & Governor
-- Tier 1 (>1MB):  disable Treesitter, LSP, completion, diagnostics
-- Tier 2 (>10MB): read-only + minimal mode (no syntax at all, unload on hide)
-- Zero-Overhead: Uses pure libuv stat — zero shell process spawns
-- ============================================================================

local M = {}

local TIER1_BYTES = 1024 * 1024      -- 1 MB
local TIER2_BYTES = 10 * 1024 * 1024 -- 10 MB

--- Setup callback invoked by snacks.bigfile on BufReadPre
---@param ctx {buf: integer, ft: string}
function M.setup(ctx)
  local buf = ctx.buf
  if vim.b[buf].large_file then return end

  local fname = vim.api.nvim_buf_get_name(buf)
  if fname == "" then return end

  -- Use libuv fs_stat — strictly async-safe, never spawns a shell process
  local stat = vim.uv.fs_stat(fname)
  local size = stat and stat.size or (1024 * 1024 + 1)

  if size > TIER2_BYTES then
    M._apply_tier2(buf, size, ctx.ft)
  elseif size > TIER1_BYTES then
    M._apply_tier1(buf, size, ctx.ft)
  end
end

--- Apply large-file protections to a buffer (manual/fallback entrypoint)
---@param buf integer|nil buffer handle (defaults to current)
function M.check(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if vim.b[buf].large_file then return end

  local fname = vim.api.nvim_buf_get_name(buf)
  if fname == "" then return end

  local stat = vim.uv.fs_stat(fname)
  if not stat or stat.size <= TIER1_BYTES then return end

  local ft = vim.bo[buf].filetype
  M.setup({ buf = buf, ft = ft })
end

--- Tier 1: >1MB — disable expensive AST/LSP features, keep basic editing
---@param buf integer
---@param size integer
---@param ft string|nil
function M._apply_tier1(buf, size, ft)
  local mb = string.format("%.1f", size / (1024 * 1024))
  vim.notify(
    string.format("Large file (%.1fMB) — Treesitter/LSP/completion disabled", mb),
    vim.log.levels.WARN,
    { title = "core/guard" }
  )

  vim.api.nvim_buf_call(buf, function()
    pcall(vim.cmd, "silent! NoMatchParen")

    -- Disable Treesitter highlighting
    local ok_ts = pcall(vim.treesitter.stop, buf)
    if not ok_ts then
      vim.bo[buf].syntax = "off"
    end

    -- Flag buffer for all domain manifests
    vim.b[buf].large_file = true
    vim.b[buf].completion = false
    vim.b[buf].minianimate_disable = true
    vim.b[buf].minihipatterns_disable = true

    -- Performance settings
    vim.opt_local.foldmethod   = "manual"
    vim.opt_local.statuscolumn = ""
    vim.opt_local.conceallevel = 0
    vim.opt_local.undofile     = false
    vim.opt_local.swapfile     = false
    vim.opt_local.list         = false
    vim.opt_local.cursorline   = false
    vim.opt_local.spell        = false
    vim.opt_local.synmaxcol    = 0
  end)

  -- Detach any LSP clients already attached
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
    vim.lsp.buf_detach_client(buf, client.id)
  end

  -- Restore standard regex syntax since Snacks bigfile intercepted the original ft
  if ft and ft ~= "" then
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.bo[buf].syntax = ft
      end
    end)
  end
end

--- Tier 2: >10MB — read-only minimal mode
---@param buf integer
---@param size integer
---@param ft string|nil
function M._apply_tier2(buf, size, ft)
  M._apply_tier1(buf, size, "") -- All tier-1 protections first (no syntax restore)

  local mb = string.format("%.1f", size / (1024 * 1024))
  vim.notify(
    string.format("Very large file (%.1fMB) — Read-only minimal mode", mb),
    vim.log.levels.ERROR,
    { title = "core/guard" }
  )

  vim.api.nvim_buf_call(buf, function()
    vim.opt_local.readonly    = true
    vim.opt_local.modifiable  = false
    vim.opt_local.syntax      = "off"
    vim.opt_local.number      = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn  = "no"
    vim.opt_local.bufhidden   = "unload"   -- Unload on hide to save RAM
    vim.opt_local.buftype     = "nowrite"
  end)
end

--- Check if a buffer is in large-file protection mode
---@param buf integer|nil
---@return boolean
function M.is_large(buf)
  return vim.b[buf or 0].large_file == true
end

return M
