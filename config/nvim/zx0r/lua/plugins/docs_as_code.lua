-- ============================================================================
-- plugins/docs_as_code.lua — Docs-as-Code & Scientific Publishing Domain
-- SLA: <5ms load, defer everything to filetype
--
-- Domain: "How are technical documents & knowledge authored/rendered?"
-- Owner: Markdown, Quarto, LaTeX, Obsidian PKM, syntax visualization.
-- ============================================================================

return {

  -- ==========================================================================
  -- QUARTO
  -- ==========================================================================
  {
    "quarto-dev/quarto-nvim",
    ft = { "quarto" },
    cmd = { "QuartoActivate", "QuartoPreview", "QuartoClosePreview" },
    dependencies = { { "jmbuhr/otter.nvim", lazy = true }, { "nvim-treesitter/nvim-treesitter", lazy = true } },
    opts = {
      lspFeatures = {
        languages = { "python", "r", "julia", "bash", "html" },
        chunks = "all",
        diagnostics = { enabled = true, triggers = { "BufWritePost" } },
        completion = { enabled = true },
      },
      codeRunner = { enabled = true, default_method = "molten" },
    },
    keys = {
      { "<leader>qa", "<cmd>QuartoActivate<cr>", desc = "Quarto: Activate" },
      { "<leader>qp", function() require("quarto").quartoPreview() end, desc = "Quarto: Preview" },
      { "<leader>qc", function() require("quarto").quartoClosePreview() end, desc = "Quarto: Close Preview" },
    },
  },

  -- ==========================================================================
  -- OTTER
  -- ==========================================================================
  {
    "jmbuhr/otter.nvim",
    ft = { "quarto" },
    dependencies = { { "nvim-treesitter/nvim-treesitter", lazy = true } },
    opts = { buffers = { set_filetype = true } },
  },

  -- ==========================================================================
  -- RENDER MARKDOWN (Presentation layer)
  -- ==========================================================================
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "quarto", "norg", "rmd", "org" },
    dependencies = { { "nvim-treesitter/nvim-treesitter", lazy = true }, { "echasnovski/mini.icons", lazy = true } },
    opts = {
      render_modes = { "n", "c", "v", "V" },
      debounce = 150,
      anti_conceal = { enabled = false },
      win_options = {
        conceallevel = { default = vim.o.conceallevel, rendered = 3 },
        concealcursor = { default = "nvc", rendered = "nvc" },
      },
      file_types = { "markdown", "quarto", "norg", "rmd", "org" },

      heading = {
        enabled = true,
        sign = true,
        position = "overlay",
        icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
        signs = { "󰫎 " },
        width = "block",
        left_pad = 0,
        right_pad = 2,
        min_width = 0,
        border = false,
      },

      code = {
        enabled = true,
        sign = true,
        style = "full",
        position = "left",
        language_pad = 2,
        language_name = true,
        language_icon = true,
        border = "thin",
        width = "block",
        right_pad = 2,
        disable = { "mermaid" },
      },

      dash = {
        enabled = true,
        icon = "─",
        width = "full",
      },

      bullet = {
        enabled = true,
        icons = { "●", "○", "◆", "◇" },
        right_pad = 1,
      },

      checkbox = {
        enabled = true,
        position = "inline",
        unchecked = { icon = "󰄱 " },
        checked = { icon = "󰄵 " },
        custom = {
          todo = { raw = "[-]", rendered = "󰥔 ", highlight = "RenderMarkdownTodo" },
          canceled = { raw = "[~]", rendered = "󰰱 ", highlight = "RenderMarkdownQuote" },
          important = { raw = "[!]", rendered = "󰀨 ", highlight = "RenderMarkdownError" },
        },
      },

      quote = {
        enabled = true,
        icon = "▋",
        repeat_linebreak = false,
      },

      pipe_table = {
        enabled = true,
        preset = "round",
        style = "full",
        cell = "padded",
        padding = 1,
        alignment_indicator = "━",
      },

      callout = {
        note      = { raw = "[!NOTE]",      rendered = "󰋽 Note",      highlight = "RenderMarkdownInfo" },
        tip       = { raw = "[!TIP]",       rendered = "󰌶 Tip",       highlight = "RenderMarkdownSuccess" },
        important = { raw = "[!IMPORTANT]", rendered = "󰅾 Important", highlight = "RenderMarkdownHint" },
        warning   = { raw = "[!WARNING]",   rendered = "󰀪 Warning",   highlight = "RenderMarkdownWarn" },
        caution   = { raw = "[!CAUTION]",   rendered = "󰳦 Caution",   highlight = "RenderMarkdownError" },
        abstract  = { raw = "[!ABSTRACT]",  rendered = "󰨸 Abstract",  highlight = "RenderMarkdownInfo" },
        summary   = { raw = "[!SUMMARY]",   rendered = "󰨸 Summary",   highlight = "RenderMarkdownInfo" },
        tldr      = { raw = "[!TLDR]",      rendered = "󰨸 Tldr",      highlight = "RenderMarkdownInfo" },
        info      = { raw = "[!INFO]",      rendered = "󰋽 Info",      highlight = "RenderMarkdownInfo" },
        todo      = { raw = "[!TODO]",      rendered = "󰗡 Todo",      highlight = "RenderMarkdownTodo" },
        success   = { raw = "[!SUCCESS]",   rendered = "󰄬 Success",   highlight = "RenderMarkdownSuccess" },
        question  = { raw = "[!QUESTION]",  rendered = "󰘥 Question",  highlight = "RenderMarkdownWarn" },
        failure   = { raw = "[!FAILURE]",   rendered = "󰅖 Failure",   highlight = "RenderMarkdownError" },
        danger    = { raw = "[!DANGER]",    rendered = "󱐌 Danger",    highlight = "RenderMarkdownError" },
        bug       = { raw = "[!BUG]",       rendered = "󰨰 Bug",       highlight = "RenderMarkdownError" },
        example   = { raw = "[!EXAMPLE]",   rendered = "󰉹 Example",   highlight = "RenderMarkdownHint" },
        quote     = { raw = "[!QUOTE]",     rendered = "󱆨 Quote",     highlight = "RenderMarkdownQuote" },
      },

      link = {
        enabled = true,
        footnote = { superscript = true, prefix = "", suffix = "" },
        image = "󰥶 ",
        email = "󰇮 ",
        hyperlink = "󰌹 ",
        wiki = { icon = "󱗖 ", highlight = "RenderMarkdownWikiLink" },
      },

      sign = {
        enabled = true,
      },

      latex = {
        enabled = false,
      },
    },
    keys = {
      { "<leader>tm", "<cmd>RenderMarkdown toggle<cr>", desc = "Markdown: Toggle Render" },
    },
  },

  -- ==========================================================================
  -- LIVE PREVIEW (Markdown, Quarto, Mermaid, MMD)
  -- ==========================================================================
  {
    "iamcco/markdown-preview.nvim",
    branch = "master",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    build = function(plugin)
      vim.cmd("source " .. plugin.dir .. "/autoload/mkdp/util.vim")
      vim.fn["mkdp#util#install"]()
    end,
    config = function()
      vim.g.mkdp_filetypes = { "markdown", "quarto", "mermaid", "mmd" }

      vim.g.mkdp_auto_start = 0
      vim.g.mkdp_auto_close = 1
      vim.g.mkdp_refresh_slow = 0
      vim.g.mkdp_command_for_global = 0
      vim.g.mkdp_open_to_the_world = 0
      vim.g.mkdp_open_ip = ""
      vim.g.mkdp_browser = ""
      vim.g.mkdp_echo_preview_url = 1
      vim.g.mkdp_browserfunc = ""
      vim.g.mkdp_markdown_css = ""
      vim.g.mkdp_highlight_css = ""
      vim.g.mkdp_port = ""
      vim.g.mkdp_page_title = "「${name}」"
      vim.g.mkdp_theme = "dark"
      vim.g.mkdp_combine_preview = 0
      vim.g.mkdp_combine_preview_auto_refresh = 1

      vim.g.mkdp_preview_options = {
        mkit = {},
        katex = {},
        uml = {},
        maid = {
          theme = "dark",
        },
        disable_sync_scroll = 0,
        sync_scroll_type = "middle",
        hide_yaml_meta = 1,
        sequence_diagrams = {},
        flowchart_diagrams = {},
        content_editable = false,
        disable_filename = 0,
        toc = {},
      }
    end,
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown: Toggle Live Preview" },
      { "<leader>ms", "<cmd>MarkdownPreview<cr>",       desc = "Markdown: Start Live Preview" },
      { "<leader>mx", "<cmd>MarkdownPreviewStop<cr>",   desc = "Markdown: Stop Live Preview" },
    },
  },

  -- ==========================================================================
  -- OBSIDIAN.NVIM — Knowledge Architecture & Second Brain
  -- Vault: ~/x/brain (SSOT Cognitive Substrate)
  -- ==========================================================================
  {
    "epwalsh/obsidian.nvim",
    version = "*",
    lazy = true,
    cmd = {
      "ObsidianOpen",
      "ObsidianNew",
      "ObsidianQuickSwitch",
      "ObsidianSearch",
      "ObsidianBacklinks",
      "ObsidianTags",
      "ObsidianToday",
      "ObsidianYesterday",
      "ObsidianTomorrow",
      "ObsidianDailies",
      "ObsidianTemplate",
      "ObsidianLink",
      "ObsidianLinkNew",
      "ObsidianPasteImg",
      "ObsidianRename",
      "ObsidianWorkspace",
    },
    event = {
      "BufReadPre " .. vim.fn.expand("~") .. "/x/brain/**.md",
      "BufNewFile " .. vim.fn.expand("~") .. "/x/brain/**.md",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    keys = {
      { "<leader>oo", "<cmd>ObsidianOpen<CR>", desc = "Obsidian: Open in App" },
      {
        "<leader>os",
        function()
          if Snacks and Snacks.picker then
            Snacks.picker.grep({ cwd = vim.fn.expand("~") .. "/x/brain" })
          else
            vim.cmd("ObsidianSearch")
          end
        end,
        desc = "Obsidian: Search / Grep (Snacks)",
      },
      {
        "<leader>og",
        function()
          if Snacks and Snacks.picker then
            Snacks.picker.grep({ cwd = vim.fn.expand("~") .. "/x/brain" })
          else
            vim.cmd("ObsidianSearch")
          end
        end,
        desc = "Obsidian: Grep (Snacks)",
      },
      { "<leader>sO", "<cmd>ObsidianSearch<CR>", desc = "Search: Obsidian Notes" },
      { "<leader>on", "<cmd>ObsidianNew<CR>", desc = "Obsidian: New Note" },
      {
        "<leader>o<space>",
        function()
          if Snacks and Snacks.picker then
            Snacks.picker.files({ cwd = vim.fn.expand("~") .. "/x/brain" })
          else
            vim.cmd("ObsidianQuickSwitch")
          end
        end,
        desc = "Obsidian: Quick Switch (Snacks)",
      },
      { "<leader>ob", "<cmd>ObsidianBacklinks<CR>", desc = "Obsidian: Backlinks" },
      { "<leader>ot", "<cmd>ObsidianTags<CR>", desc = "Obsidian: Tags" },
      { "<leader>oT", "<cmd>ObsidianTemplate<CR>", desc = "Obsidian: Insert Template" },
      { "<leader>od", "<cmd>ObsidianToday<CR>", desc = "Obsidian: Today's Daily Note" },
      { "<leader>oD", "<cmd>ObsidianDailies<CR>", desc = "Obsidian: Daily Notes List" },
      { "<leader>oy", "<cmd>ObsidianYesterday<CR>", desc = "Obsidian: Yesterday Note" },
      { "<leader>om", "<cmd>ObsidianTomorrow<CR>", desc = "Obsidian: Tomorrow Note" },
      { "<leader>oi", "<cmd>ObsidianPasteImg<CR>", desc = "Obsidian: Paste Image" },
      { "<leader>or", "<cmd>ObsidianRename<CR>", desc = "Obsidian: Rename Note" },
      { "<leader>ow", "<cmd>ObsidianWorkspace<CR>", desc = "Obsidian: Switch Workspace" },
      { "<leader>ol", "<cmd>ObsidianLink<CR>", mode = "v", desc = "Obsidian: Link Selection" },
      { "<leader>oL", "<cmd>ObsidianLinks<CR>", desc = "Obsidian: List Links" },
      { "<leader>oN", "<cmd>ObsidianLinkNew<CR>", mode = "v", desc = "Obsidian: Link to New Note" },
      { "<leader>oe", "<cmd>ObsidianExtractNote<CR>", mode = "v", desc = "Obsidian: Extract Note" },
    },
    opts = {
      workspaces = {
        {
          name = "brain",
          path = "~/x/brain",
        },
      },

      notes_subdir = "00_inbox/quick",

      daily_notes = {
        folder = "01_daily",
        date_format = "%Y-%m-%d",
        alias_format = "%B %-d, %Y",
        template = "Daily.md",
      },

      templates = {
        subdir = "_meta/templates",
        date_format = "%Y-%m-%d",
        time_format = "%H:%M",
      },

      attachments = {
        img_folder = "_meta/assets",
        img_text_func = function(client, path)
          path = client:vault_relative_path(path) or path
          return string.format("![%s](%s)", path.name, path)
        end,
      },

      note_id_func = function(title)
        local id = ""
        if title ~= nil then
          -- Transform to clean ASCII kebab-case (AGENTS.md §4.1)
          id = title:gsub(" ", "-"):gsub("[^A-Za-z0-9%-]", ""):lower()
          id = id:gsub("%-+", "-"):gsub("^%-", ""):gsub("%-$", "")
        end
        if id == "" then
          -- Fallback timestamp-entropy id
          id = tostring(os.date("%Y%m%d%H%M%S")) .. string.format("%04x", math.random(0, 0xffff))
        end
        return id
      end,

      mappings = {
        ["gf"] = {
          action = function()
            return require("obsidian").util.gf_passthrough()
          end,
          opts = { noremap = false, expr = true, buffer = true },
        },
        ["<C-c>"] = {
          action = function()
            return require("obsidian").util.toggle_checkbox()
          end,
          opts = { buffer = true },
        },
        ["<cr>"] = {
          action = function()
            return require("obsidian").util.smart_action()
          end,
          opts = { buffer = true, expr = true },
        },
      },

      disable_frontmatter = true,

      follow_url_func = function(url)
        vim.ui.open(url)
      end,
    },
    config = function(_, opts)
      local templates = require("obsidian.templates")
      local orig = templates.substitute_template_variables
      templates.substitute_template_variables = function(text, client, note)
        text = orig(text, client, note)
        local tz = os.date("%z")
        local tz_colon = #tz == 5 and (tz:sub(1, 3) .. ":" .. tz:sub(4, 5)) or tz
        local now = os.date("%Y-%m-%dT%H:%M:%S") .. tz_colon

        -- 1. Format-specific date variables (e.g. {{date:YYYYMMDD}}, {{date:YYYY-MM-DD}}, {{date:YYYY-[W]WW}})
        text = text:gsub("{{%s*date:([^}]+)%s*}}", function(fmt)
          local strftime = fmt:gsub("YYYY", "%%Y")
            :gsub("MM", "%%m")
            :gsub("DD", "%%d")
            :gsub("HH", "%%H")
            :gsub("mm", "%%M")
            :gsub("ss", "%%S")
            :gsub("%[W%]WW", "W%%W")
          return os.date(strftime)
        end)

        -- 2. id: 26-char ULID / Git SHA fallback
        text = text:gsub("<%%%s*crypto%.randomUUID%(%)%.replace%([^%)]*%)%s*%%>", function()
          return vim.fn.sha256(vim.uv.random(32)):sub(1, 40)
        end)
        text = text:gsub("<%%%s*crypto%.randomUUID%(%)%s*%%>", function()
          return vim.fn.sha256(vim.uv.random(32)):sub(1, 40)
        end)

        -- 3. created / updated: ISO 8601 with timezone
        text = text:gsub("<%%%s*tp%.date%.now%(['\"]YYYY%-MM%-DDTHH:mm:ssZ['\"]%)%s*%%>", now)

        return text
      end

      require("obsidian").setup(opts)
    end,
  },

  -- ==========================================================================
  -- HELPVIEW (Rich rendering for :help documentation)
  -- ==========================================================================
  {
    "OXY2DEV/helpview.nvim",
    ft = { "help" },
    dependencies = { { "nvim-treesitter/nvim-treesitter", lazy = true } },
    opts = {},
  },

  -- ==========================================================================
  -- IMG-CLIP (Clipboard image pasting into documents)
  -- ==========================================================================
  {
    "HakonHarnes/img-clip.nvim",
    cmd = { "PasteImage" },
    keys = {
      { "<leader>P", "<cmd>PasteImage<cr>", desc = "Paste clipboard image" },
    },
    opts = {
      default = {
        embed_image_as_base64 = false,
        prompt_for_file_name = false,
        drag_and_drop = { insert_mode = true },
      },
    },
  },
}

