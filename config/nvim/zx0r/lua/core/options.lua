-- ============================================================================
-- core/options.lua — Deterministic vim.o / vim.opt settings
-- Rule: NO side effects. NO autocmds. NO require() calls. Pure state mutation.
-- ============================================================================

local opt = vim.opt
local o   = vim.o


-- ── Security ─────────────────────────────────────────────────────────

vim.opt.modeline = true
vim.opt.modelineexpr = false
vim.opt.exrc = false

-- ── Editor behavior ─────────────────────────────────────────────────────────

o.mouse        = "a"          -- Mouse support in all modes
o.updatetime   = 200          -- Faster CursorHold events → snappier diagnostics
o.timeoutlen   = 300          -- which-key trigger delay
o.ttimeoutlen  = 10           -- Key sequence timeout (near-instant)
o.shell        = "/bin/bash"  -- Faster startup than zsh/fish
o.encoding     = "utf-8"
o.fileencoding = "utf-8"
o.confirm      = true         -- Prompt instead of error on unsaved exit
o.undofile     = true         -- Persistent undo across sessions
o.swapfile     = false        -- No swap files (use undo instead)
o.backup       = false

vim.g.tex_flavor = "latex"    -- Default dialect for .tex files (LaTeX instead of plainTeX)


-- ── Appearance ──────────────────────────────────────────────────────────────

o.termguicolors = true        -- True 24-bit color
o.number        = true
o.relativenumber = true
o.signcolumn    = "yes:1"     -- Fixed sign column (no layout shift)
o.cursorline    = true
o.cursorcolumn  = false       -- Disable — causes redraws on every move
o.conceallevel  = 2           -- Markdown/LaTeX concealment
o.laststatus    = 3           -- Global statusline (Neovim 0.7+)
o.cmdheight     = 0           -- Hide cmdline when not in use (Neovim 0.8+)
o.showmode      = false       -- Mode shown in statusline, not cmdline
o.ruler         = false
o.showcmd       = false
o.showmatch     = false
o.pumheight     = 12          -- Completion popup max lines
o.pumblend      = 0           -- No transparency on popup (performance)
o.winblend      = 0
opt.winborder   = "rounded"   -- macOS HIG rounded border radius for all floating windows

-- ── Indentation ─────────────────────────────────────────────────────────────

o.expandtab  = true
o.tabstop    = 2
o.shiftwidth = 2
o.shiftround = true           -- Round indent to shiftwidth multiple
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

o.wrap       = false
o.scrolloff  = 8
o.sidescrolloff = 8

-- ── Completion (native) ─────────────────────────────────────────────────────

opt.completeopt = { "menu", "menuone", "noselect" }

-- ── Folding (Treesitter-native) ──────────────────────────────────────────────

o.foldmethod = "expr"
o.foldlevel  = 99             -- All folds open by default

-- Fold settings. Treesitter handles the actual expression per-buffer.
o.foldlevelstart = 99
o.foldenable = false          -- Disable on open; user enables per-buffer

-- ── Clipboard ───────────────────────────────────────────────────────────────
-- Lazy-load clipboard provider — deferred to UIEnter in autocmds.lua

opt.clipboard = ""

-- ── Diff ────────────────────────────────────────────────────────────────────

opt.diffopt:append("algorithm:patience")
opt.diffopt:append("indent-heuristic")
opt.diffopt:append("linematch:60")

-- ── Spelling ────────────────────────────────────────────────────────────────

o.spell     = false           -- Enable per-filetype via ftplugin/
o.spelllang = "en_us"

-- ── Virtual text / diagnostics ──────────────────────────────────────────────

o.virtualedit = "block"       -- True block selection

-- ── Window borders ──────────────────────────────────────────────────────────

opt.fillchars = {
  foldopen  = " ",
  foldclose = " ",
  fold      = " ",
  foldsep   = " ",
  diff      = "╱",
  eob       = " ",
  vert      = "┃",
  horiz     = "━",
  horizup   = "┻",
  horizdown = "┳",
  vertleft  = "┫",
  vertright = "┣",
  verthoriz = "╋",
}

-- ── List chars ──────────────────────────────────────────────────────────────

opt.listchars = {
  tab      = "→ ",
  trail    = "·",
  nbsp     = "␣",
  extends  = "›",
  precedes = "‹",
}
o.list = false  -- Toggle with <leader>ul

-- ── Formatoptions ───────────────────────────────────────────────────────────

opt.formatoptions = "jqlnt"  -- j: remove comment leaders on join
