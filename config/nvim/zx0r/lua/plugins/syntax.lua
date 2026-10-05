-- lua/plugins/syntax.lua — Syntax & Structural Analysis Domain
--
-- Responsibilities:
--   - Tree-sitter parser lifecycle and configuration
--   - Incremental syntax parsing
--   - Syntax highlighting
--   - Structural textobjects and selections
--   - Syntax-aware navigation and context
--   - Tree-sitter queries and language-specific structure
--
-- Non-responsibilities:
--   - LSP / semantic language intelligence -> language.lua
--   - Completion / snippets              -> coding.lua
--   - Formatting / linting              -> coding.lua / diagnostics.lua
--   - Testing                            -> testing.lua
--   - Debugging                          -> debug.lua
--   - Markdown / Quarto rendering       -> markdown.lua
--
-- Architecture:
--   - Own syntax structure, not semantic language intelligence.
--   - Prefer native Neovim / Tree-sitter capabilities.
--   - Keep parser and query configuration local to this domain.
--   - Avoid duplicating capabilities owned by other domains.
--
-- Target:
--   - Neovim >= 0.12
--   - Current nvim-treesitter API
-- ============================================================================

return {
  -- ==========================================================================
  -- TREE-SITTER
  -- ==========================================================================

  {
    "nvim-treesitter/nvim-treesitter",

    event = { "BufReadPost", "BufNewFile", "BufWritePre" },
    cmd = { "TSUpdateSync", "TSUpdate", "TSInstall" },

    build = ":TSUpdate",

    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
    },

    opts = {
      -- ----------------------------------------------------------------------
      -- Parser registry
      --
      -- Keep this list explicit. Installing parsers is infrastructure
      -- provisioning, not something that should happen implicitly for every
      -- opened file.
      -- ----------------------------------------------------------------------

      ensure_installed = {
        -- Lua
        "lua",
        "luadoc",
        "luap",

        -- Python
        "python",

        -- Rust
        "rust",

        -- Go
        "go",
        "gomod",
        "gosum",
        "gowork",

        -- JavaScript / TypeScript
        "javascript",
        "typescript",
        "tsx",
        "jsdoc",

        -- Infrastructure
        "nix",
        "terraform",
        "hcl",
        "bash",
        "fish",
        "yaml",
        "json",
        "json5",
        "toml",
        "sql",
        "dockerfile",
        "proto",

        -- Documents
        "markdown",
        "markdown_inline",
        "typst",
        "latex",

        -- Web
        "html",
        "css",
        "scss",
        "svelte",
        "vue",

        -- Editor / configuration
        "regex",
        "query",
        "vim",
        "vimdoc",

        -- Native / build
        "c",
        "make",
        "cmake",

        -- VCS / misc
        "git_config",
        "git_rebase",
        "gitcommit",
        "gitignore",
        "diff",
      },
    },

    config = function(_, opts)
      --------------------------------------------------------------------------
      -- Native nvim-treesitter setup
      --
      -- The current nvim-treesitter API no longer uses:
      --
      --   require("nvim-treesitter.configs").setup(...)
      --
      -- Parser management is handled through the current module API.
      --------------------------------------------------------------------------

      local treesitter = require("nvim-treesitter")

      treesitter.setup(opts)

      --------------------------------------------------------------------------
      -- Filetype mapping
      --
      -- Ensure LaTeX and BibTeX filetypes are explicitly associated with their
      -- respective Tree-sitter parsers (mapping .tex, plaintex, and .bib).
      --------------------------------------------------------------------------

      vim.treesitter.language.register("latex", { "tex", "plaintex", "latex" })
      vim.treesitter.language.register("bibtex", { "bib", "bibtex" })


      --------------------------------------------------------------------------
      -- Parser installation
      --
      -- Install only parsers that are not already available in runtimepath.
      -- This prevents unnecessary installation work on every startup.
      --------------------------------------------------------------------------

      vim.schedule(function()
        local missing = {}

        for _, language in ipairs(opts.ensure_installed or {}) do
          local parsers = vim.api.nvim_get_runtime_file(
            "parser/" .. language .. ".*",
            false
          )

          if #parsers == 0 then
            missing[#missing + 1] = language
          end
        end

        if #missing > 0 then
          treesitter.install(missing, { summary = true })
        end
      end)

      --------------------------------------------------------------------------
      -- Native highlighting
      --
      -- Neovim owns the Tree-sitter highlighting lifecycle.
      --
      -- Large buffers are explicitly excluded to protect editor responsiveness.
      --------------------------------------------------------------------------

      local highlight_group = vim.api.nvim_create_augroup(
        "core_treesitter_highlight",
        { clear = true }
      )

      vim.api.nvim_create_autocmd("FileType", {
        group = highlight_group,

        callback = function(event)
          local bufnr = event.buf

          if not vim.api.nvim_buf_is_valid(bufnr) then
            return
          end

          ----------------------------------------------------------------------
          -- Ignore special buffers
          ----------------------------------------------------------------------

          if vim.bo[bufnr].buftype ~= "" then
            return
          end

          ----------------------------------------------------------------------
          -- Large-file protection
          ----------------------------------------------------------------------

          local filename = vim.api.nvim_buf_get_name(bufnr)

          if filename == "" then
            return
          end

          local ok, stat = pcall(
            vim.uv.fs_stat,
            filename
          )

          if ok and stat and stat.size > 100 * 1024 * 1024 then
            vim.b[bufnr].large_file = true
            return
          end

          ----------------------------------------------------------------------
          -- Start Tree-sitter
          ----------------------------------------------------------------------

          pcall(vim.treesitter.start, bufnr)
        end,
      })
    end,
  },

  -- ==========================================================================
  -- TREE-SITTER TEXTOBJECTS
  --
  -- Structural editing belongs to the Tree-sitter domain.
  -- ==========================================================================

  {
    "nvim-treesitter/nvim-treesitter-textobjects",

    event = {
      "BufReadPost",
      "BufNewFile",
    },

    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },

    opts = {
      select = {
        lookahead = true,

        selection_modes = {
          ["@parameter.outer"] = "v",
          ["@function.outer"] = "V",
          ["@class.outer"] = "V",
        },

        include_surrounding_whitespace = false,
      },

      move = {
        set_jumps = true,
      },

      swap = {
        swap_next = {
          ["<leader>na"] = "@parameter.inner",
          ["<leader>nf"] = "@function.outer",
        },

        swap_previous = {
          ["<leader>nA"] = "@parameter.inner",
          ["<leader>nF"] = "@function.outer",
        },
      },
    },

    keys = {
      -- ----------------------------------------------------------------------
      -- Select text objects
      -- ----------------------------------------------------------------------

      {
        "af",
        mode = { "x", "o" },
        function()
          require("nvim-treesitter-textobjects.select").select_textobject(
            "@function.outer",
            "textobjects"
          )
        end,
        desc = "Select function",
      },

      {
        "if",
        mode = { "x", "o" },
        function()
          require("nvim-treesitter-textobjects.select").select_textobject(
            "@function.inner",
            "textobjects"
          )
        end,
        desc = "Select function inner",
      },

      {
        "ac",
        mode = { "x", "o" },
        function()
          require("nvim-treesitter-textobjects.select").select_textobject(
            "@class.outer",
            "textobjects"
          )
        end,
        desc = "Select class",
      },

      {
        "ic",
        mode = { "x", "o" },
        function()
          require("nvim-treesitter-textobjects.select").select_textobject(
            "@class.inner",
            "textobjects"
          )
        end,
        desc = "Select class inner",
      },

      {
        "aa",
        mode = { "x", "o" },
        function()
          require("nvim-treesitter-textobjects.select").select_textobject(
            "@parameter.outer",
            "textobjects"
          )
        end,
        desc = "Select parameter",
      },

      {
        "ia",
        mode = { "x", "o" },
        function()
          require("nvim-treesitter-textobjects.select").select_textobject(
            "@parameter.inner",
            "textobjects"
          )
        end,
        desc = "Select parameter inner",
      },

      -- ----------------------------------------------------------------------
      -- Navigate between functions
      -- ----------------------------------------------------------------------

      {
        "]f",
        function()
          require("nvim-treesitter-textobjects.move").goto_next_start(
            "@function.outer",
            "textobjects"
          )
        end,
        desc = "Next function",
      },

      {
        "[f",
        function()
          require("nvim-treesitter-textobjects.move").goto_previous_start(
            "@function.outer",
            "textobjects"
          )
        end,
        desc = "Previous function",
      },

      {
        "]F",
        function()
          require("nvim-treesitter-textobjects.move").goto_next_end(
            "@function.outer",
            "textobjects"
          )
        end,
        desc = "Next function end",
      },

      {
        "[F",
        function()
          require("nvim-treesitter-textobjects.move").goto_previous_end(
            "@function.outer",
            "textobjects"
          )
        end,
        desc = "Previous function end",
      },

      -- ----------------------------------------------------------------------
      -- Navigate between classes
      -- ----------------------------------------------------------------------

      {
        "]c",
        function()
          require("nvim-treesitter-textobjects.move").goto_next_start(
            "@class.outer",
            "textobjects"
          )
        end,
        desc = "Next class",
      },

      {
        "[c",
        function()
          require("nvim-treesitter-textobjects.move").goto_previous_start(
            "@class.outer",
            "textobjects"
          )
        end,
        desc = "Previous class",
      },
    },
  },

  -- ==========================================================================
  -- CONTEXT
  --
  -- Displays the structural context of the current location.
  -- ==========================================================================

  {
    "nvim-treesitter/nvim-treesitter-context",

    event = "BufReadPost",

    opts = {
      enable = true,

      max_lines = 3,

      min_window_height = 20,

      line_numbers = true,

      mode = "topline",

      separator = "─",

      zindex = 20,

      on_attach = function(buf)
        return vim.api.nvim_buf_is_valid(buf)
          and vim.bo[buf].buftype == ""
          and vim.bo[buf].modifiable
          and not vim.b[buf].large_file
      end,
    },
  },

  -- ==========================================================================
  -- Rainbow delimiters
  -- ==========================================================================

  {
    "HiPhish/rainbow-delimiters.nvim",

    event = {
      "BufReadPost",
      "BufNewFile",
    },

    config = function()
      local ok, lib = pcall(require, "rainbow-delimiters.lib")
      if ok and lib and lib.attach then
        local orig_attach = lib.attach
        lib.attach = function(bufnr)
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(bufnr) then
              orig_attach(bufnr)
            end
          end)
        end
      end

      vim.g.rainbow_delimiters = {
        strategy = {
          [""] = "rainbow-delimiters.strategy.global",
          vim = "rainbow-delimiters.strategy.local",
        },

        query = {
          [""] = "rainbow-delimiters",
          lua = "rainbow-delimiters",
        },

        priority = {
          [""] = 250,
          lua = 250,
        },

        highlight = {
          "RainbowDelimiterYellow",
          "RainbowDelimiterViolet",
          "RainbowDelimiterBlue",
          "RainbowDelimiterOrange",
          "RainbowDelimiterCyan",
          "RainbowDelimiterGreen",
          "RainbowDelimiterRed",
        },

        condition = function(bufnr)
          -- Large buffer protection: avoid heavy AST delimiter walk on files > 1000 lines
          return vim.api.nvim_buf_line_count(bufnr) <= 1000
        end,
      }

      local bufnr = vim.api.nvim_get_current_buf()
      if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "" and vim.bo[bufnr].filetype ~= "" then
        pcall(require("rainbow-delimiters.lib").attach, bufnr)
      end
    end,
  },

  -- ==========================================================================
  -- Virtual code-block context
  -- ==========================================================================

  {
    "haringsrob/nvim_context_vt",

    event = "VeryLazy",

    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },

    opts = {
      prefix = "  󱞷",

      highlight = "NonText",

      min_rows = 8,

      disable_ft = {
        "markdown",
        "yaml",
        "css",
        "toml",
        "json",
      },

      disable_virtual_lines_ft = {
        "yaml",
        "python",
      },
    },

    keys = {
      {
        "<leader>ux",
        "<cmd>NvimContextVtToggle<cr>",
        desc = "Toggle block context",
      },
    },
  },

  -- ==========================================================================
  -- SNACKS SCOPE & INDENT
  --
  -- Structural navigation, Treesitter scope textobjects, and indentation guides
  -- ==========================================================================

  {
    "folke/snacks.nvim",
    opts = {
      scope = {
        enabled = true,
        char = "│",
        underline = false,
        only_current = false,
        hl = "SnacksIndentScope",
      },
      indent = {
        enabled = true,
        char = "│",
        hl = "SnacksIndent",
        animate = { enabled = false },
      },
    },
  },
}
