-- NOTE:-------------------------------------------------------
--   ██╗  ██╗    W O R K S T A T I O N
--   ╚██╗██╔╝
--    ╚███╔╝     SYSTEMS OVER SCRIPTS
--    ██╔██╗     INTENT OVER DRIFT
--   ██╔╝ ██╗    AUTOMATION WITH CONTROL
--   ╚═╝  ╚═╝
-- init.lua — Core Architecture
-- Neovim >= 0.12
-- Bootstrap order:
--   1. Lua loader
--   2. Performance baseline
--   3. Core options
--   4. Global keymaps
--   5. Plugin manager
--   6. Autocommands
--   7. Deferred observability
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
-- 3. Leader definitions & Instant Aesthetic Engine (Ring 0)
-- ----------------------------------------------------------------------------
-- Set leader keys strictly before lazy.nvim parses plugin key specs.
-- Keymap definitions are deferred to VeryLazy.

vim.g.mapleader      = " "
vim.g.maplocalleader = " "

local function apply_theme()
  if not pcall(vim.cmd.colorscheme, "x") then
    pcall(vim.cmd.colorscheme, "habamax")
  end
end

if #vim.api.nvim_list_uis() > 0 then
  apply_theme()
else
  vim.api.nvim_create_autocmd("UIEnter", {
    once = true,
    callback = apply_theme,
  })
end

-- ----------------------------------------------------------------------------
-- 4. Plugin manager (Ring 1: Lazy Bootstrap & Capability Discovery)
-- ----------------------------------------------------------------------------
-- Bootstraps and configures lazy.nvim.
-- Discovers plugin domains from lua/plugins/.

require("core.lazy")

-- ----------------------------------------------------------------------------
-- 5. Autocommands & System Lifecycle
-- ----------------------------------------------------------------------------
-- Core event handling, large file guard, and window syntax routing.

require("core.autocmds")

-- ----------------------------------------------------------------------------
-- 6. Deferred Lifecycle (Global Keymaps, ACP Runtime & Audit Router)
-- ----------------------------------------------------------------------------
-- Registers global editor mappings, ACP IPC runtime, and audit commands
-- after UI is rendered and interactive.

vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = function()
    require("core.keymaps")
    require("core.acp").setup()
    require("core.audit").setup()
    pcall(function()
      local ok_theme, theme = pcall(require, "theme")
      if ok_theme and theme.setup then
        theme.setup()
      end
    end)
  end,
})

