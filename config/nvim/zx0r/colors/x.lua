-- ============================================================================
-- colors/x.lua
--
-- Ring 0 Execution: SLA < 0.05 ms via pre-compiled AOT Bytecode Chunk
-- Fallback: Dynamic spec compilation via lua/theme/master.lua

-- ============================================================================

local active_style = vim.g.theme_style or vim.env.X_THEME or "dark"
local cache_file = vim.fs.joinpath(vim.fn.stdpath("cache"), "theme", active_style .. ".luac")
local master_file = vim.fn.stdpath("config") .. "/lua/theme/master.lua"

-- ── 1. Fast Path: AOT Compiled Cache ────────────────────────────────────────
local cache_stat = vim.uv.fs_stat(cache_file)
local master_stat = vim.uv.fs_stat(master_file)

if cache_stat and master_stat and cache_stat.mtime.sec >= master_stat.mtime.sec then
  local chunk, err = loadfile(cache_file)
  if chunk then
    chunk()
    goto register_commands
  end
end

-- ── 2. Dynamic Path: Load master generator and recompile fresh bytecode ────────
require("theme.master").load(active_style)

::register_commands::

-- ── 3. Commands & Controls ──────────────────────────────────────────────────
if not vim.g._theme_commands_registered then
  vim.g._theme_commands_registered = true

  vim.api.nvim_create_user_command("EnvironmentXCompile", function()
    local path = require("theme.master").compile()
    vim.notify(string.format("Environment-X compiled [%s] -> %s", vim.g.theme_style or "dark", path), vim.log.levels.INFO, {
      title = "Theme Compiler",
    })
  end, { desc = "Recompile Environment-X theme bytecode for current style" })

  vim.api.nvim_create_user_command("ThemeStyle", function(opts)
    local style = vim.trim(opts.args):lower()
    local master = require("theme.master")
    if not master.palettes[style] then
      vim.notify("Invalid style. Available: dark, light", vim.log.levels.WARN)
      return
    end
    vim.g.theme_style = style
    vim.cmd.colorscheme("x")
  end, {
    nargs = 1,
    complete = function() return { "dark", "light" } end,
    desc = "Switch Environment-X palette (dark | light)",
  })

  vim.api.nvim_create_user_command("ThemeToggle", function()
    local next_style = (vim.g.theme_style == "dark") and "light" or "dark"
    vim.g.theme_style = next_style
    vim.cmd.colorscheme("x")
    vim.notify("Environment-X style: " .. next_style, vim.log.levels.INFO)
  end, { desc = "Toggle Environment-X theme palette between dark and light" })
end
