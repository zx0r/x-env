-- ============================================================================
-- colors/x.lua — The X Ultra-Fast AOT Theme Loader
--
-- Ring 0 Execution: SLA < 0.05 ms via pre-compiled AOT Bytecode Chunk
-- Fallback: Dynamic spec compilation via lua/theme/master.lua
--
-- Architect: zx0r & DeepMind Advanced Agentic Systems Engineering
-- ============================================================================

local active_style = vim.g.theme_style or vim.env.X_THEME or "dark"
local cache_file = vim.fs.joinpath(vim.fn.stdpath("cache"), "theme", active_style .. ".luac")
local theme_dir = vim.fn.stdpath("config") .. "/lua/theme"
local master_file = theme_dir .. "/master.lua"
local engine_file = theme_dir .. "/engine.lua"
-- ── 1. Fast Path: AOT Compiled Cache ────────────────────────────────────────
local cache_stat = vim.uv.fs_stat(cache_file)
if cache_stat then
  local master_stat = vim.uv.fs_stat(master_file)
  local engine_stat = vim.uv.fs_stat(engine_file)
  local is_fresh = master_stat and (cache_stat.mtime.sec >= master_stat.mtime.sec)
  if is_fresh and engine_stat and engine_stat.mtime.sec > cache_stat.mtime.sec then
    is_fresh = false
  end

  if is_fresh then
    local chunk = loadfile(cache_file)
    if chunk then
      chunk()
      goto register_commands
    end
  end
end

-- ── 2. Dynamic Path: Load master generator and recompile fresh bytecode ────────
require("theme.master").load(active_style)

::register_commands::

-- ── 3. Commands & Controls ──────────────────────────────────────────────────
if not vim.g._theme_commands_registered then
  vim.g._theme_commands_registered = true

  vim.api.nvim_create_user_command("XCompile", function()
    local path = require("theme.master").compile()
    vim.notify(string.format("X theme compiled [%s] -> %s", vim.g.theme_style or "dark", path), vim.log.levels.INFO, {
      title = "Theme Compiler",
    })
  end, { desc = "Recompile X theme bytecode for current style" })

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
    desc = "Switch X theme palette (dark | light)",
  })

  vim.api.nvim_create_user_command("ThemeToggle", function()
    local next_style = (vim.g.theme_style == "dark") and "light" or "dark"
    vim.g.theme_style = next_style
    vim.cmd.colorscheme("x")
    vim.notify("X theme style: " .. next_style, vim.log.levels.INFO)
  end, { desc = "Toggle X theme palette between dark and light" })
end
