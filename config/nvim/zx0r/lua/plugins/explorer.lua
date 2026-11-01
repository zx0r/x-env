return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    cmd = { "Neotree" },
    dependencies = {
      { "nvim-lua/plenary.nvim", lazy = true },
      { "echasnovski/mini.icons", lazy = true },
      { "MunifTanjim/nui.nvim", lazy = true },
      {
        "antosha417/nvim-lsp-file-operations",
        opts = {},
      },
    },
    keys = {
      {
        "<leader>fe",
        function()
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree" then
              vim.cmd("Neotree close")
              return
            end
          end
          require("neo-tree.command").execute({ action = "focus", dir = vim.uv.cwd() })
        end,
        desc = "Explorer (cwd)",
      },
      {
        "<leader>fE",
        function()
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree" then
              vim.cmd("Neotree close")
              return
            end
          end
          local root = vim.fs.root(0, { ".git", "package.json", "Cargo.toml", "pyproject.toml" }) or vim.uv.cwd()
          require("neo-tree.command").execute({ action = "focus", dir = root })
        end,
        desc = "Explorer (Root)",
      },
      { "<leader>e", "<leader>fe", desc = "Explorer (cwd)", remap = true },
      { "<leader>E", "<leader>fE", desc = "Explorer (Root)", remap = true },
    },
    deactivate = function()
      vim.cmd([[Neotree close]])
    end,
    opts = {
      close_if_last_window = true,
      enable_diagnostics = true,
      enable_git_status = true,
      popup_border_style = "rounded",
      sources = { "filesystem", "buffers", "git_status" },
      hide_root_node = true,
      retain_hidden_root_indent = false,
      open_files_do_not_replace_types = { "terminal", "Trouble", "trouble", "qf", "Outline", "edgy" },
      source_selector = {
        winbar = false,
        statusline = false,
      },
      filesystem = {
        bind_to_cwd = false,
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
        hijack_netrw_behavior = "disabled",
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = true,
        },
        window = {
          mappings = {
            ["<c-/>"] = "fuzzy_finder_directory",
            ["o"] = "none",
          },
        },
      },
      buffers = {
        follow_current_file = { enabled = true },
        window = {
          mappings = {
            ["o"] = "none",
            ["bd"] = "none",
          },
        },
      },
      git_status = {
        window = {
          mappings = {
            ["<c-g>"] = "none",
            ["o"] = "none",
            ["gr"] = "none",
            ["gR"] = "git_revert_file",
          },
        },
      },
      default_component_configs = {
        indent = {
          with_expanders = true,
          expander_collapsed = "",
          expander_expanded = " ",
          expander_highlight = "NeoTreeExpander",
          indent_marker = "┃",
          last_indent_marker = "┗",
        },
        git_status = {
          symbols = {
            added = " ",
            modified = " ",
            deleted = " ",
            renamed = " ",
            untracked = " ",
            ignored = " ",
            unstaged = "󰄱 ",
            staged = " ",
            conflict = " ",
          },
        },
        icon = {
          folder_closed = "📁",
          folder_open = "📂",
          folder_empty = " ",
          default = "*",
          highlight = "NeoTreeFileIcon",
        },
        name = {
          use_git_status_colors = true,
          highlight = "NeoTreeFileName",
        },
      },
      window = {
        width = 30,
        mappings = {
          ["l"] = "open",
          ["h"] = "close_node",
          ["<space>"] = "none",
          ["o"] = "none",
          ["Y"] = {
            function(state)
              local node = state.tree:get_node()
              local path = node:get_id()
              vim.fn.setreg("+", path, "c")
              vim.notify("Copied: " .. path, vim.log.levels.INFO)
            end,
            desc = "Copy Path to Clipboard",
          },
          ["O"] = {
            function(state)
              vim.ui.open(state.tree:get_node().path)
            end,
            desc = "Open with System Application",
          },
          ["P"] = { "toggle_preview", config = { use_float = false } },
          ["q"] = {
            function()
              vim.cmd("Neotree close")
            end,
            desc = "Close Explorer Sidebar",
          },
        },
      },
    },
    config = function(_, opts)
      local events = require("neo-tree.events")
      opts.event_handlers = opts.event_handlers or {}
      if pcall(require, "snacks") then
        local function on_move(data)
          Snacks.rename.on_rename_file(data.source, data.destination)
        end
        vim.list_extend(opts.event_handlers, {
          { event = events.FILE_MOVED, handler = on_move },
          { event = events.FILE_RENAMED, handler = on_move },
        })
      end

      require("neo-tree").setup(opts)
      require("neo-tree").ensure_config()

      vim.api.nvim_create_autocmd("TermClose", {
        pattern = "*lazygit",
        callback = function()
          if package.loaded["neo-tree.sources.git_status"] then
            require("neo-tree.sources.git_status").refresh()
          end
        end,
      })
    end,
  },
  {
    "folke/edgy.nvim",
    event = "VeryLazy",
    opts = {
      animate = { enabled = false },
      options = {
        left = { size = 30 },
      },
      icons = {
        closed = " ",
        open = " ",
      },
      left = {
        {
          title = "󰉋 PROJECT",
          ft = "neo-tree",
          filter = function(buf)
            return vim.b[buf].neo_tree_source == "filesystem"
          end,
          pinned = true,
          size = { height = 0.55 },
          open = "Neotree show position=left filesystem",
        },
        {
          title = "󰈙 BUFFERS",
          ft = "neo-tree",
          filter = function(buf)
            return vim.b[buf].neo_tree_source == "buffers"
          end,
          pinned = true,
          size = { height = 0.30 },
          open = "Neotree show position=left buffers",
        },
        {
          title = "󰊢 VCS",
          ft = "neo-tree",
          filter = function(buf)
            return vim.b[buf].neo_tree_source == "git_status"
          end,
          pinned = true,
          size = { height = 0.15 },
          open = "Neotree show position=left git_status",
        },
      },
      keys = {
        -- increase width
        ["<c-Right>"] = function(win)
          win:resize("width", 2)
        end,
        -- decrease width
        ["<c-Left>"] = function(win)
          win:resize("width", -2)
        end,
        -- increase height
        ["<c-Up>"] = function(win)
          win:resize("height", 2)
        end,
        -- decrease height
        ["<c-Down>"] = function(win)
          win:resize("height", -2)
        end,
      },
    },
    keys = {
      {
        "<leader>ue",
        function()
          require("edgy").toggle("left")
        end,
        desc = "Edgy Toggle",
      },
      {
        "<leader>uE",
        function()
          require("edgy").select()
        end,
        desc = "Edgy Select Window",
      },
    },
  },

  -- ── Yazi: Blazing fast terminal file manager ─────────────────────────────
  {
    "mikavilpas/yazi.nvim",
    event = "VeryLazy",
    -- Edgy highlight setup: owned by edgy.nvim init block above.
    keys = {
      {
        "<leader>-",
        "<cmd>Yazi<cr>",
        desc = "Open yazi at the current file",
      },
      {
        "<leader>fy",
        "<cmd>Yazi<cr>",
        desc = "Open yazi at the current file",
      },
      {
        "<leader>fY",
        "<cmd>Yazi cwd<cr>",
        desc = "Open yazi in cwd",
      },
      {
        "<leader>cw",
        "<cmd>Yazi cwd<cr>",
        desc = "Open the file manager in nvim's working directory",
      },
      {
        "<c-up>",
        "<cmd>Yazi toggle<cr>",
        desc = "Resume the last yazi session",
      },
    },
    opts = {
      open_for_directories = false,
      keymaps = {
        show_help = "<f1>",
      },
    },
  },

  -- ── oil.nvim: directory editing as a buffer ─────────────────────────────
  {
    "stevearc/oil.nvim",
    cmd = { "Oil" },
    keys = {
      { "-", "<cmd>Oil<cr>", desc = "Open parent directory (oil)" },
      { "<leader>fo", "<cmd>Oil --float<cr>", desc = "Oil file explorer (float)" },
      {
        "<leader>fO",
        function()
          require("oil").open(vim.fn.getcwd())
        end,
        desc = "Oil cwd",
      },
    },
    opts = {
      default_file_explorer = true,
      columns = {
        { "icon", add_padding = false },
        { "permissions", highlight = "OilPermissions" },
        { "size", highlight = "OilSize" },
        { "mtime", highlight = "OilMtime" },
      },
      buf_options = {
        buflisted = false,
        bufhidden = "hide",
      },
      win_options = {
        wrap = false,
        signcolumn = "no",
        cursorcolumn = false,
        foldcolumn = "0",
        spell = false,
        list = false,
        conceallevel = 3,
        concealcursor = "nvic",
      },
      delete_to_trash = true,
      skip_confirm_for_simple_edits = true,
      prompt_save_on_select_new_entry = true,
      cleanup_delay_ms = 2000,
      lsp_file_methods = {
        enabled = true,
        timeout_ms = 1000,
        autosave_changes = false,
      },
      constrain_cursor = "editable",
      watch_for_changes = true,
      use_default_keymaps = false,
      keymaps = {
        ["g?"] = { "actions.show_help", mode = "n" },
        ["<CR>"] = { "actions.select", mode = "n" },
        ["<C-s>"] = { "actions.select", opts = { vertical = true }, mode = "n" },
        ["<C-h>"] = { "actions.select", opts = { horizontal = true }, mode = "n" },
        ["<C-t>"] = { "actions.select", opts = { tab = true }, mode = "n" },
        ["<C-p>"] = { "actions.preview", mode = "n" },
        ["<C-c>"] = { "actions.close", mode = "n" },
        ["<C-l>"] = { "actions.refresh", mode = "n" },
        ["-"] = { "actions.parent", mode = "n" },
        ["_"] = { "actions.open_cwd", mode = "n" },
        ["`"] = { "actions.cd", mode = "n" },
        ["~"] = { "actions.cd", opts = { scope = "tab" }, mode = "n" },
        ["gs"] = { "actions.change_sort", mode = "n" },
        ["gx"] = { "actions.open_external", mode = "n" },
        ["g."] = { "actions.toggle_hidden", mode = "n" },
        ["g\\"] = { "actions.toggle_trash", mode = "n" },
      },
      view_options = {
        show_hidden = false,
        is_hidden_file = function(name, _)
          return vim.startswith(name, ".")
        end,
        is_always_hidden = function(name, _)
          return name == ".." or name == ".DS_Store"
        end,
        natural_order = true,
        case_insensitive = false,
        sort = {
          { "type", "asc" },
          { "name", "asc" },
        },
      },
      float = {
        padding = 2,
        max_width = 90,
        max_height = 36,
        border = "rounded",
        win_options = { winblend = 0 },
      },
      preview = {
        max_width = { 100, 0.8 },
        min_width = { 40, 0.4 },
        width = nil,
        max_height = { 30, 0.9 },
        min_height = { 5, 0.1 },
        height = nil,
        border = "rounded",
        win_options = { winblend = 0 },
        update_on_cursor_moved = true,
      },
    },
  },
}
