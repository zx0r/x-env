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

        map("n", "<leader>gp", gs.preview_hunk, "Git: Preview hunk")

        map("n", "<leader>gd", gs.diffthis, "Git: Diff buffer")

        map("n", "<leader>gD", function()
          gs.diffthis("~")
        end, "Git: Diff HEAD~1")

        ------------------------------------------------------------------------
        -- Blame
        ------------------------------------------------------------------------

        map("n", "<leader>gb", function()
          gs.blame_line({
            full = true,
          })
        end, "Git: Blame line")

        map("n", "<leader>gl", gs.toggle_current_line_blame, "Git: Toggle line blame")

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

    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewFileHistory",
    },

    keys = {
      {
        "<leader>gO",
        "<cmd>DiffviewOpen<CR>",
        desc = "Git: Open diffview",
      },

      {
        "<leader>gL",
        "<cmd>DiffviewFileHistory %<CR>",
        desc = "Git: File history",
      },

      {
        "<leader>gC",
        "<cmd>DiffviewClose<CR>",
        desc = "Git: Close diffview",
      },
    },

    opts = {
      diff_binaries = false,

      enhanced_diff_hl = true,

      git_cmd = {
        "git",
      },

      use_icons = true,

      show_help_hints = true,

      watch_index = true,

      keymaps = {
        disable_defaults = false,

        view = {
          {
            "n",
            "q",
            "<cmd>DiffviewClose<CR>",
            {
              desc = "Git: Close diffview",
            },
          },
        },
      },

      hooks = {},
    },
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
      { "<leader>gB", function() Snacks.gitbrowse() end, desc = "Git: Browse repository" },
    },
  },
}
