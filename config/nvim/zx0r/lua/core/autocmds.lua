-- ============================================================================
-- core/autocmds.lua — Augroup-isolated autocmds
-- SLA: No vim.fn.system() / io.popen() — all async via vim.system() or uv
-- ============================================================================

local function augroup(name)
  return vim.api.nvim_create_augroup("core_" .. name, { clear = true })
end
local au = vim.api.nvim_create_autocmd

-- ── Custom Filetype Extensions (Zero-Overhead: Deferred to first real buffer) ──
au({ "BufReadPre", "BufNewFile" }, {
  group = augroup("custom_filetypes"),
  once = true,
  callback = function()
    vim.filetype.add({
      extension = {
        dvc = "yaml",
        mmd = "mermaid",
        mermaid = "mermaid",
      },
      pattern = {
        [".*/templates/.*%.ya?ml"] = "helm",
        [".*/templates/.*%.tpl"] = "helm",
        ["values%.ya?ml"] = "helm",
        ["Chart%.ya?ml"] = "helm",
        [".*/playbooks/.*%.ya?ml"] = "yaml.ansible",
        [".*/roles/.*/tasks/.*%.ya?ml"] = "yaml.ansible",
        [".*/roles/.*/handlers/.*%.ya?ml"] = "yaml.ansible",
        [".*/tasks/.*%.ya?ml"] = "yaml.ansible",
        [".*/vars/.*%.ya?ml"] = "yaml.ansible",
        [".*/defaults/.*%.ya?ml"] = "yaml.ansible",
        [".*/handlers/.*%.ya?ml"] = "yaml.ansible",
      },
    })
  end,
})

