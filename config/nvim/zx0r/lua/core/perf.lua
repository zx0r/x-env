-- ============================================================================
-- core/perf.lua — Safe Startup Performance Baseline
--
-- This module contains only low-risk startup optimizations.
-- Performance claims must be validated with :startuptime and benchmarks.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Remote providers
-- ---------------------------------------------------------------------------
-- Disable providers that are not used by this configuration.
-- This prevents unnecessary provider discovery and loading.
--
-- Re-enable any provider required by a remote plugin or workflow.

vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0

-- ---------------------------------------------------------------------------
-- Mason binary discovery (Pure libuv path construction, zero VimL overhead)
-- ---------------------------------------------------------------------------
-- Mason is lazy-loaded (only on explicit :Mason* commands), but native
-- vim.lsp.enable() needs Mason-installed LSP servers on PATH before Mason
-- loads. Prepend the Mason bin directory unconditionally using direct path.

local data_dir = vim.env.XDG_DATA_HOME or (vim.env.HOME .. "/.local/share")
local appname = vim.env.NVIM_APPNAME or "nvim"
local mason_bins = {
  data_dir .. "/" .. appname .. "/mason/bin",
  data_dir .. "/nvim/" .. appname .. "/mason/bin",
  data_dir .. "/nvim/mason/bin",
}
for _, mason_bin in ipairs(mason_bins) do
  if vim.uv.fs_stat(mason_bin) and not vim.env.PATH:find(mason_bin, 1, true) then
    vim.env.PATH = mason_bin .. ":" .. vim.env.PATH
  end
end


-- ---------------------------------------------------------------------------
-- Startup message & GC tuning
-- ---------------------------------------------------------------------------
-- Suppress the default startup intro message.
vim.opt.shortmess:append("I")

-- Tune LuaJIT garbage collector: incremental GC with moderate step
if collectgarbage then
  collectgarbage("setpause", 150)
  collectgarbage("setstepmul", 300)
end
