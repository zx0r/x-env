-- ============================================================================
-- lua/plugins/ai.lua — AI Engineering Domain
-- CodeCompanion + MCPHub
--
-- Startup policy:
--   • No AI plugin is loaded during startup.
--   • CodeCompanion loads on explicit command/keymap.
--   • MCPHub loads only on explicit command/keymap.
--   • No synchronous external process is started during plugin setup.
-- ============================================================================

return {
  -- ── CodeCompanion ────────────────────────────────────────────────────────
  {
    "olimorris/codecompanion.nvim",

    cmd = {
      "CodeCompanion",
      "CodeCompanionChat",
      "CodeCompanionActions",
    },

    keys = {
      {
        "<leader>ac",
        mode = { "n", "v" },
        desc = "AI chat",
      },
      {
        "<leader>aa",
        mode = { "n", "v" },
        desc = "AI actions",
      },
      {
        "<leader>ae",
        mode = { "n", "v" },
        desc = "AI explain",
      },
    },

    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "ravitemer/mcphub.nvim",
    },

    opts = {
      -- ── Providers ────────────────────────────────────────────────────────
      -- API credentials are resolved from environment variables.
      adapters = {
        anthropic = function()
          return require("codecompanion.adapters").extend("anthropic", {
            env = {
              api_key = "ANTHROPIC_API_KEY",
            },
            schema = {
              model = {
                default = "claude-sonnet-4-5",
              },
            },
          })
        end,

        openai = function()
          return require("codecompanion.adapters").extend("openai", {
            env = {
              api_key = "OPENAI_API_KEY",
            },
            schema = {
              model = {
                default = "gpt-4o",
              },
            },
          })
        end,

        ollama = function()
          return require("codecompanion.adapters").extend("ollama", {
            schema = {
              model = {
                default = "qwen2.5-coder:7b",
              },
            },
          })
        end,
      },

      -- ── Strategies ───────────────────────────────────────────────────────
      strategies = {
        chat = {
          adapter = "anthropic",
        },

        inline = {
          adapter = "anthropic",
        },

        agent = {
          adapter = "anthropic",
        },
      },

      -- ── Display ──────────────────────────────────────────────────────────
      display = {
        chat = {
          window = {
            layout = "vertical",
            width = 0.40,
            height = 0.85,
            relative = "editor",
            border = "rounded",
          },

          render_headers = true,
          show_settings = true,
          show_token_count = true,

          buf_options = {
            buflisted = false,
          },
        },

        diff = {
          enabled = true,
          close_chat_at = 240,
          layout = "vertical",

          opts = {
            "internal",
            "filler",
            "closeoff",
            "algorithm:patience",
            "followwrap",
            "linematch:120",
          },

          provider = "default",
        },

        inline = {
          layout = "vertical",
        },

        action_palette = {
          width = 95,
          height = 10,
          prompt = "Prompt ",

          opts = {
            show_default_prompt_library = true,
          },
        },
      },

      -- ── MCP integration ──────────────────────────────────────────────────
      -- CodeCompanion is the MCP consumer.
      extensions = {
        mcphub = {
          enabled = true,

          callback = "mcphub.extensions.codecompanion",

          opts = {
            show_result_in_chat = true,
            make_vars = true,
            make_slash_commands = true,
          },
        },
      },

      -- ── Prompt library ───────────────────────────────────────────────────
      prompt_library = {
        ["Generate a Commit Message"] = {
          strategy = "chat",

          description = "Generate a conventional commit message",

          opts = {
            short_name = "commit",
            auto_submit = true,
          },

          prompts = {
            {
              role = "user",

              content = function()
                -- Size-gate: check stat before full diff to avoid blocking on huge diffs
                local stat = vim.system(
                  { "git", "diff", "--cached", "--stat" },
                  { text = true }
                ):wait(5000)

                if stat.code == 124 then
                  vim.notify("git diff --stat timed out after 5s", vim.log.levels.WARN)
                  return "Git diff timed out. Staged changes may be too large."
                end

                local stat_out = stat.stdout or ""
                if #stat_out == 0 then
                  return "No staged changes found. Stage files with `git add` first."
                end

                if #stat_out > 50000 then
                  vim.notify("Staged changes exceed 50KB; diff may be truncated", vim.log.levels.WARN)
                end

                local result = vim.system(
                  { "git", "diff", "--cached" },
                  { text = true }
                ):wait(5000)

                if result.code == 124 then
                  vim.notify("git diff timed out after 5s", vim.log.levels.WARN)
                  return "Git diff timed out. Staged changes may be too large."
                end

                local diff = (result.stdout or ""):gsub("%s+$", "")

                -- Truncate very large diffs to prevent LLM context overflow
                local max_len = 50000
                if #diff > max_len then
                  diff = diff:sub(1, max_len) .. "\n\n... [truncated — diff too large]"
                end

                return string.format(
                  "Write a conventional commit message for:\n```diff\n%s\n```",
                  diff
                )
              end,
            },
          },
        },

        ["Explain Code"] = {
          strategy = "chat",

          description = "Explain the selected code",

          opts = {
            short_name = "explain",
            modes = { "v" },
            auto_submit = true,
            stop_context_insertion = true,
          },

          prompts = {
            {
              role = "system",
              content = "You are a senior software engineer. Explain the code clearly and concisely.",
            },

            {
              role = "user",

              content = function(context)
                local code =
                  require("codecompanion.helpers.actions").get_code(
                    context.start_line,
                    context.end_line
                  )

                return string.format(
                  "Explain this %s code:\n```%s\n%s\n```",
                  context.filetype,
                  context.filetype,
                  code
                )
              end,
            },
          },
        },

        ["Refactor Code"] = {
          strategy = "inline",

          description = "Refactor the selected code",

          opts = {
            short_name = "refactor",
            modes = { "v" },
            auto_submit = true,
          },

          prompts = {
            {
              role = "system",
              content = "You are a principal engineer. Refactor the code for clarity, performance, and maintainability.",
            },

            {
              role = "user",

              content = function(context)
                local code =
                  require("codecompanion.helpers.actions").get_code(
                    context.start_line,
                    context.end_line
                  )

                return string.format(
                  "Refactor this %s code:\n```%s\n%s\n```",
                  context.filetype,
                  context.filetype,
                  code
                )
              end,
            },
          },
        },
      },

      -- ── Slash commands ───────────────────────────────────────────────────
      slash_commands = {
        buffer = {
          opts = {
            provider = "default",
          },
        },

        file = {
          opts = {
            provider = "default",
          },
        },

        help = {
          opts = {
            provider = "default",
          },
        },

        symbols = {
          opts = {
            provider = "default",
          },
        },
      },
    },
  },

  -- ── MCPHub ───────────────────────────────────────────────────────────────
  {
    "ravitemer/mcphub.nvim",

    cmd = {
      "MCPHub",
    },

    keys = {
      {
        "<leader>am",
        "<cmd>MCPHub<cr>",
        desc = "MCP hub",
      },
    },

    build = "bundled_build.lua",

    opts = {
      use_bundled_binary = true,

      server_config =
        vim.fn.stdpath("config") .. "/mcp-servers.json",

      auto_approve = false,

      ui = {
        window = {
          width = 0.85,
          height = 0.85,
          border = "rounded",
          zindex = 50,
        },
      },

      extensions = {
        avante = {
          enabled = false,
        },

        codecompanion = {
          enabled = true,
          show_result_in_chat = true,
          make_vars = true,
          make_slash_commands = true,
        },
      },

      log = {
        level = vim.log.levels.WARN,
        to_file = false,
        file_path = nil,
        prefix = "MCPHub",
      },
    },

    config = function(_, opts)
      require("mcphub").setup(opts)

      vim.api.nvim_create_autocmd("VimLeavePre", {
        group = vim.api.nvim_create_augroup(
          "plugin_mcp_cleanup",
          { clear = true }
        ),

        callback = function()
          local ok, hub = pcall(require, "mcphub")

          if ok and hub.stop_all then
            hub.stop_all()
          end
        end,
      })
    end,
  },
}