-- ── Highlight on yank ────────────────────────────────────────────────────────
au("TextYankPost", {
  group = augroup("yank_highlight"),
  callback = function()
    vim.hl.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

-- ── Auto-resize splits when terminal is resized ──────────────────────────────
au("VimResized", {
  group = augroup("resize_splits"),
  callback = function()
    -- Only equalize active tab to avoid cross-tab redraw overhead
    vim.cmd("wincmd =")
  end,
})

-- ── Restore cursor position ──────────────────────────────────────────────────
au("BufReadPost", {
  group = augroup("restore_cursor"),
  callback = function(event)
    local buf = event.buf
    local ft = vim.bo[buf].filetype
    local fname = vim.api.nvim_buf_get_name(buf)

    -- Markdown / technical prose: strictly pin viewport and cursor to line 1
    if
      ft == "markdown"
      or ft == "markdown.mdx"
      or ft == "quarto"
      or fname:match("%.md$")
      or fname:match("%.markdown$")
      or fname:match("%.qmd$")
    then
      pcall(vim.fn.winrestview, { topline = 1, lnum = 1, col = 0 })
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) then
          pcall(vim.fn.winrestview, { topline = 1, lnum = 1, col = 0 })
        end
      end)
      return
    end

    -- Skip if: special buffer, git commit, or already moved cursor
    if ft == "gitcommit" or ft == "gitrebase" then
      return
    end
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local line_count = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- ── Lazy-load clipboard & Treesitter foldexpr ──────────────────────────────
au("UIEnter", {
  group = augroup("deferred_ui"),
  once = true,
  callback = function()
    vim.o.clipboard = "unnamedplus"
    vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
  end,
})

-- ── Close certain buffers with q ────────────────────────────────────────────
au("FileType", {
  group = augroup("close_with_q"),
  pattern = {
    "help",
    "lspinfo",
    "notify",
    "qf",
    "startuptime",
    "checkhealth",
    "neotest-output",
    "neotest-output-panel",
    "neotest-summary",
    "lazy",
    "mason",
    "dap-float",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- ── Auto-create missing directories on save ──────────────────────────────────
au("BufWritePre", {
  group = augroup("auto_mkdir"),
  callback = function(event)
    if event.match:match("^%w%w+://") then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- ── Terminal settings ────────────────────────────────────────────────────────
au("TermOpen", {
  group = augroup("terminal"),
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
    vim.opt_local.scrolloff = 0
    vim.cmd("startinsert")
  end,
})

-- ── Large file guard trigger (Deterministic Zero-Overhead Governor) ─────────
au("BufReadPre", {
  group = augroup("large_file"),
  callback = function(event)
    local ok, guard = pcall(require, "core.guard")
    if ok then
      guard.check(event.buf)
    end
  end,
})

-- ── Disable formatoptions from inserting comment leaders ─────────────────────
au("FileType", {
  group = augroup("no_comment_continuation"),
  callback = function()
    vim.opt_local.formatoptions:remove({ "c", "r", "o" })
  end,
})

-- ── Filetype-specific spell checking ─────────────────────────────────────────
au("FileType", {
  group = augroup("spell_for_text"),
  pattern = { "markdown", "tex", "text", "gitcommit" },
  callback = function()
    vim.opt_local.spell = true
    vim.opt_local.wrap = true
    vim.opt_local.concealcursor = "nvc" -- M-01: buffer-local for prose only
  end,
})

-- ── Auto-save on focus lost (optional, only for named files) ─────────────────
au("FocusLost", {
  group = augroup("autosave"),
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].modified and vim.bo[buf].modifiable and vim.api.nvim_buf_get_name(buf) ~= "" then
      vim.cmd("silent! update")
    end
  end,
})

-- ── External File Change Synchronization (Agent / VCS / External edits) ─────
au({ "FocusGained", "TermClose", "TermLeave" }, {
  group = augroup("auto_checktime"),
  callback = function()
    if vim.fn.getcmdwintype() == "" and vim.bo.buftype == "" then
      vim.cmd("checktime")
    end
  end,
})

au("FileChangedShell", {
  group = augroup("file_changed_policy"),
  callback = function(event)
    local buf = event.buf
    if not vim.bo[buf].modified then
      -- Clean buffer: reload automatically without throwing red W11 modal
      vim.v.fcs_choice = "reload"
    else
      -- Buffer has unsaved local edits: prompt peacefully without crash error
      vim.v.fcs_choice = "ask"
      local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
      vim.notify(
        string.format("File '%s' changed on disk, but has unsaved local changes.", name),
        vim.log.levels.WARN,
        { title = "Disk Conflict", icon = " " }
      )
    end
  end,
})

au("FileChangedShellPost", {
  group = augroup("file_changed_notify"),
  callback = function(event)
    local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(event.buf), ":t")
    vim.notify(
      string.format("File '%s' modified on disk. Buffer reloaded.", name),
      vim.log.levels.INFO,
      { title = "File Changed", icon = "󰑐 " }
    )
  end,
})

-- ── Instant Exit Optimization (Zero Lag on :q / :qa) ─────────────────────────
au("VimLeavePre", {
  group = augroup("fast_exit"),
  callback = function()
    -- Bounded Graceful LSP Shutdown (SLA: <= 80ms)
    -- Sends shutdown RPC to allow language servers (rust-analyzer, gopls, clangd)
    -- to cleanly flush AST indexes and caches, bounded by a strict fallback timer.
    if package.loaded["vim.lsp"] then
      local clients = vim.lsp.get_clients()
      if #clients == 0 then return end

      for _, client in ipairs(clients) do
        pcall(client.stop, client, 80)
      end

      -- Wait up to 80ms for channels to close gracefully
      vim.wait(80, function()
        return vim.iter(clients):all(function(c)
          return not c.rpc or c.rpc.is_closing()
        end)
      end, 5)

      -- Enforce immediate termination for any stubborn servers to prevent :q lag
      for _, client in ipairs(clients) do
        if client.rpc and not client.rpc.is_closing() then
          pcall(client.stop, client, true)
        end
      end
    end
  end,
})

-- ── Restore Terminal Cursor on Exit ──────────────────────────────────────────
au("VimLeave", {
  group = augroup("restore_terminal_cursor"),
  callback = function()
    if #vim.api.nvim_list_uis() > 0 then
      -- 3 = blinking underline (matching Ghostty profile: cursor-style = underline)
      -- \27]112\7: Reset dynamic cursor foreground color to terminal default
      io.stdout:write("\27[3 q\27]112\7")
    end
  end,
})

-- ── Force visible Visual selection across all themes ─────────────────────────
au("ColorScheme", {
  group = augroup("force_visual_hl"),
  callback = function()
    -- Ensure Visual selection is always clearly visible (grey/blueish background)
    vim.api.nvim_set_hl(0, "Visual", { bg = "#4b5263", fg = "NONE", default = false })
  end,
})

-- ── Close transient floating / Snacks windows when :q would otherwise be blocked ──
au("QuitPre", {
  group = augroup("message_quit"),
  callback = function()
    local closable_wins = {}
    local normal_win_count = 0
    local wins = vim.api.nvim_list_wins()

    for _, win in ipairs(wins) do
      if vim.api.nvim_win_is_valid(win) then
        local buf = vim.api.nvim_win_get_buf(win)
        local ft = vim.bo[buf].filetype
        local config = vim.api.nvim_win_get_config(win)

        if ft:match("^snacks_") or config.relative ~= "" then
          closable_wins[#closable_wins + 1] = win
        else
          normal_win_count = normal_win_count + 1
        end
      end
    end

    -- If this :q closes the last remaining normal window, dismiss all transient floats
    -- so Neovim exits cleanly without being trapped in background floating buffers.
    if normal_win_count <= 1 then
      for _, win in ipairs(closable_wins) do
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
  end,
})

-- ── Read-Only Buffer Diagnostics & Write Guard ───────────────────────────────
au("BufReadPost", {
  group = augroup("readonly_diagnostics"),
  callback = function(event)
    local buf = event.buf
    local fname = vim.api.nvim_buf_get_name(buf)
    if fname == "" or vim.bo[buf].buftype ~= "" then
      return
    end

    -- Non-blocking: check vim.bo.readonly (set by Neovim from file permissions)
    if vim.bo[buf].readonly or not vim.bo[buf].modifiable then
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) then
          vim.notify(
            "Buffer is write-protected (read-only permissions or root ownership).",
            vim.log.levels.WARN,
            { title = "Read-Only Buffer" }
          )
        end
      end)
    end
  end,
})

au("BufWritePre", {
  group = augroup("readonly_write_guard"),
  callback = function(event)
    local buf = event.buf
    local fname = vim.api.nvim_buf_get_name(buf)
    if fname == "" or vim.bo[buf].buftype ~= "" then
      return
    end

    -- Non-blocking: rely on Neovim's in-memory readonly flag
    if vim.bo[buf].readonly or not vim.bo[buf].modifiable then
      vim.notify(
        "Write blocked: Target is read-only. Elevated privileges (sudo) or 'chmod +w' required.",
        vim.log.levels.ERROR,
        { title = "Permission Denied" }
      )
    end
  end,
})

-- ━━━ ASYNC TMUX RELOADER (LibUV Engine) ━━━━━━━━━━━━━━━
local tmux_timer
local TMUX_CONF = vim.uv.os_homedir() .. "/.config/tmux/tmux.conf"

vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("TmuxPrincipalAutoReload", { clear = true }),
  pattern = { "*/tmux/*.conf", "*/tmux/**/*.conf", "*.tmux" },
  desc = "Zero-overhead non-blocking Tmux auto-reloader",
  callback = function()
    -- Guard 1: Проверка наличия активного сокета Tmux (Zero-Cost env lookup)
    if not vim.env.TMUX then
      return
    end

    if not tmux_timer then
      tmux_timer = vim.uv.new_timer()
    end

    -- Guard 2: Trailing-Edge Debounce (гасит дребезг от автоформаттеров/LSP)
    tmux_timer:stop()
    tmux_timer:start(50, 0, function()
      -- 100% Асинхронный вызов без форка оболочки shell (напрямую в LibUV C-loop)
      vim.system({ "tmux", "source-file", TMUX_CONF }, { text = true }, function(obj)
        vim.schedule(function()
          if obj.code == 0 then
            vim.notify("󰑕 Tmux: Configuration reloaded", vim.log.levels.INFO, {
              title = "The Environment X",
              timeout = 1500,
            })
          else
            vim.notify(
              "󰅚 Tmux Syntax Error:\n" .. (obj.stderr or obj.stdout or "Unknown error"),
              vim.log.levels.ERROR,
              {
                title = "Tmux Control Plane",
              }
            )
          end
        end)
      end)
    end)
  end,
})
