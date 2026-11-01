-- ============================================================================
-- plugins/vcs.lua — Version Control System Domain
--
-- Responsibilities:
--   - Git change signs
--   - Hunk navigation and manipulation
--   - Git blame
--   - Diff and file history
--   - Multi-file diff / merge conflict UI
--   - Git worktrees
--   - TODO/FIXME source annotations
--
-- Non-responsibilities:
--   - Git installation
--   - Git configuration
--   - Commit/push/pull workflow
--   - Terminal lifecycle
--
-- Lazygit:
--   - Managed by Snacks terminal
--   - Opened through the global keymap layer
--
-- ============================================================================

return {
  -- ==========================================================================
  -- Gitsigns
  --
  -- Native Git buffer integration:
  --   - Signs
  --   - Hunk navigation
  --   - Stage/reset
  --   - Blame
  --   - Inline diff preview
  -- ==========================================================================

  {
    "lewis6991/gitsigns.nvim",

    event = {
      "BufReadPre",
      "BufNewFile",
    },

    opts = {
      --------------------------------------------------------------------------
      -- Signs
      --------------------------------------------------------------------------

      signs = {
        add = {
          text = "▎",
        },

        change = {
          text = "▎",
        },

        delete = {
          text = "",
        },

        topdelete = {
          text = "",
        },

        changedelete = {
          text = "▎",
        },

        untracked = {
          text = "▎",
        },
      },

      signs_staged = {
        add = {
          text = "▎",
        },

        change = {
          text = "▎",
        },

        delete = {
          text = "",
        },

        topdelete = {
          text = "",
        },

        changedelete = {
          text = "▎",
        },
      },

      signs_staged_enable = true,

      --------------------------------------------------------------------------
      -- Performance
      --------------------------------------------------------------------------

      update_debounce = 50,

      max_file_length = 40000,

      --------------------------------------------------------------------------
      -- Hunk preview
      --------------------------------------------------------------------------

      preview_config = {
        border = "rounded",
        style = "minimal",
        relative = "cursor",
        row = 0,
        col = 1,
      },

      --------------------------------------------------------------------------
      -- Current-line blame
      --------------------------------------------------------------------------

      current_line_blame = false,

      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol",
        delay = 300,
        ignore_whitespace = false,
        virt_text_priority = 100,
      },

      current_line_blame_formatter = "<author> — <author_time:%Y-%m-%d> — <summary>",

      --------------------------------------------------------------------------
      -- Buffer-local integration
      --------------------------------------------------------------------------

      on_attach = function(bufnr)
        ------------------------------------------------------------------------
        -- Large-file protection
        ------------------------------------------------------------------------

        if vim.b[bufnr].large_file then
          return
        end

        local gs = require("gitsigns")

        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, {
            buffer = bufnr,
            silent = true,
            desc = desc,
          })
        end

        ------------------------------------------------------------------------
        -- Hunk navigation
        --
        -- Preserve native diff navigation when already inside a diff buffer.
        ------------------------------------------------------------------------

        map("n", "]h", function()
          if vim.wo.diff then
            vim.cmd.normal({
              "]c",
              bang = true,
            })
          else
            gs.nav_hunk("next")
          end
        end, "Git: Next hunk")

        map("n", "[h", function()
          if vim.wo.diff then
            vim.cmd.normal({
              "[c",
              bang = true,
            })
          else
            gs.nav_hunk("prev")
          end
        end, "Git: Previous hunk")

        ------------------------------------------------------------------------
        -- Hunk operations
        ------------------------------------------------------------------------

        map({ "n", "v" }, "<leader>gs", gs.stage_hunk, "Git: Stage hunk")

        map({ "n", "v" }, "<leader>gr", gs.reset_hunk, "Git: Reset hunk")

        map("n", "<leader>gS", gs.stage_buffer, "Git: Stage buffer")

        map("n", "<leader>gu", gs.undo_stage_hunk, "Git: Undo stage hunk")

        map("n", "<leader>gR", gs.reset_buffer, "Git: Reset buffer")

        ------------------------------------------------------------------------
        -- Diff / preview
        ------------------------------------------------------------------------

        ------------------------------------------------------------------------
        -- Diff / preview
        ------------------------------------------------------------------------

        map("n", "<leader>gp", gs.preview_hunk, "Git: Preview hunk")

        ------------------------------------------------------------------------
        -- Blame
        ------------------------------------------------------------------------

        map("n", "<leader>gb", function()
          gs.blame_line({
            full = true,
          })
        end, "Git: Blame line")

        map("n", "<leader>gB", function()
          gs.blame()
        end, "Git: Blame buffer")

        map("n", "<leader>uB", gs.toggle_current_line_blame, "Git: Toggle line blame")

        ------------------------------------------------------------------------
        -- Hunk text object
        ------------------------------------------------------------------------

        map({ "o", "x" }, "ih", ":<C-u>Gitsigns select_hunk<CR>", "Git: Select hunk")
      end,
    },
  },

  -- ==========================================================================
  -- Diffview
  --
  -- Responsibilities:
  --   - Multi-file diffs
  --   - File history
  --   - Merge conflict inspection
  -- ==========================================================================

  {
    "sindrets/diffview.nvim",
    dependencies = { { "echasnovski/mini.icons", lazy = true } },

    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewFileHistory",
    },

    keys = {
      {
        "<leader>gd",
        "<cmd>DiffviewOpen<CR>",
        desc = "Git: Open diffview",
      },
      {
        "<leader>gD",
        "<cmd>DiffviewFileHistory<CR>",
        desc = "Git: Repo history",
      },
      {
        "<leader>gO",
        "<cmd>DiffviewOpen<CR>",
        desc = "Git: Open diffview (alias)",
      },
      {
        "<leader>gL",
        "<cmd>DiffviewFileHistory %<CR>",
        desc = "Git: File history",
      },
      {
        "<leader>gq",
        "<cmd>DiffviewClose<CR>",
        desc = "Git: Close diffview",
      },
    },

    opts = function(_, opts)
      local actions = require("diffview.actions")
      local prefix = "<leader>gC"

      opts = opts or {}
      opts.diff_binaries = false
      opts.enhanced_diff_hl = true
      opts.git_cmd = {
        "git",
        "-c",
        "log.showSignature=false",
        "-c",
        "diff.external=",
      }
      opts.use_icons = true
      opts.show_help_hints = true
      opts.watch_index = true

      opts.view = {
        default = { winbar_info = true },
        file_history = { winbar_info = true },
      }

      opts.hooks = {
        diff_buf_read = function(bufnr)
          vim.b[bufnr].view_activated = false
        end,
      }

      opts.keymaps = {
        disable_defaults = false,
        view = {
          { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Git: Close diffview" } },
          { "n", prefix .. "o", actions.conflict_choose("ours"), { desc = "Choose the OURS version of a conflict" } },
          { "n", prefix .. "t", actions.conflict_choose("theirs"), { desc = "Choose the THEIRS version of a conflict" } },
          { "n", prefix .. "b", actions.conflict_choose("base"), { desc = "Choose the BASE version of a conflict" } },
          { "n", prefix .. "a", actions.conflict_choose("all"), { desc = "Choose all the versions of a conflict" } },
          { "n", prefix .. "x", actions.conflict_choose("none"), { desc = "Delete the conflict region" } },
          { "n", prefix .. "O", actions.conflict_choose_all("ours"), { desc = "Choose the OURS version of a conflict for the whole file" } },
          { "n", prefix .. "T", actions.conflict_choose_all("theirs"), { desc = "Choose the THEIRS version of a conflict for the whole file" } },
          { "n", prefix .. "B", actions.conflict_choose_all("base"), { desc = "Choose the BASE version of a conflict for the whole file" } },
          { "n", prefix .. "A", actions.conflict_choose_all("all"), { desc = "Choose all the versions of a conflict for the whole file" } },
          { "n", prefix .. "X", actions.conflict_choose_all("none"), { desc = "Delete the conflict region for the whole file" } },
        },
        file_panel = {
          { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Git: Close diffview" } },
          { "n", prefix .. "O", actions.conflict_choose_all("ours"), { desc = "Choose the OURS version of a conflict for the whole file" } },
          { "n", prefix .. "T", actions.conflict_choose_all("theirs"), { desc = "Choose the THEIRS version of a conflict for the whole file" } },
          { "n", prefix .. "B", actions.conflict_choose_all("base"), { desc = "Choose the BASE version of a conflict for the whole file" } },
          { "n", prefix .. "A", actions.conflict_choose_all("all"), { desc = "Choose all the versions of a conflict for the whole file" } },
          { "n", prefix .. "X", actions.conflict_choose_all("none"), { desc = "Delete the conflict region for the whole file" } },
        },
      }

      return opts
    end,
  },

  -- ==========================================================================
  -- Git Worktree
  --
  -- Worktree lifecycle is owned by git-worktree.
  -- Selection is delegated to snacks.picker.
  -- ==========================================================================

  {
    "ThePrimeagen/git-worktree.nvim",

    keys = {
      {
        "<leader>gw",
        desc = "Git: Worktrees",
      },
    },

    config = function()
      require("git-worktree").setup()

      vim.keymap.set("n", "<leader>gw", function()
        local worktrees = require("git-worktree").get_worktrees()
        if worktrees and #worktrees > 0 then
          vim.ui.select(worktrees, {
            prompt = "Git Worktrees",
            format_item = function(wt)
              return wt.path or tostring(wt)
            end,
          }, function(choice)
            if choice then
              require("git-worktree").switch_worktree(choice.path)
            end
          end)
        else
          vim.notify("No worktrees found", vim.log.levels.INFO)
        end
      end, {
        silent = true,
        desc = "Git: Worktrees",
      })
    end,
  },

  -- ==========================================================================
  -- Snacks Lazygit & Git Utilities
  -- ==========================================================================

  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>gg", function() Snacks.lazygit() end, desc = "Git: Lazygit" },
      { "<leader>gf", function() Snacks.lazygit.log_file() end, desc = "Git: Lazygit file history" },
      {
        "<leader>gy",
        function()
          Snacks.gitbrowse()
        end,
        desc = "Git: Browse in web (remote)",
      },
    },
  },

  -- ==========================================================================
  -- Git Conflict: Inline merge conflict resolution
  -- ==========================================================================
  {
    "akinsho/git-conflict.nvim",
    cmd = {
      "GitConflictChooseOurs",
      "GitConflictChooseTheirs",
      "GitConflictChooseBoth",
      "GitConflictChooseNone",
      "GitConflictNextConflict",
      "GitConflictPrevConflict",
      "GitConflictListQf",
      "GitConflictRefresh",
    },
    opts = {
      default_mappings = {
        ours = "<leader>gCo",
        theirs = "<leader>gCt",
        none = "<leader>gCn",
        both = "<leader>gCb",
        next = "]g",
        prev = "[g",
      },
    },
    keys = {
      { "]g", "<cmd>GitConflictNextConflict<cr>", desc = "Git: Next conflict" },
      { "[g", "<cmd>GitConflictPrevConflict<cr>", desc = "Git: Prev conflict" },
      { "<leader>gCo", "<cmd>GitConflictChooseOurs<cr>", desc = "Git Conflict: Choose ours" },
      { "<leader>gCt", "<cmd>GitConflictChooseTheirs<cr>", desc = "Git Conflict: Choose theirs" },
      { "<leader>gCb", "<cmd>GitConflictChooseBoth<cr>", desc = "Git Conflict: Choose both" },
      { "<leader>gCn", "<cmd>GitConflictChooseNone<cr>", desc = "Git Conflict: Choose none" },
      { "<leader>gCl", "<cmd>GitConflictListQf<cr>", desc = "Git Conflict: List conflicts" },
      { "<leader>gCr", "<cmd>GitConflictRefresh<cr>", desc = "Git Conflict: Refresh" },
    },
    config = function(_, opts)
      require("git-conflict").setup(opts)
      vim.api.nvim_create_autocmd("User", {
        pattern = "GitConflictDetected",
        callback = function()
          vim.notify("Conflict detected in " .. vim.fn.expand("<afile>"), vim.log.levels.WARN)
        end,
      })
    end,
  },

  -- ==========================================================================
  -- Git Graph: Interactive Unicode commit graph with Diffview integration
  -- ==========================================================================
  {
    "isakbm/gitgraph.nvim",
    cmd = { "GitGraph" },
    keys = {
      {
        "<leader>gl",
        function()
          require("gitgraph").draw({}, { all = true, max_count = 5000 })
        end,
        desc = "Git: Interactive commit graph",
      },
      {
        "<leader>gG",
        function()
          require("gitgraph").draw({}, { all = true, max_count = 5000 })
        end,
        desc = "Git: Interactive commit graph (alias)",
      },
    },
    opts = {
      git_cmd = "git -c log.showSignature=false",
      symbols = {
        merge_commit = "",
        commit = "",
      },
      format = {
        timestamp = "%H:%M:%S %d-%m-%Y",
        fields = { "hash", "timestamp", "author", "branch_name", "tag" },
      },
      hooks = {
        on_select_commit = function(commit)
          vim.cmd(":DiffviewOpen " .. commit.hash .. "^!")
        end,
        on_select_range_commit = function(from, to)
          vim.cmd(":DiffviewOpen " .. from.hash .. "~1.." .. to.hash)
        end,
      },
    },
    config = function(_, opts)
      require("gitgraph").setup(opts)
      vim.api.nvim_create_user_command("GitGraph", function()
        require("gitgraph").draw({}, { all = true, max_count = 5000 })
      end, { desc = "Git: Draw interactive commit graph" })
    end,
  },
}
