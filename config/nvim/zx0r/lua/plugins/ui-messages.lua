-- ============================================================================
-- plugins/ui-messages.lua — Notification & Message Pipeline Domain
--
-- Responsibility:
--   • macOS HIG Notification Center (Snacks.notifier)
--   • In-Place Progress Telemetry Pipeline (LSP, Treesitter, Mason, Lazy)
--   • Command Line & Message Interception / Filtering (Noice.nvim)
--
-- Neovim >= 0.12
-- ============================================================================

-- ── Progress Primitives ─────────────────────────────────────────────────────
local SPINNER = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

local function spinner()
  return SPINNER[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #SPINNER + 1]
end

local function notify_progress(p)
  local done, err = p.done or false, p.err or false
  local msg = (p.msg or ""):gsub("[%s·%.]+$", "")
  local title = (p.title or ""):gsub("[%s·%.]+$", "")
  local icon = err and " " or (done and "󰄬 " or (p.icon or spinner()))
  vim.notify(msg, err and vim.log.levels.ERROR or vim.log.levels.INFO, {
    id = p.id,
    title = title ~= "" and title or nil,
    timeout = (done or err) and 3000 or false,
    opts = function(notif)
      notif.icon = icon
      if done then
        notif.hl = { icon = "DiagnosticOk" }
      elseif err then
        notif.hl = { icon = "DiagnosticError" }
      end
    end,
  })
end

-- ── Setup In-Place Telemetry Adapters ───────────────────────────────────────
local function setup_progress_adapters()
  -- ── LSP Progress Telemetry HUD ──────────────────────────────────
  local tasks, order = {}, {}

  vim.api.nvim_create_autocmd("LspProgress", {
    group = vim.api.nvim_create_augroup("core_lsp_progress", { clear = true }),
    callback = function(ev)
      local cid = ev.data and ev.data.client_id
      if not cid then
        return
      end
      local client = vim.lsp.get_client_by_id(cid)
      local v = ev.data.params and ev.data.params.value
      if not v then
        return
      end

      local key = cid .. ":" .. tostring(ev.data.params.token or "")
      local done = v.kind == "end"
      local err = false
      if done and v.message and v.message ~= "" then
        local lower = v.message:lower()
        if lower:find("fail") or lower:find("error") or lower:find("abort") then
          err = true
        end
      end

      if not tasks[key] then
        order[#order + 1] = key
      end
      tasks[key] = {
        client = client and client.name or "LSP",
        title = v.title or "",
        msg = v.message or "",
        done = done,
        err = err,
      }

      -- Render unified HUD
      local lines, all_done, any_err, clients = {}, true, false, {}
      for _, k in ipairs(order) do
        local t = tasks[k]
        if t then
          if not t.done then
            all_done = false
          end
          if t.err then
            any_err = true
          end
          clients[t.client] = true

          local desc
          if t.title ~= "" and t.msg ~= "" then
            desc = t.title .. ": " .. t.msg
          elseif t.title ~= "" then
            desc = t.title
          elseif t.msg ~= "" then
            desc = t.msg
          else
            desc = "Processing"
          end
          desc = desc:gsub("[%s·%.]+$", "")

          local icon = t.done and (t.err and " " or "󰄬 ") or (spinner() .. " ")
          lines[#lines + 1] = icon .. desc
        end
      end
      if #lines == 0 then
        return
      end

      local names = vim.tbl_keys(clients)
      table.sort(names)
      local card_title = #names > 0 and table.concat(names, ", ") or "Workspace"

      vim.notify(table.concat(lines, "\n"), any_err and vim.log.levels.ERROR or vim.log.levels.INFO, {
        id = "workspace_telemetry",
        title = card_title,
        timeout = all_done and 2500 or false,
        opts = function(n)
          n.icon = any_err and " " or (all_done and "󰄬 " or spinner())
          if all_done then
            n.hl = { icon = any_err and "DiagnosticError" or "DiagnosticOk" }
          end
        end,
      })
      if all_done then
        vim.defer_fn(function()
          local still_done = true
          for _, t in pairs(tasks) do
            if not t.done then
              still_done = false
              break
            end
          end
          if still_done then
            tasks, order = {}, {}
          end
        end, 2600)
      end
    end,
  })

  -- ── Tree-sitter In-Place Progress Adapter ──────────────────────
  local ts_attached = false
  local function setup_treesitter(loaded_log)
    if ts_attached then
      return
    end
    local ts_log = loaded_log or package.loaded["nvim-treesitter.log"]
    if not ts_log then
      local ok, res = pcall(require, "nvim-treesitter.log")
      if ok then
        ts_log = res
      end
    end
    if not ts_log or not ts_log.Logger then
      return
    end
    ts_attached = true

    local ts_installed = 0
    local ts_total = 0
    local ts_active = {}
    local ts_failed = {}

    local function get_total()
      if ts_total > 0 then
        return ts_total
      end
      local ok_cfg, cfg = pcall(require, "nvim-treesitter.configs")
      if ok_cfg and cfg.get_ensure_installed then
        local list = cfg.get_ensure_installed()
        if type(list) == "table" and #list > 0 then
          ts_total = #list
          return ts_total
        end
      end
      return 0
    end

    ts_log.Logger.info = function(self, m, ...)
      local msg = m:format(...)
      local lang = (self.ctx and self.ctx:match("^install/(.+)$"))
        or msg:match("tree%-sitter%-([%w_]+)")
        or (self.ctx and self.ctx ~= "" and self.ctx)

      if msg:find("already installed") then
        notify_progress({
          id = "treesitter_progress",
          title = "Treesitter",
          msg = lang and string.format("%s is already installed", lang) or "All parsers are up to date",
          done = true,
        })
        return
      end

      if msg:find("Language installed") or (lang and msg:find("Installed")) then
        if lang then
          ts_active[lang] = nil
        end
        ts_installed = ts_installed + 1
        local total = math.max(get_total(), ts_installed + vim.tbl_count(ts_active))
        if vim.tbl_count(ts_active) == 0 then
          notify_progress({
            id = "treesitter_progress",
            title = "Treesitter",
            msg = string.format("Installed %d parsers successfully", ts_installed),
            done = true,
          })
          ts_installed = 0
          ts_active = {}
          ts_failed = {}
        else
          notify_progress({
            id = "treesitter_progress",
            title = "Treesitter",
            msg = string.format("Installed %s (%d/%d)", lang or "parser", ts_installed, total),
            done = false,
          })
        end
        return
      end

      if lang then
        ts_active[lang] = true
        local action = msg:find("Downloading") and "Downloading"
          or (msg:find("Compiling") and "Compiling" or (msg:find("Installing") and "Installing" or "Processing"))
        local total = math.max(get_total(), ts_installed + vim.tbl_count(ts_active))
        notify_progress({
          id = "treesitter_progress",
          title = "Treesitter",
          msg = string.format("%s %s (%d/%d)", action, lang, ts_installed, total),
          done = false,
        })
      end
    end

    ts_log.Logger.warn = function(self, m, ...)
      local msg = m:format(...)
      notify_progress({
        id = "treesitter_progress",
        title = "Treesitter",
        msg = msg:gsub("[%s·%.]+$", ""),
      })
    end

    ts_log.Logger.error = function(self, m, ...)
      local msg = m:format(...)
      local clean_msg = msg:gsub("[%s·%.]+$", "")
      local lang = (self.ctx and self.ctx:match("^install/(.+)$"))
        or msg:match("tree%-sitter%-([%w_]+)")
        or "parser"
      ts_active[lang] = nil
      table.insert(ts_failed, lang)
      notify_progress({
        id = "treesitter_progress",
        title = "Treesitter",
        msg = string.format("Failed %s: %s", lang, clean_msg),
        err = true,
      })
      return msg
    end
  end

  -- Guaranteed interception via package.preload
  package.preload["nvim-treesitter.log"] = function()
    package.preload["nvim-treesitter.log"] = nil
    local searchers = package.loaders or package.searchers
    local fn
    for i = 2, #searchers do
      local res = searchers[i]("nvim-treesitter.log")
      if type(res) == "function" then
        fn = res
        break
      end
    end
    if fn then
      local mod = fn("nvim-treesitter.log")
      setup_treesitter(mod)
      return mod
    end
  end

  if package.loaded["nvim-treesitter.log"] or package.loaded["nvim-treesitter"] then
    setup_treesitter()
  end
  vim.api.nvim_create_autocmd("User", {
    pattern = { "LazyLoad", "TSUpdate" },
    callback = function(event)
      if not event.data or event.data == "nvim-treesitter" then
        setup_treesitter()
      end
    end,
  })
  vim.api.nvim_create_autocmd("CmdlineEnter", {
    pattern = "*",
    callback = function()
      local cmd = vim.fn.getcmdline()
      if cmd:match("^%s*TS") then
        setup_treesitter()
      end
    end,
  })

  -- ── Mason Toolchain In-Place Progress Adapter ──────────────────
  local mason_attached = false
  local function setup_mason(loaded_mr)
    if mason_attached then
      return
    end
    local mr = loaded_mr or package.loaded["mason-registry"]
    if not mr then
      local ok, res = pcall(require, "mason-registry")
      if ok then
        mr = res
      end
    end
    if not mr then
      return
    end
    mason_attached = true

    local installing, failed, completed, total = {}, {}, 0, 0

    local function update(pkg_name, event_type)
      if event_type == "start" then
        installing[pkg_name] = true
        total = math.max(total, completed + vim.tbl_count(installing))
      elseif event_type == "success" then
        installing[pkg_name] = nil
        completed = completed + 1
      elseif event_type == "failed" then
        installing[pkg_name] = nil
        table.insert(failed, pkg_name)
      end

      local count = vim.tbl_count(installing)
      if count > 0 then
        local active_names = vim.tbl_keys(installing)
        table.sort(active_names)
        notify_progress({
          id = "mason_progress",
          title = "Mason",
          msg = string.format("Installing %s (%d/%d)", active_names[1], completed, total),
          done = false,
        })
      else
        if #failed > 0 then
          notify_progress({
            id = "mason_progress",
            title = "Mason",
            msg = string.format("Failed %d/%d: %s", #failed, total, table.concat(failed, ", ")),
            err = true,
          })
        elseif completed > 0 then
          notify_progress({
            id = "mason_progress",
            title = "Mason",
            msg = string.format("Installed %d tools successfully", completed),
            done = true,
          })
        end
        installing = {}
        failed = {}
        completed = 0
        total = 0
      end
    end

    mr:on("package:install:handle", function(h)
      update(h.package.name, "start")
    end)
    mr:on("package:install:success", function(pkg)
      update(pkg.name, "success")
    end)
    mr:on("package:install:failed", function(pkg)
      update(pkg.name, "failed")
    end)
  end

  -- Guaranteed interception via package.preload
  package.preload["mason-registry"] = function()
    package.preload["mason-registry"] = nil
    local searchers = package.loaders or package.searchers
    local fn
    for i = 2, #searchers do
      local res = searchers[i]("mason-registry")
      if type(res) == "function" then
        fn = res
        break
      end
    end
    if fn then
      local mod = fn("mason-registry")
      setup_mason(mod)
      return mod
    end
  end

  if package.loaded["mason-registry"] or package.loaded["mason"] then
    setup_mason()
  end
  vim.api.nvim_create_autocmd("User", {
    pattern = "LazyLoad",
    callback = function(e)
      if e.data == "mason.nvim" then
        setup_mason()
      end
    end,
  })
  vim.api.nvim_create_autocmd("CmdlineEnter", {
    pattern = "*",
    callback = function()
      local cmd = vim.fn.getcmdline()
      if cmd:match("^%s*Mason") then
        setup_mason()
      end
    end,
  })

  -- ── Lazy Plugin Manager Notifications ─────────────────────────
  local lazy_state = { active = {}, count = 0 }

  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("core_lazy_progress", { clear = true }),
    pattern = { "LazyInstallPre", "LazyUpdatePre", "LazySyncPre", "LazyCleanPre", "LazyRestorePre" },
    callback = function(ev)
      local op = ev.match:gsub("Pre$", ""):gsub("^Lazy", "")
      lazy_state = { active = {}, count = 0 }
      notify_progress({
        id = "lazy_progress",
        title = "Lazy",
        msg = string.format("Starting %s", op:lower()),
        done = false,
      })
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("core_lazy_plugins", { clear = true }),
    pattern = { "LazyPluginInstall", "LazyPluginUpdate", "LazyPluginBuild", "LazyPluginClean" },
    callback = function(ev)
      local name = ev.data and ev.data.plugin or "plugin"
      local action = ev.match:gsub("^LazyPlugin", "")
      lazy_state.count = lazy_state.count + 1
      lazy_state.active[name] = action
      notify_progress({
        id = "lazy_progress",
        title = "Lazy",
        msg = string.format("%s %s", action, name),
        done = false,
      })
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("core_lazy_done", { clear = true }),
    pattern = { "LazyInstall", "LazyUpdate", "LazySync", "LazyClean", "LazyCheck" },
    callback = function()
      local ok, cfg = pcall(require, "lazy.core.config")
      local failed = {}
      if ok and cfg.plugins then
        for pname, p in pairs(cfg.plugins) do
          if p._ and p._.tasks then
            for _, t in ipairs(p._.tasks) do
              if t.has_errors and t:has_errors() then
                table.insert(failed, pname)
                break
              end
            end
          end
        end
      end

      if #failed > 0 then
        table.sort(failed)
        notify_progress({
          id = "lazy_progress",
          title = "Lazy",
          msg = string.format("Failed %d plugins: %s", #failed, table.concat(failed, ", ")),
          err = true,
        })
      elseif lazy_state.count > 0 then
        notify_progress({
          id = "lazy_progress",
          title = "Lazy",
          msg = string.format("Installed %d plugins successfully", lazy_state.count),
          done = true,
        })
      else
        notify_progress({
          id = "lazy_progress",
          title = "Lazy",
          msg = "Plugins up to date",
          done = true,
        })
      end
      lazy_state = { active = {}, count = 0 }
    end,
  })
end

return {
  -- ========================================================================
  -- snacks.nvim — Notifier & Telemetry Pipeline
  -- ========================================================================
  {
    "folke/snacks.nvim",
    opts = {
      notifier = {
        enabled = true,
        timeout = 2500,
        width = { min = 40, max = 0.4 },
        height = { min = 1, max = 0.5 },
        margin = { top = 1, right = 2, bottom = 0 },
        padding = true,
        gap = 1,
        sort = { "level", "added" },
        level = vim.log.levels.INFO,
        icons = {
          error = " ",
          warn = " ",
          info = " ",
          debug = " ",
          trace = " ",
        },
        style = function(buf, notif, ctx)
          ctx.opts.border = "rounded"
          local parts = { { " " } }
          if notif.icon and notif.icon ~= "" then
            parts[#parts + 1] = { notif.icon .. " ", ctx.hl.icon }
          end
          if notif.title and notif.title ~= "" then
            local clean_title = notif.title:gsub("[%s·%.]+$", "")
            if clean_title ~= "" then
              parts[#parts + 1] = { clean_title .. " ", ctx.hl.title }
            end
          end
          if #parts > 1 then
            ctx.opts.title = parts
            ctx.opts.title_pos = "center"
          end
          local raw_lines = vim.split(notif.msg or "", "\n")
          local lines = {}
          for _, l in ipairs(raw_lines) do
            local clean_l = l:gsub("[%s·%.]+$", "")
            lines[#lines + 1] = clean_l
          end
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        end,
        top_down = true,
        date_format = "%R",
        more_format = " ↓ %d lines ",
        refresh = 50,
        keep = function()
          return vim.fn.getcmdpos() > 0
        end,
        filter = function(notif)
          if type(notif.msg) ~= "string" then
            return true
          end
          return not notif.msg:find("No information available", 1, true)
            and not notif.msg:find("offset_encoding", 1, true)
        end,
      },
    },

    keys = {
      {
        "<leader>un",
        function()
          Snacks.notifier.hide()
        end,
        desc = "Dismiss Notifications",
      },
      {
        "<leader>nh",
        function()
          if Snacks.picker then
            Snacks.picker.notifications()
          else
            Snacks.notifier.show_history()
          end
        end,
        desc = "Notification History",
      },
    },
  },

  -- ========================================================================
  -- noice.nvim — Cmdline & Message Routing
  -- ========================================================================
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      notify = { enabled = false },
      messages = { enabled = true, view = "mini", view_error = "notify", view_warn = "notify" },
      cmdline = {
        enabled = true,
        view = "cmdline_popup",
        format = {
          cmdline = { pattern = "^:", icon = "", lang = "vim" },
          search_down = { kind = "search", pattern = "^/", icon = " ", lang = "regex" },
          search_up = { kind = "search", pattern = "^%?", icon = " ", lang = "regex" },
          filter = { pattern = "^:%s*!", icon = "$", lang = "bash" },
          lua = { pattern = { "^:%s*lua%s+", "^:%s*lua%s*=%s*", "^:%s*=%s*" }, icon = "", lang = "lua" },
          help = { pattern = "^:%s*he?l?p?%s+", icon = "󰋖" },
          input = { view = "cmdline_input", icon = "󰥻 " },
        },
      },
      popupmenu = { enabled = true, backend = "nui" },
      routes = {
        {
          filter = {
            event = "notify",
            any = {
              { find = "offset_encoding" },
              { find = "unloaded buffer" },
              { find = "No information available" },
            },
          },
          opts = { skip = true },
        },
        {
          filter = {
            event = "msg_show",
            any = {
              { find = "%d+L, %d+B" },
              { find = "; after #%d+" },
              { find = "; before #%d+" },
              { find = "%d fewer lines" },
              { find = "%d more lines" },
              { find = "%d lines yanked" },
              { find = "%d lines changed" },
              { find = "%d changes;" },
            },
          },
          opts = { skip = true },
        },
      },
      lsp = {
        progress = { enabled = false },
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = false,
        },
      },
      presets = { command_palette = true, lsp_doc_border = true },
    },
    config = function(_, opts)
      require("noice").setup(opts)
      setup_progress_adapters()
    end,
  },
}
