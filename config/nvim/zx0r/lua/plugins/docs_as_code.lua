-- ============================================================================
-- plugins/docs_as_code.lua — Docs-as-Code & Scientific Publishing Domain
-- SLA: <5ms load, defer everything to filetype
--
-- Domain: "How are technical documents & knowledge authored/rendered?"
-- Owner: Markdown, Quarto, LaTeX, Obsidian PKM, syntax visualization.
-- ============================================================================

return {

  -- ==========================================================================
  --  ii.nvim: Terminal graphical coprocessor integration for Neovim (KGP / Sixel)
  --  Zero-latency asynchronous IPC over Unix domain socket with ordered rendering
  -- ==========================================================================
  {
    "zx0r/ii.nvim",
    ft = {
      "markdown",
      "markdown.mdx",
      "md",
      "mdx",
      "quarto",
      "qmd",
      "rmd",
      "ipynb",
      "tex",
      "plaintex",
      "latex",
      "typst",
      "typ",
      "mermaid",
      "mmd",
      "dot",
      "gv",
      "svg",
      "png",
      "csv",
      "tsv",
      "plotly",
      "vl",
      "vega",
      "vegalite",
      "chem",
      "mhchem",
      "zip",
      "jar",
      "whl",
      "tar",
      "tgz",
      "tbz2",
      "txz",
      "tzst",
    },
    cmd = { "Ii", "IiRender", "IiToggle", "IiClear", "IiPreview" },
    keys = {
      { "<leader>pr", "<cmd>IiRender<cr>", desc = "ii: Render buffer" },
      { "<leader>pt", "<cmd>IiToggle<cr>", desc = "ii: Toggle KGP rendering" },
      { "<leader>pc", "<cmd>IiClear<cr>", desc = "ii: Clear decorations" },
      { "<leader>pp", "<cmd>IiPreview<cr>", desc = "ii: Instant preview" },
    },
    opts = {
      -- 10ms debounce tuned for Apple ProMotion 120Hz displays (8.33ms frame window)
      debounce_ms = 10,
      -- IPC deadline timeout for complex multi-node vector charts
      timeout_ms = 3000,
    },
  },

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
      {
        "<leader>qp",
        function()
          require("quarto").quartoPreview()
        end,
        desc = "Quarto: Preview",
      },
      {
        "<leader>qc",
        function()
          require("quarto").quartoClosePreview()
        end,
        desc = "Quarto: Close Preview",
      },
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
      ui = { enable = false },

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
          local strftime = fmt
            :gsub("YYYY", "%%Y")
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
