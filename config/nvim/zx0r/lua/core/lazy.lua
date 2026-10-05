-- ============================================================================
-- core/lazy.lua — Plugin Manager Bootstrap (lazy.nvim)
-- Strategy: defaults.lazy = true (everything lazy unless explicit lazy=false)
-- Lockfile: lua/lazy-lock.json for deterministic reproduction
-- ============================================================================

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local is_bootstrap = not vim.uv.fs_stat(lazypath)

-- Bootstrap lazy.nvim if not present
if is_bootstrap then
  local result = vim.system({
    "git", "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  }, { text = true }):wait()   -- :wait() is safe here — runs before any UI exists
  if result.code ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n",   "ErrorMsg"   },
      { result.stderr or "",              "WarningMsg" },
      { "\nPress any key to exit...",     ""           },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

local ok, lazy = pcall(require, "lazy")
if ok then
  lazy.setup({
    spec = {
    -- Automatically discover plugin specs from the `lua/plugins/` module.
    --
    -- Keep plugin domains as independent Lua modules so new top-level
    -- domains can be added without modifying this file.
    { import = "plugins" },
  },

  defaults = {
    -- Prefer event-driven lazy loading unless a plugin explicitly requires
    -- eager initialization.
    lazy = true,

    -- Do not pin plugins to release tags. Reproducibility is provided by
    -- lazy-lock.json; version constraints are declared only when required.
    version = false,
  },

  install = {
    -- Deterministic supply-chain: do not check/install missing plugins on launch.
    -- Plugin provisioning is performed explicitly via :Lazy install / sync.
    missing = true,

    -- Temporary fallback colorscheme used during initial installation when
    -- the user's configured colorscheme is not available yet.
    colorscheme = { "x", "habamax" },
  },

  rocks = {
    -- Disable LuaRocks integration. Enable only when a plugin explicitly
    -- requires LuaRocks-managed dependencies.
    enabled = false,
  },

  checker = {
    -- Disable background update checks. Dependency updates remain explicit
    -- and controlled through the lockfile/update workflow.
    enabled = false,
  },

  change_detection = {
    -- Disable automatic filesystem change detection for plugin specs.
    -- Restart Neovim after configuration changes.
    enabled = false,
  },

  performance = {
    -- Keep lazy.nvim's compiled module cache enabled for faster startup.
    cache = {
      enabled = true,
    },

    -- Let lazy.nvim manage the runtime path without preserving the default
    -- package path from the legacy Vim loading model.
    reset_packpath = true,

    rtp = {
      -- Reset runtimepath to $VIMRUNTIME and config dir to prune obsolete probes
      reset = true,

      -- Disable built-in legacy runtime plugins that are intentionally
      -- replaced or not required by this configuration.
      disabled_plugins = {
        "2html_plugin",
        "editorconfig",
        "getscript",
        "getscriptPlugin",
        "gzip",
        "logipat",
        "man",
        "matchit",
        "matchparen",
        "net",
        "netrw",
        "netrwPlugin",
        "osc52",
        "rplugin",
        "rrhelper",
        "spellfile",
        "spellfile_plugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "vimball",
        "vimballPlugin",
        "zipPlugin",
      },
    },
  },
})
end
