-- ============================================================================
-- lua/plugins/coding.lua — Coding Domain
--
-- Domain:
--   Completion / snippets
--   Formatting
--   Linting
--   Refactoring
--   Code generation
--   Structural editing
--   Editing ergonomics
--
-- Boundaries:
--   language.lua -> LSP / Mason / Treesitter / language intelligence
--   debug.lua    -> DAP / debugging
--   vcs.lua      -> Git / VCS
--   ai.lua       -> AI / MCP
--   data.lua     -> Data / Database
--   ui.lua       -> UI / navigation
-- ============================================================================

return {

  -- ==========================================================================
  -- COMPLETION
  -- ==========================================================================

  {
    "saghen/blink.cmp",
    -- Фиксация на стабильной 1.x ветке (v1.10.x). Предотвращает поломку от v2.0 (ветка main)
    version = "1.*",
    event = "InsertEnter",

    dependencies = {
      {
        "rafamadriz/friendly-snippets",
        lazy = true,
      },
    },

    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      keymap = {
        preset = "enter",

        ["<C-space>"] = {
          "show",
          "show_documentation",
          "hide_documentation",
        },
        ["<C-e>"] = { "hide" },
        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
        ["<C-k>"] = { "select_prev", "fallback" },
        ["<C-j>"] = { "select_next", "fallback" },
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
        ["<CR>"] = { "accept", "fallback" },
      },

      appearance = {
        use_nvim_cmp_as_default = false,
        nerd_font_variant = "mono",
      },

      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        providers = {
          lsp = {
            name = "LSP",
            fallbacks = { "buffer" },
            score_offset = 100,
          },
          path = {
            name = "Path",
            score_offset = 25,
            opts = {
              trailing_slash = false,
              label_trailing_slash = true,
            },
          },
          snippets = {
            name = "Snippets",
            score_offset = 85,
            opts = {
              friendly_snippets = true,
              search_paths = {
                vim.fn.stdpath("config") .. "/snippets",
              },
            },
          },
          buffer = {
            name = "Buffer",
            score_offset = 15,
            min_keyword_length = 4,
          },
        },
      },

      completion = {
        accept = {
          auto_brackets = { enabled = true },
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
          update_delay_ms = 50,
          window = {
            max_width = 80,
            max_height = 20,
            border = "rounded",
          },
        },
        ghost_text = {
          enabled = true,
          show_with_selection = false,
        },
        menu = {
          border = "rounded",
          draw = {
            columns = {
              { "label", "label_description", gap = 1 },
              { "kind_icon", "kind", gap = 1 },
            },
          },
        },
        list = {
          selection = {
            preselect = true,
            auto_insert = true,
          },
          max_items = 200,
        },
      },

      fuzzy = {
        implementation = "prefer_rust_with_warning",
        use_proximity = true,
        frecency = { enabled = true },
        sorts = { "score", "sort_text" },
      },

      signature = {
        enabled = true,
        window = {
          border = "rounded",
          max_height = 10,
          max_width = 80,
        },
      },
    },

    opts_extend = { "sources.default" },
  },

  -- ==========================================================================
  -- FORMATTING
  -- ==========================================================================

  {
    "stevearc/conform.nvim",

    event = "BufWritePre",

    cmd = {
      "ConformInfo",
    },

    keys = {
      {
        "<leader>lf",
        function()
          require("conform").format({
            async = true,
            lsp_format = "fallback",
          })
        end,
        mode = { "n", "v" },
        desc = "Format buffer / selection",
      },
    },

    opts = {
      formatters_by_ft = {
        lua = { "stylua" },

        python = {
          "ruff_organize_imports",
          "ruff_format",
        },

        rust = { "rustfmt" },

        go = {
          "gofumpt",
          "goimports-reviser",
          "golines",
        },

        javascript = { "biome", "prettier", stop_after_first = true },
        javascriptreact = { "biome", "prettier", stop_after_first = true },
        typescript = { "biome", "prettier", stop_after_first = true },
        typescriptreact = { "biome", "prettier", stop_after_first = true },

        json = { "biome", "prettier", stop_after_first = true },
        jsonc = { "biome", "prettier", stop_after_first = true },
        yaml = { "prettier" },

        markdown = {
          "prettier",
        },

        html = { "prettier" },
        css = { "prettier" },
        scss = { "prettier" },

        nix = { "nixfmt" },

        terraform = { "terraform_fmt" },
        hcl = { "terraform_fmt" },

        sh = { "shfmt" },
        bash = { "shfmt" },
        zsh = { "shfmt" },
        fish = { "fish_indent" },

        sql = { "sql_formatter" },
        toml = { "taplo" },
        proto = { "buf" },

        ["*"] = {
          "trim_whitespace",
          "trim_newlines",
        },
      },

      -- Non-blocking formatting after save (Zero-stall I/O SLA: format_on_save -> format_after_save async)
      format_after_save = function(bufnr)
        if not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end

        if not vim.bo[bufnr].modifiable then
          return
        end

        if vim.bo[bufnr].buftype ~= "" then
          return
        end

        if vim.b[bufnr].large_file then
          return
        end

        if vim.b[bufnr].conform_disable then
          return
        end

        local ignored = {
          oil = true,
          help = true,
          gitcommit = true,
          gitrebase = true,
        }

        if ignored[vim.bo[bufnr].filetype] then
          return
        end

        return {
          lsp_format = "fallback",
        }
      end,

      default_format_opts = {
        lsp_format = "fallback",
      },

      formatters = {
        stylua = {
          prepend_args = {
            "--indent-type",
            "Spaces",
            "--indent-width",
            "2",
          },
        },

        shfmt = {
          prepend_args = {
            "-i",
            "2",
            "-ci",
            "-sr",
          },
        },

        biome = {
          condition = function(self, ctx)
            return vim.fs.find({ "biome.json", "biome.jsonc" }, { path = ctx.filename, upward = true })[1] ~= nil
          end,
        },

        prettier = {
          condition = function(self, ctx)
            return vim.fs.find({ "biome.json", "biome.jsonc" }, { path = ctx.filename, upward = true })[1] == nil
          end,
          prepend_args = {
            "--prose-wrap",
            "always",
            "--print-width",
            "100",
          },
        },

        ruff_format = {
          prepend_args = {
            "--line-length",
            "100",
          },
        },

        nixfmt = {
          command = "nixfmt",
          args = {
            "--width",
            "100",
          },
        },

        sql_formatter = {
          prepend_args = {
            "-l",
            "postgresql",
          },
        },

        golines = {
          prepend_args = {
            "--max-len",
            "120",
          },
        },
      },

      log_level = vim.log.levels.ERROR,
      notify_on_error = true,
      notify_no_formatters = false,
    },
  },

  -- ==========================================================================
  -- REFACTORING
  -- ==========================================================================

  {
    "ThePrimeagen/refactoring.nvim",

    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },

    keys = {
      {
        "<leader>re",
        mode = "v",
        function()
          require("refactoring").refactor("Extract Function")
        end,
        desc = "Extract function",
      },

      {
        "<leader>rf",
        mode = "v",
        function()
          require("refactoring").refactor("Extract Function To File")
        end,
        desc = "Extract function to file",
      },

      {
        "<leader>rv",
        mode = "v",
        function()
          require("refactoring").refactor("Extract Variable")
        end,
        desc = "Extract variable",
      },

      {
        "<leader>ri",
        function()
          require("refactoring").refactor("Inline Variable")
        end,
        desc = "Inline variable",
      },

      {
        "<leader>rr",
        mode = "v",
        function()
          require("refactoring").select_refactor()
        end,
        desc = "Select refactor",
      },
    },

    opts = {},
  },

  -- ==========================================================================
  -- CODE DOCUMENTATION
  -- ==========================================================================

  {
    "danymat/neogen",

    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },

    cmd = "Neogen",

    keys = {
      {
        "<leader>cn",
        function()
          require("neogen").generate()
        end,
        desc = "Generate annotation",
      },
    },

    opts = {
      snippet_engine = "nvim",
    },
  },


  -- ==========================================================================
  -- DEBUG PRINT
  -- ==========================================================================

  {
    "andrewferrier/debugprint.nvim",

    keys = {
      {
        "g?p",
        mode = "n",
        desc = "Debug print below",
      },

      {
        "g?P",
        mode = "n",
        desc = "Debug print above",
      },

      {
        "g?v",
        mode = { "n", "v" },
        desc = "Debug print variable below",
      },

      {
        "g?V",
        mode = { "n", "v" },
        desc = "Debug print variable above",
      },

      {
        "g?o",
        mode = "n",
        desc = "Debug print operator below",
      },

      {
        "g?O",
        mode = "n",
        desc = "Debug print operator above",
      },
    },

    opts = {},
  },

  -- ==========================================================================
  -- TEXT CASE
  -- ==========================================================================

  {
    "johmsalas/text-case.nvim",

    dependencies = {
      "nvim-telescope/telescope.nvim",
    },

    keys = {
      {
        "gC",
        mode = { "n", "v" },
        desc = "Text case",
      },
    },

    cmd = {
      "TextCaseOpenTelescope",
    },

    config = function()
      require("textcase").setup({})
      require("telescope").load_extension("textcase")
    end,
  },

  -- ==========================================================================
  -- TEXT OBJECTS
  -- ==========================================================================

  {
    "chrisgrieser/nvim-various-textobjs",

    event = "VeryLazy",

    opts = {
      useDefaultKeymaps = true,
    },
  },

  -- ==========================================================================
  -- ALIGNMENT
  -- ==========================================================================

  {
    "echasnovski/mini.align",

    keys = {
      {
        "ga",
        mode = { "n", "v" },
        desc = "Align",
      },

      {
        "gA",
        mode = { "n", "v" },
        desc = "Align with preview",
      },
    },

    opts = {},
  },

  -- ==========================================================================
  -- INDENT DETECTION
  -- ==========================================================================

  {
    "NMAC427/guess-indent.nvim",

    event = {
      "BufReadPost",
      "BufNewFile",
    },

    opts = {},
  },

  -- ==========================================================================
  -- AUTOPAIRS
  -- ==========================================================================

  {
    "altermo/ultimate-autopair.nvim",

    event = {
      "InsertEnter",
      "CmdlineEnter",
    },


    opts = {
      profile = "default",

      fastwarp = {
        enable = true,
        enable_normal = true,
        enable_reverse = true,
        map = "<C-e>",
        rmap = "<C-S-e>",
        cmap = "<C-e>",
      },

      tabout = {
        enable = true,
        map = "<A-Tab>",
        cmap = "<A-Tab>",
      },
    },
  },

  -- ==========================================================================
  -- STRUCTURAL SEARCH / REPLACE
  -- ==========================================================================

  {
    "cshuaimin/ssr.nvim",

    keys = {
      {
        "<leader>sR",
        mode = { "n", "x" },
        function()
          require("ssr").open()
        end,
        desc = "Structural replace",
      },
    },

    opts = {
      border = "rounded",

      min_width = 50,
      min_height = 5,

      max_width = 120,
      max_height = 25,

      adjust_window = true,

      keymaps = {
        close = "q",
        next_match = "n",
        prev_match = "N",
        replace_confirm = "<CR>",
        replace_all = "<leader><CR>",
      },
    },
  },

  -- ==========================================================================
  -- Undo / Redo feedback
  -- ==========================================================================

  {
    "tzachar/highlight-undo.nvim",

    event = "VeryLazy",

    opts = {
      duration = 700,

      undo = {
        hlgroup = "IncSearch",
      },

      redo = {
        hlgroup = "DiffAdd",
      },
    },
  },

  -- ==========================================================================
  -- MULTICURSORS (Hydra-powered multiple cursors from x0r_old)
  -- ==========================================================================
  {
    "smoka7/multicursors.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "smoka7/hydra.nvim",
    },
    cmd = { "MCstart", "MCvisual", "MCclear", "MCpattern", "MCvisualPattern", "MCunderCursor" },
    keys = {
      { mode = { "v", "n" }, "<leader>M", "<cmd>MCstart<cr>", desc = "Multicursor" },
    },
    opts = {
      hint_config = {
        border = "rounded",
        position = "bottom-right",
      },
      generate_hints = {
        normal = true,
        insert = true,
        extend = true,
        config = {
          column_count = 1,
        },
      },
    },
  },

  -- ==========================================================================
  -- BETTER ESCAPE (Fast jk / jj without timeout delay from x0r_old)
  -- ==========================================================================
  {
    "max397574/better-escape.nvim",
    event = "InsertEnter",
    opts = {},
  },
}
