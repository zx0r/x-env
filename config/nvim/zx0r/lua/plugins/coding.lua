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
      { "rafamadriz/friendly-snippets", lazy = true },
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
        swift = { "swiftformat", "swift", stop_after_first = true },

        go = {
          "gofumpt",
          "goimports-reviser",
          "golines",
        },

        javascript = { "biome", "prettierd", "prettier", stop_after_first = true },
        javascriptreact = { "biome", "prettierd", "prettier", stop_after_first = true },
        typescript = { "biome", "prettierd", "prettier", stop_after_first = true },
        typescriptreact = { "biome", "prettierd", "prettier", stop_after_first = true },

        json = { "biome", "prettierd", "prettier", stop_after_first = true },
        jsonc = { "biome", "prettierd", "prettier", stop_after_first = true },
        yaml = { "prettierd", "prettier", stop_after_first = true },

        markdown = { "prettierd", "prettier", stop_after_first = true },
        ["markdown.mdx"] = { "prettierd", "prettier", stop_after_first = true },

        html = { "prettierd", "prettier", stop_after_first = true },
        css = { "biome", "prettierd", "prettier", stop_after_first = true },
        scss = { "prettierd", "prettier", stop_after_first = true },
        less = { "prettierd", "prettier", stop_after_first = true },
        handlebars = { "prettierd", "prettier", stop_after_first = true },
        graphql = { "biome", "prettierd", "prettier", stop_after_first = true },
        svelte = { "biome", "prettierd", "prettier", stop_after_first = true },
        astro = { "biome", "prettierd", "prettier", stop_after_first = true },
        vue = { "biome", "prettierd", "prettier", stop_after_first = true },

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
        swiftformat = {
          prepend_args = {
            "--quiet",
          },
        },

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

        prettierd = {
          condition = function(self, ctx)
            return vim.fs.find({ "biome.json", "biome.jsonc" }, { path = ctx.filename, upward = true })[1] == nil
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
      { "nvim-lua/plenary.nvim", lazy = true },
      { "nvim-treesitter/nvim-treesitter", lazy = true },
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
      { "nvim-treesitter/nvim-treesitter", lazy = true },
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

    keys = {
      {
        "gC",
        mode = { "n", "v" },
        desc = "Text case",
      },
    },

    cmd = {
      "TextCaseStartReplacingCommand",
    },

    config = function()
      require("textcase").setup({})
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
      {
        "<leader>cR",
        mode = { "n", "x" },
        function()
          require("ssr").open()
        end,
        desc = "Structural replace (Tree-sitter)",
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
      { "nvim-treesitter/nvim-treesitter", lazy = true },
      { "smoka7/hydra.nvim", lazy = true },
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

  -- ==========================================================================
  -- SPIDER (Subword motions for camelCase / snake_case)
  -- ==========================================================================
  {
    "chrisgrieser/nvim-spider",
    keys = {
      { "w", function() require("spider").motion("w") end, mode = { "n", "o", "x" }, desc = "Spider: Next subword" },
      { "e", function() require("spider").motion("e") end, mode = { "n", "o", "x" }, desc = "Spider: End of subword" },
      { "b", function() require("spider").motion("b") end, mode = { "n", "o", "x" }, desc = "Spider: Prev subword" },
      { "ge", function() require("spider").motion("ge") end, mode = { "n", "o", "x" }, desc = "Spider: Prev end of subword" },
    },
    opts = {
      skipInsignificantPunctuation = true,
    },
  },

  -- ==========================================================================
  -- PUPPETEER (Automatic template string conversion on ${ insertion)
  -- ==========================================================================
  {
    "chrisgrieser/nvim-puppeteer",
    dependencies = { { "nvim-treesitter/nvim-treesitter", lazy = true } },
    event = "InsertEnter",
    lazy = true,
  },

  -- ==========================================================================
  -- COMMENT-BOX (Formatted section headers and ASCII comment boxes)
  -- ==========================================================================
  {
    "LudoPinelli/comment-box.nvim",
    cmd = { "CBccbox", "CBllline", "CBline", "CBllbox14", "CBcatalog", "CBd" },
    keys = {
      { "<leader>cbb", "<cmd>CBccbox<cr>", mode = { "n", "v" }, desc = "Comment Box: Centered" },
      { "<leader>cbt", "<cmd>CBllline<cr>", mode = { "n", "v" }, desc = "Comment Box: Tiled line" },
      { "<leader>cbl", "<cmd>CBline<cr>", desc = "Comment Box: Simple line" },
      { "<leader>cbm", "<cmd>CBllbox14<cr>", mode = { "n", "v" }, desc = "Comment Box: Marked box" },
      { "<leader>cbc", "<cmd>CBcatalog<cr>", desc = "Comment Box: Catalog" },
      { "<leader>cbd", "<cmd>CBd<cr>", mode = { "n", "v" }, desc = "Comment Box: Delete style" },
    },
    opts = {},
  },

  -- ==========================================================================
  -- PACKAGE-INFO (Dependency version inspector for package.json)
  -- ==========================================================================
  {
    "vuki656/package-info.nvim",
    event = {
      "BufRead package.json",
      "BufRead package-lock.json",
    },
    opts = {},
    keys = {
      { "<leader>cv", function() require("package-info").show({ force = true }) end, desc = "Package: show versions" },
      { "<leader>cu", function() require("package-info").update() end, desc = "Package: update version" },
      { "<leader>cd", function() require("package-info").delete() end, desc = "Package: delete dependency" },
      { "<leader>cp", function() require("package-info").change_version() end, desc = "Package: change version" },
      { "<leader>ci", function() require("package-info").install() end, desc = "Package: install dependency" },
    },
  },

  -- ==========================================================================
  -- CODESNAP (macOS HIG code screenshots to clipboard/file)
  -- ==========================================================================
  {
    "mistricky/codesnap.nvim",
    build = "make",
    cmd = { "CodeSnap", "CodeSnapSave" },
    keys = {
      { "<leader>cs", mode = "x", "<cmd>CodeSnap<cr>", desc = "CodeSnap: clipboard" },
      { "<leader>cS", mode = "x", "<cmd>CodeSnapSave<cr>", desc = "CodeSnap: save image" },
    },
    opts = {
      save_path = (os.getenv("HOME") .. "/Pictures/Screenshots"),
      has_breadcrumbs = true,
      bg_theme = "summer",
      watermark = "",
    },
  },
}



