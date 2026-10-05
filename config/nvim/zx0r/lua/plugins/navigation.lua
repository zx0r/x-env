-- ============================================================================
-- ~/.config/nvim/lua/plugins/navigation.lua — Navigation Domain
--
-- Responsibilities:
--   - Filesystem navigation
--   - File tree navigation
--   - Spatial cursor navigation
--   - Explicit file pinning / recall
--   - Motion-oriented navigation
--
-- Boundaries:
--   language.lua -> LSP / language intelligence
--   coding.lua   -> completion / refactoring / code editing
--   picker.lua   -> search / fuzzy selection
--   vcs.lua      -> Git / VCS
--   ui.lua       -> editor UI / presentation
--
-- Navigation stack:
--   Flash    -> spatial cursor movement
--   Harpoon  -> explicit file pinning / rapid recall
--
-- ============================================================================

return {

  -- ==========================================================================
  -- FLASH
  -- Fast spatial navigation
  -- ==========================================================================

  {
    "folke/flash.nvim",

    event = "VeryLazy",

    ---@type Flash.Config
    opts = {},

    keys = {
      {
        "s",
        mode = { "n", "x", "o" },
        function()
          require("flash").jump()
        end,
        desc = "Flash jump",
      },

      {
        "S",
        mode = { "n", "x", "o" },
        function()
          require("flash").treesitter()
        end,
        desc = "Flash Treesitter",
      },

      {
        "r",
        mode = "o",
        function()
          require("flash").remote()
        end,
        desc = "Flash remote",
      },

      {
        "R",
        mode = { "o", "x" },
        function()
          require("flash").treesitter_search()
        end,
        desc = "Flash Treesitter search",
      },

      {
        "<C-s>",
        mode = "c",
        function()
          require("flash").toggle()
        end,
        desc = "Toggle Flash search",
      },
    },
  },

  -- ==========================================================================
  -- HARPOON
  -- Explicit spatial file pinning / rapid recall
  -- ==========================================================================

  {
    "ThePrimeagen/harpoon",

    branch = "harpoon2",

    dependencies = {
      "nvim-lua/plenary.nvim",
    },

    keys = {
      {
        "<leader>ha",
        function()
          require("harpoon"):list():add()
        end,
        desc = "Harpoon: add file",
      },

      {
        "<leader>hh",
        function()
          local harpoon = require("harpoon")

          harpoon.ui:toggle_quick_menu(
            harpoon:list()
          )
        end,
        desc = "Harpoon: menu",
      },

      {
        "<leader>h1",
        function()
          require("harpoon"):list():select(1)
        end,
        desc = "Harpoon: file 1",
      },

      {
        "<leader>h2",
        function()
          require("harpoon"):list():select(2)
        end,
        desc = "Harpoon: file 2",
      },

      {
        "<leader>h3",
        function()
          require("harpoon"):list():select(3)
        end,
        desc = "Harpoon: file 3",
      },

      {
        "<leader>h4",
        function()
          require("harpoon"):list():select(4)
        end,
        desc = "Harpoon: file 4",
      },

      {
        "<leader>hn",
        function()
          require("harpoon"):list():next()
        end,
        desc = "Harpoon: next",
      },

      {
        "<leader>hp",
        function()
          require("harpoon"):list():prev()
        end,
        desc = "Harpoon: previous",
      },
    },

    opts = {
      settings = {
        save_on_toggle = true,
        save_on_change = true,
      },

      default = {
        display = function(list_item)
          return vim.fn.fnamemodify(
            list_item.value,
            ":."
          )
        end,
      },
    },

    config = function(_, opts)
      require("harpoon"):setup(opts)
    end,
  },

  -- ==========================================================================
  -- PLENARY
  -- Shared dependency
  -- ==========================================================================

  {
    "nvim-lua/plenary.nvim",
    lazy = true,
  },

  -- ==========================================================================
  -- PICKER
  -- Fuzzy search and selection
  -- ==========================================================================

  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        enabled = true,
        ui_select = true,
        prompt = "   ",
        layout = {
          cycle = true,
          preset = function()
            return vim.o.columns >= 100 and "mac_pro" or "mac_compact"
          end,
        },
        layouts = {
          mac_pro = {
            layout = {
              box = "horizontal",
              backdrop = 60,
              width = 0.92,
              min_width = 90,
              height = 0.86,
              min_height = 24,
              border = "none",
              {
                box = "vertical",
                border = "rounded",
                title = " {title} {live} {flags} ",
                title_pos = "center",
                width = 0.30,
                { win = "input", height = 1, border = "bottom" },
                { win = "list", border = "none" },
              },
              {
                win = "preview",
                title = " {preview:Preview} ",
                title_pos = "center",
                border = "rounded",
                width = 0.70,
              },
            },
          },
          mac_compact = {
            layout = {
              box = "vertical",
              backdrop = 60,
              width = 0.92,
              height = 0.88,
              border = "none",
              {
                box = "vertical",
                border = "rounded",
                title = " {title} {live} {flags} ",
                title_pos = "center",
                height = 0.30,
                { win = "input", height = 1, border = "bottom" },
                { win = "list", border = "none" },
              },
              {
                win = "preview",
                title = " {preview:Preview} ",
                title_pos = "center",
                border = "rounded",
                height = 0.70,
              },
            },
          },
        },
        formatters = {
          file = {
            filename_first = true,
            truncate = "center",
            min_width = 40,
          },
        },
        sources = {
          files = {
            hidden = true,
            ignored = false,
          },
          grep = {
            hidden = true,
            ignored = false,
          },
        },
        win = {
          input = {
            keys = {
              ["<Esc>"] = { "close", mode = { "n", "i" } },
            },
          },
          preview = {
            wo = {
              number = true,
              relativenumber = false,
              signcolumn = "no",
              cursorline = true,
              wrap = false,
            },
          },
        },
      },
    },
    keys = {
      { "<leader>,", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<leader>:", function() Snacks.picker.command_history() end, desc = "Command History" },
      { "<leader><space>", function() Snacks.picker.files() end, desc = "Find Files (Local)" },
      -- Note: Short aliases (<leader>fb) intentionally overlap with grouped prefixes 
      -- (<leader>f*) to support both muscle-memory patterns.
      { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find Config File" },
      { "<leader>ff", function() Snacks.picker.files() end, desc = "Find Files (Local)" },
      { "<leader>fF", function() Snacks.picker.files({ cwd = os.getenv("X_ROOT") or (os.getenv("HOME") .. "/x") }) end, desc = "Find Files (Global)" },
      { "<leader>fg", function() Snacks.picker.git_files() end, desc = "Find Git Files" },
      { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent" },
      { "<leader>sg", function() Snacks.picker.grep() end, desc = "Grep (Local)" },
      { "<leader>sG", function() Snacks.picker.grep({ cwd = os.getenv("X_ROOT") or (os.getenv("HOME") .. "/x") }) end, desc = "Grep (Global)" },
      { "<leader>sb", function() Snacks.picker.lines() end, desc = "Grep Buffer Lines" },
      { "<leader>sw", function() Snacks.picker.grep_word() end, desc = "Visual selection or word", mode = { "n", "x" } },
      { "<leader>sh", function() Snacks.picker.help() end, desc = "Help Pages" },
      { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
      { "<leader>sq", function() Snacks.picker.qflist() end, desc = "Quickfix List" },
    }
  },
}
