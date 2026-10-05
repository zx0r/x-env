-- ============================================================================
-- lua/plugins/debug.lua — Debugging Domain
-- Neovim >= 0.12
--
-- Architecture:
--   nvim-dap      → DAP client
--   nvim-dap-ui   → optional debugging UI
--   nvim-nio      → async runtime required by dap-ui
--
-- Loading policy:
--   Zero startup cost.
--   The entire domain is loaded only when a <leader>d mapping is invoked.
--
-- External debug adapters:
--   Python       → debugpy
--   Go           → delve
--   Rust/C/C++   → codelldb
--   JS/TS        → js-debug-adapter
--
-- Adapters are expected to be installed by the existing Mason/tooling domain.
-- ============================================================================

return {
  -- ── DAP client ────────────────────────────────────────────────────────────
  {
    "mfussenegger/nvim-dap",

    keys = {
      {
        "<leader>db",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "Debug: Toggle breakpoint",
      },
      {
        "<leader>dB",
        function()
          require("dap").set_breakpoint(vim.fn.input("Condition: "))
        end,
        desc = "Debug: Conditional breakpoint",
      },
      {
        "<leader>dc",
        function()
          require("dap").continue()
        end,
        desc = "Debug: Continue",
      },
      {
        "<leader>di",
        function()
          require("dap").step_into()
        end,
        desc = "Debug: Step into",
      },
      {
        "<leader>do",
        function()
          require("dap").step_over()
        end,
        desc = "Debug: Step over",
      },
      {
        "<leader>dO",
        function()
          require("dap").step_out()
        end,
        desc = "Debug: Step out",
      },
      {
        "<leader>dr",
        function()
          require("dap").repl.open()
        end,
        desc = "Debug: REPL",
      },
      {
        "<leader>dl",
        function()
          require("dap").run_last()
        end,
        desc = "Debug: Run last",
      },
      {
        "<leader>du",
        function()
          require("dapui").toggle()
        end,
        desc = "Debug: Toggle UI",
      },
    },

    dependencies = {
      {
        "rcarriga/nvim-dap-ui",
        dependencies = {
          "nvim-neotest/nvim-nio",
        },
        opts = {
          controls = {
            enabled = true,
            element = "repl",
          },

          layouts = {
            {
              elements = {
                { id = "scopes", size = 0.25 },
                { id = "breakpoints", size = 0.17 },
                { id = "stacks", size = 0.25 },
                { id = "watches", size = 0.33 },
              },
              size = 45,
              position = "left",
            },
            {
              elements = {
                { id = "repl", size = 0.5 },
                { id = "console", size = 0.5 },
              },
              size = 12,
              position = "bottom",
            },
          },

          floating = {
            border = "rounded",
          },

          render = {
            indent = 1,
            max_value_lines = 100,
          },
        },
      },

      "nvim-neotest/nvim-nio",
    },

    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      -- ── UI lifecycle ──────────────────────────────────────────────────────

      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end

      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end

      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end

      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end

      -- ── Signs ─────────────────────────────────────────────────────────────

      vim.fn.sign_define("DapBreakpoint", {
        text = "●",
        texthl = "DiagnosticSignError",
        linehl = "",
        numhl = "",
      })

      vim.fn.sign_define("DapBreakpointCondition", {
        text = "◆",
        texthl = "DiagnosticSignWarn",
        linehl = "",
        numhl = "",
      })

      vim.fn.sign_define("DapBreakpointRejected", {
        text = "○",
        texthl = "DiagnosticSignHint",
        linehl = "",
        numhl = "",
      })

      vim.fn.sign_define("DapLogPoint", {
        text = "◆",
        texthl = "DiagnosticSignInfo",
        linehl = "",
        numhl = "",
      })

      vim.fn.sign_define("DapStopped", {
        text = "▶",
        texthl = "DiagnosticSignWarn",
        linehl = "CursorLine",
        numhl = "",
      })

      -- ── Python / debugpy ──────────────────────────────────────────────────

      dap.adapters.python = function(callback, config)
        if config.request == "attach" then
          local connect = config.connect or config

          callback({
            type = "server",
            host = connect.host or "127.0.0.1",
            port = assert(connect.port, "Python attach requires a port"),
            options = {
              source_filetype = "python",
            },
          })

          return
        end

        local python = vim.fn.exepath("python3")

        if python == "" then
          python = vim.fn.exepath("python")
        end

        if python == "" then
          vim.notify(
            "Python executable not found",
            vim.log.levels.ERROR,
            { title = "nvim-dap" }
          )
          return
        end

        callback({
          type = "executable",
          command = python,
          args = {
            "-m",
            "debugpy.adapter",
          },
          options = {
            source_filetype = "python",
          },
        })
      end

      dap.configurations.python = {
        {
          type = "python",
          request = "launch",
          name = "Python: Launch file",
          program = "${file}",
          console = "integratedTerminal",

          pythonPath = function()
            local venv = vim.env.VIRTUAL_ENV

            if venv then
              return venv .. "/bin/python"
            end

            local conda = vim.env.CONDA_PREFIX

            if conda then
              return conda .. "/bin/python"
            end

            local py3 = vim.fn.exepath("python3")
            return py3 ~= "" and py3 or "python"
          end,
        },

        {
          type = "python",
          request = "launch",
          name = "Python: Launch module",
          module = function()
            return vim.fn.input("Module: ")
          end,
          console = "integratedTerminal",
          justMyCode = false,
        },
      }

      -- ── Go / Delve ────────────────────────────────────────────────────────

      dap.adapters.go = {
        type = "server",
        port = "${port}",
        executable = {
          command = "dlv",
          args = {
            "dap",
            "-l",
            "127.0.0.1:${port}",
          },
        },
      }

      dap.configurations.go = {
        {
          type = "go",
          name = "Go: Debug file",
          request = "launch",
          program = "${file}",
        },

        {
          type = "go",
          name = "Go: Debug package",
          request = "launch",
          program = "${workspaceFolder}",
        },

        {
          type = "go",
          name = "Go: Debug test",
          request = "launch",
          mode = "test",
          program = "${file}",
        },

        {
          type = "go",
          name = "Go: Debug test package",
          request = "launch",
          mode = "test",
          program = "${workspaceFolder}",
        },
      }

      -- ── Rust / C / C++ / codelldb ────────────────────────────────────────

      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = "codelldb",
          args = {
            "--port",
            "${port}",
          },
        },
      }

      local codelldb_config = {
        {
          type = "codelldb",
          request = "launch",
          name = "Debug executable",
          program = function()
            return vim.fn.input(
              "Executable: ",
              vim.fn.getcwd() .. "/target/debug/",
              "file"
            )
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
        },
      }

      dap.configurations.rust = codelldb_config
      dap.configurations.c = codelldb_config
      dap.configurations.cpp = codelldb_config

      -- ── JavaScript / TypeScript / js-debug-adapter ───────────────────────

      local js_debug_adapter =
        vim.fn.stdpath("data")
        .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js"

      for _, adapter in ipairs({
        "node",
        "chrome",
        "pwa-node",
        "pwa-chrome",
        "pwa-msedge",
      }) do
        dap.adapters[adapter] = {
          type = "server",
          host = "127.0.0.1",
          port = "${port}",
          executable = {
            command = "node",
            args = {
              js_debug_adapter,
              "${port}",
            },
          },
        }
      end

      local js_configurations = {
        {
          type = "pwa-node",
          request = "launch",
          name = "Node: Launch file",
          program = "${file}",
          cwd = "${workspaceFolder}",
          sourceMaps = true,
        },

        {
          type = "pwa-node",
          request = "attach",
          name = "Node: Attach",
          processId = require("dap.utils").pick_process,
          cwd = "${workspaceFolder}",
          sourceMaps = true,
        },
      }

      for _, filetype in ipairs({
        "javascript",
        "typescript",
        "javascriptreact",
        "typescriptreact",
      }) do
        dap.configurations[filetype] = js_configurations
      end
    end,
  },
}
