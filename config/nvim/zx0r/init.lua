-- ============================================================================
-- init.lua — Core Architecture
-- Neovim >= 0.12
--
-- Bootstrap order:
--   1. Lua loader
--   2. Performance baseline
--   3. Core options
--   4. Global keymaps
--   5. Plugin manager
--   6. Autocommands
--   7. Deferred observability
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. Lua module loader
-- ----------------------------------------------------------------------------
-- Enable Neovim's built-in Lua bytecode/module loader before loading
-- any user module.

vim.loader.enable()

-- ----------------------------------------------------------------------------
-- 1. Performance baseline
-- ----------------------------------------------------------------------------
-- Must run before the rest of the configuration.

require("core.perf")

-- ----------------------------------------------------------------------------
-- 2. Core options
-- ----------------------------------------------------------------------------
-- Pure editor configuration.
-- No plugin dependencies or deferred side effects.

require("core.options")

-- ----------------------------------------------------------------------------
-- 3. Leader definitions & Instant Theme Render (Ring 0: SLA < 1.0 ms)
-- ----------------------------------------------------------------------------
-- Set leader keys strictly before lazy.nvim parses plugin key specs.
-- Keymap definitions are deferred to Ring 2 (VeryLazy) to avoid 1.5ms overhead.

vim.g.mapleader      = " "
vim.g.maplocalleader = " "

vim.cmd.colorscheme("x")

-- ----------------------------------------------------------------------------
-- 4. Plugin manager (Ring 1: Lazy Bootstrap, SLA 5-15 ms)
-- ----------------------------------------------------------------------------
-- Bootstraps and configures lazy.nvim.
-- Plugin domains are discovered from lua/plugins/.

require("core.lazy")

-- ----------------------------------------------------------------------------
-- 5. Autocommands & Deferred Lifecycle (Ring 2: Zero Initial Overhead)
-- ----------------------------------------------------------------------------
-- Core event handling and augroup definitions.

require("core.autocmds")
require("theme").setup()

-- ----------------------------------------------------------------------------
-- 6. Deferred observability & diagnostics
-- ----------------------------------------------------------------------------
-- Benchmarking, telemetry, and invariant auditing via :CoreDoctor and commands.
-- Modules load on-demand when commands are invoked — zero overhead at startup.

require("core.audit").setup()

-- ----------------------------------------------------------------------------
-- 7. Deferred global keymaps
-- ----------------------------------------------------------------------------
-- Registers global editor mappings after UI is rendered and interactive.

vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = function()
    require("core.keymaps")
  end,
})

