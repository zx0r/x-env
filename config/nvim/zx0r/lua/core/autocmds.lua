-- ============================================================================
-- core/autocmds.lua — Augroup-isolated autocmds
-- SLA: No vim.fn.system() / io.popen() — all async via vim.system() or uv
-- ============================================================================

local function augroup(name)
  return vim.api.nvim_create_augroup("core_" .. name, { clear = true })
end
local au = vim.api.nvim_create_autocmd

-- ── Custom Filetype Extensions (Zero-Overhead: Deferred to first buffer/UI) ──
au({ "BufReadPre", "BufNewFile", "UIEnter" }, {
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
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
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
    if ft == "markdown" or ft == "markdown.mdx" or ft == "quarto"
       or fname:match("%.md$") or fname:match("%.markdown$") or fname:match("%.qmd$") then
      pcall(vim.fn.winrestview, { topline = 1, lnum = 1, col = 0 })
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) then
          pcall(vim.fn.winrestview, { topline = 1, lnum = 1, col = 0 })
        end
      end)
      return
    end

    -- Skip if: special buffer, git commit, or already moved cursor
    if ft == "gitcommit" or ft == "gitrebase" then return end
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
    vim.opt.clipboard = "unnamedplus"
    vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
  end,
})

-- ── Close certain buffers with q ────────────────────────────────────────────
au("FileType", {
  group = augroup("close_with_q"),
  pattern = {
    "help", "lspinfo", "notify", "qf", "startuptime",
    "checkhealth", "neotest-output", "neotest-output-panel",
    "neotest-summary", "lazy", "mason", "dap-float",
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
    if event.match:match("^%w%w+://") then return end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- ── Terminal settings ────────────────────────────────────────────────────────
au("TermOpen", {
  group = augroup("terminal"),
  callback = function()
    vim.opt_local.number         = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn     = "no"
    vim.opt_local.scrolloff      = 0
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
au("BufEnter", {
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
    vim.opt_local.wrap  = true
  end,
})

-- ── Auto-save on focus lost (optional, only for named files) ─────────────────
au("FocusLost", {
  group = augroup("autosave"),
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].modified and vim.bo[buf].modifiable
       and vim.api.nvim_buf_get_name(buf) ~= "" then
      vim.cmd("silent! update")
    end
  end,
})

-- ── Restore Terminal Cursor on Exit ──────────────────────────────────────────
au("VimLeave", {
  group = augroup("restore_terminal_cursor"),
  callback = function()
    -- 3 = blinking underline, 4 = steady underline
    io.write("\27[3 q")
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

-- ── Close transient Snacks windows when :q would otherwise be blocked ───────
au("QuitPre", {
  group = augroup("message_quit"),
  callback = function()
    local snacks_wins, floating_wins = {}, {}
    local wins = vim.api.nvim_list_wins()

    for _, win in ipairs(wins) do
      local buf = vim.api.nvim_win_get_buf(win)
      local ft = vim.bo[buf].filetype
      local config = vim.api.nvim_win_get_config(win)

      if ft:match("^snacks_") then
        snacks_wins[#snacks_wins + 1] = win
      elseif config.relative ~= "" then
        floating_wins[#floating_wins + 1] = win
      end
    end

    if #wins - #floating_wins - #snacks_wins ~= 1 then
      return
    end

    for _, win in ipairs(snacks_wins) do
      pcall(vim.api.nvim_win_close, win, true)
    end
  end,
})
