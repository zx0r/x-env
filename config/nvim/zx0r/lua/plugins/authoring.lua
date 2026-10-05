-- ============================================================================
-- plugins/authoring.lua — Document Authoring Domain
-- SLA: <5ms load, defer everything to filetype
--
-- Domain: "How are technical documents authored/rendered?"
-- Owner: Markdown, Quarto, LaTeX, syntax visualization.
-- ============================================================================

return {

  -- ==========================================================================
  -- QUARTO
  -- ==========================================================================
  {
    "quarto-dev/quarto-nvim",
    ft = { "quarto" },
    cmd = { "QuartoActivate", "QuartoPreview", "QuartoClosePreview" },
    dependencies = { "jmbuhr/otter.nvim", "nvim-treesitter/nvim-treesitter" },
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
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = { buffers = { set_filetype = true } },
  },

  -- ==========================================================================
  -- RENDER MARKDOWN (Presentation layer)
  -- ==========================================================================
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "quarto", "norg", "rmd", "org" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "echasnovski/mini.icons" },
    opts = {
      render_modes = { "n", "c", "v", "V" },
      anti_conceal = { enabled = false },
      win_options = {
        conceallevel = { default = vim.o.conceallevel, rendered = 3 },
        concealcursor = { default = "", rendered = "nvc" },
      },
      file_types = { "markdown", "quarto", "norg", "rmd", "org" },
      heading = { enabled = true, sign = true },
      code = { enabled = true, sign = true, style = "language", width = "block", right_pad = 1, language_pad = 2 },
      checkbox = { enabled = true },
      latex = { enabled = true, converter = { "utftex", "latex2text" }, highlight = "RenderMarkdownMath", top_pad = 0, bottom_pad = 0 },
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
    init = function()
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
}
