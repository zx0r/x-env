-- lua/plugins/workspace.lua — Workspace Domain
--
-- Responsibilities:
--   - Project root detection
--   - Buffer-local workspace directory
--   - Workspace root caching
--   - Workspace lifecycle
--   - Explicit workspace commands
--
-- Non-responsibilities:
--   - File explorer                     -> explorer.lua
--   - Search / picker                   -> navigation.lua
--   - LSP workspace intelligence        -> language.lua
--   - Shell / terminal execution        -> terminal.lua
--   - Version control                   -> vcs.lua
--
-- Architecture:
--   - Native Neovim APIs only.
--   - Workspace root is derived from buffer context.
--   - Workspace directory is buffer-local.
--   - No plugin owns project-root detection.
--
-- Neovim >= 0.12
-- ============================================================================

return {
  {
    name = "workspace-policy",
    dir = vim.fn.stdpath("config"),
    virtual = true,
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "WorkspaceRoot", "WorkspaceCd" },
    config = function()
      local M = {}
      local group = vim.api.nvim_create_augroup("Workspace", { clear = true })

      local ROOT_MARKERS = {
        {
          "Cargo.toml",
          "go.mod",
          "go.work",
          "pyproject.toml",
          "uv.lock",
          "package.json",
          "deno.json",
          "deno.jsonc",
          "composer.json",
          "mix.exs",
          "Gemfile",
          "pom.xml",
          "build.gradle",
          "build.gradle.kts",
        },
        {
          "Makefile",
          "Taskfile.yml",
          "Taskfile.yaml",
          "justfile",
        },
        ".git",
      }

      local root_cache = {}

      local function cache_key(bufnr)
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name == "" then
          return vim.fn.getcwd()
        end
        return vim.fs.dirname(vim.fs.abspath(name))
      end

      ---@param bufnr? integer
      ---@return string?
      function M.root(bufnr)
        bufnr = bufnr or 0
        local key = cache_key(bufnr)
        if root_cache[key] ~= nil then
          return root_cache[key] or nil
        end
        local root = vim.fs.root(bufnr, ROOT_MARKERS)
        root_cache[key] = root or false
        return root
      end

      ---@param bufnr? integer
      ---@return boolean
      function M.set(bufnr)
        bufnr = bufnr or 0
        local root = M.root(bufnr)
        if not root then
          return false
        end
        if vim.fn.getcwd() ~= root then
          vim.cmd("tcd " .. vim.fn.fnameescape(root))
        end
        vim.b[bufnr].workspace_root = root
        return true
      end

      ---@param bufnr? integer
      ---@return string
      function M.cwd(bufnr)
        bufnr = bufnr or 0
        local root = vim.b[bufnr].workspace_root
        if root and root ~= "" then
          return root
        end
        return vim.fn.getcwd()
      end

      local function valid_buffer(bufnr)
        return vim.api.nvim_buf_is_valid(bufnr)
          and vim.bo[bufnr].buftype == ""
          and vim.api.nvim_buf_get_name(bufnr) ~= ""
      end

      vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        callback = function(args)
          if valid_buffer(args.buf) then
            M.set(args.buf)
          end
        end,
      })

      vim.api.nvim_create_autocmd("DirChanged", {
        group = group,
        callback = function()
          root_cache = {}
        end,
      })

      vim.api.nvim_create_user_command("WorkspaceRoot", function()
        local root = M.root(0)
        if root then
          vim.notify(root, vim.log.levels.INFO, {
            title = "Workspace",
          })
          return
        end
        vim.notify("Workspace root not found", vim.log.levels.WARN, {
          title = "Workspace",
        })
      end, {
        desc = "Show current workspace root",
      })

      vim.api.nvim_create_user_command("WorkspaceCd", function()
        if not M.set(0) then
          vim.notify("Workspace root not found", vim.log.levels.WARN, {
            title = "Workspace",
          })
        end
      end, {
        desc = "Change current buffer to workspace root",
      })

      -- If buffer is already open when policy loads, configure it
      local cur_buf = vim.api.nvim_get_current_buf()
      if valid_buffer(cur_buf) then
        M.set(cur_buf)
      end
    end,
  },
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore Session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore Last Session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Don't Save Current Session" },
    },
  },
  {
    "laytan/cloak.nvim",
    event = { "BufReadPre", "BufNewFile" },
    cmd = { "CloakDisable", "CloakEnable", "CloakToggle" },
    keys = {
      { "<leader>ck", function() require("cloak").toggle() end, desc = "Toggle Cloak" },
    },
    opts = {
      enabled = true,
      cloak_character = "*",
      highlight_group = "Comment",
      cloak_length = nil,
      patterns = {
        {
          file_pattern = { ".env*", "wrangler.toml", ".dev.vars*" },
          cloak_pattern = "=.+",
          replace = nil,
        },
      },
    },
  },
  {
    "lambdalisue/suda.vim",
    cmd = { "SudaRead", "SudaWrite" },
    keys = {
      { "<leader>W", "<cmd>SudaWrite<cr>", desc = "Suda Write (sudo save)" },
    },
  },
}
