-- ============================================================================
-- core/options.lua — Deterministic vim.o settings (Zero-Overhead)
-- Rule: NO side effects. NO autocmds. NO require() calls. Pure state mutation.
-- SLA: Pure C-level vim.o direct scalar writes (zero vim.opt metatable wrapping).
-- ============================================================================

local o = vim.o

-- ── Security ─────────────────────────────────────────────────────────

o.modeline     = true
o.modelineexpr = false
o.exrc         = false

-- ── Editor behavior ─────────────────────────────────────────────────────────

o.mouse        = "a"          -- Mouse support in all modes
o.updatetime   = 200          -- Faster CursorHold events → snappier diagnostics
o.timeoutlen   = 300          -- which-key trigger delay
o.ttimeoutlen  = 10           -- Key sequence timeout (near-instant)
o.shell        = "/bin/bash"  -- Faster startup than zsh/fish
o.encoding     = "utf-8"
o.fileencoding = "utf-8"
o.confirm      = true         -- Prompt instead of error on unsaved exit
o.autoread     = true         -- Automatically reload files modified outside Neovim
o.undofile     = true         -- Persistent undo across sessions
o.swapfile     = false        -- No swap files (use undo instead)
o.backup       = false
o.shada        = "!,'50,<20,s10,h" -- Cap register/mark serialization to guarantee <1ms exit

vim.g.tex_flavor = "latex"    -- Default dialect for .tex files (LaTeX instead of plainTeX)


-- ── Appearance ──────────────────────────────────────────────────────────────

o.termguicolors  = true        -- True 24-bit color
o.number         = true
o.relativenumber = true
o.signcolumn     = "yes:1"     -- Fixed sign column (no layout shift)
o.cursorline     = true
o.cursorcolumn   = false       -- Disable — causes redraws on every move
o.conceallevel   = 2           -- Markdown/LaTeX concealment
o.laststatus     = 3           -- Global statusline (Neovim 0.7+)
o.cmdheight      = 0           -- Hide cmdline when not in use (Neovim 0.8+)
o.showmode       = false       -- Mode shown in statusline, not cmdline
o.ruler          = false
o.showcmd        = false
o.showmatch      = false
o.pumheight      = 12          -- Completion popup max lines
o.pumblend       = 0           -- No transparency on popup (performance)
o.winblend       = 0
o.winborder      = "rounded"   -- macOS HIG rounded border radius for all floating windows
o.guicursor      = "n-v-c-sm:block-Cursor,i-ci-ve:ver25-Cursor,r-cr-o:hor20-Cursor,t:block-TermCursor,a:blinkon0"

-- ── Indentation ─────────────────────────────────────────────────────────────

o.expandtab   = true
o.tabstop     = 2
o.shiftwidth  = 2
o.shiftround  = true           -- Round indent to shiftwidth multiple
o.smartindent = true

-- ── Search ──────────────────────────────────────────────────────────────────

o.ignorecase = true           -- Case-insensitive search...
o.smartcase  = true           -- ...unless uppercase is typed
o.incsearch  = true
o.hlsearch   = false          -- Don't persist highlights (use / for temporary)
o.grepprg    = "rg --vimgrep --smart-case --follow"
o.grepformat = "%f:%l:%c:%m"

-- ── Split behavior ──────────────────────────────────────────────────────────

o.splitright = true
o.splitbelow = true

-- ── Scroll / wrap ───────────────────────────────────────────────────────────

o.wrap          = false
o.scrolloff     = 8
o.sidescrolloff = 8

-- ── Completion (native) ─────────────────────────────────────────────────────

o.completeopt = "menu,menuone,noselect"

-- ── Folding (Treesitter-native) ──────────────────────────────────────────────

o.foldmethod     = "expr"
o.foldlevel      = 99         -- All folds open by default
o.foldlevelstart = 99
o.foldenable     = false      -- Disable on open; user enables per-buffer

-- ── Clipboard ───────────────────────────────────────────────────────────────
-- Lazy-load clipboard provider — deferred to UIEnter in autocmds.lua

o.clipboard = ""

-- ── Diff ────────────────────────────────────────────────────────────────────

o.diffopt = "internal,filler,closeoff,algorithm:patience,indent-heuristic,linematch:60"

-- ── Spelling ────────────────────────────────────────────────────────────────

o.spell     = false           -- Enable per-filetype via ftplugin/
o.spelllang = "en_us"

-- ── Virtual text / diagnostics ──────────────────────────────────────────────

o.virtualedit = "block"       -- True block selection

-- ── Window borders & Glyphs ─────────────────────────────────────────────────

o.fillchars = "foldopen: ,foldclose: ,fold: ,foldsep: ,diff:╱,eob: ,vert:┃,horiz:━,horizup:┻,horizdown:┳,vertleft:┫,vertright:┣,verthoriz:╋"

-- ── List chars ──────────────────────────────────────────────────────────────

o.listchars = "tab:→ ,trail:·,nbsp:␣,extends:›,precedes:‹"
o.list      = false           -- Toggle with <leader>ul

-- ── Formatoptions ───────────────────────────────────────────────────────────

o.formatoptions = "jqlnt"     -- j: remove comment leaders on join

-- ── Neovide GUI Settings (Zero-Overhead: runs only in GUI) ───────────────────

if vim.g.neovide then
  o.guifont = "JetBrainsMono Nerd Font:h13"
  vim.g.neovide_padding_top = 5
  vim.g.neovide_padding_right = 5
  vim.g.neovide_padding_left = 5
  vim.g.neovide_window_blurred = true
  vim.g.neovide_floating_blur_amount_x = 5.0
  vim.g.neovide_floating_blur_amount_y = 5.0
  vim.g.neovide_floating_shadow = true
  vim.g.neovide_floating_z_height = 10
  vim.g.neovide_cursor_antialiasing = false
  vim.g.neovide_cursor_vfx_mode = "pixiedust"
  vim.g.neovide_hide_mouse_when_typing = true
  vim.g.neovide_refresh_rate = 75
end
