-- ============================================================================
-- core/keymaps.lua — Principal-Level Keymap Architecture
-- Navigation: smart-splits for C-hjkl (reliable), NO global arrow remaps
--             Arrow remaps inside NeoTree only (handled in explorer.lua)
-- Developer hotkeys: full VSCode parity
-- ============================================================================

-- ── Leader ──────────────────────────────────────────────────────────────────
vim.g.mapleader      = " "
vim.g.maplocalleader = " "

local map = vim.keymap.set

-- ═══════════════════════════════════════════════════════════════════════════
-- §1  WINDOW FOCUS NAVIGATION  (Folke-style — AGENT_GUIDE.md)
--
--     ARCHITECTURE: Both arrows AND C-hjkl navigate between windows.
--     If wincmd doesn't move (edge of Neovim layout), smart-splits takes
--     over to cross into Kitty terminal panes.
--
--     Inside NeoTree: <Left> = close_node, <Right> = focus editor
--     (buffer-local overrides in explorer.lua — NOT affected by these globals)
--
--     | Key          | Editor              | NeoTree sidebar           |
--     |--------------|---------------------|---------------------------|
--     | <Left>/C-h   | Focus → sidebar     | close_node (explorer.lua) |
--     | <Right>/C-l  | (cursor right)      | Focus → editor            |
--     | <Up>/C-k     | Focus window above  | Prev Edgy panel           |
--     | <Down>/C-j   | Focus window below  | Next Edgy panel           |
-- ═══════════════════════════════════════════════════════════════════════════

local nav = {
  h = "Left",
  j = "Down",
  k = "Up",
  l = "Right",
}

--- Pure wincmd navigation — no plugin dependencies in core.
--- Plugin-based pane-crossing (tmux/wezterm) is owned by terminal.lua (smart-splits).
---@param dir string vim direction key (h/j/k/l)
local function navigate(dir)
  return function()
    vim.cmd.wincmd(dir)
  end
end

-- Arrow keys + C-hjkl → unified window/pane navigation
for key, dir in pairs(nav) do
  map("n", "<" .. dir .. ">", navigate(key), { desc = "Focus " .. dir, silent = true })
  map("n", "<C-" .. key .. ">", navigate(key), { desc = "Focus " .. dir, silent = true })
end

-- Terminal mode navigation: owned by terminal.lua (smart-splits)

-- ═══════════════════════════════════════════════════════════════════════════
-- §2  WINDOW MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════

map("n", "<leader>ws", "<C-w>s",       { desc = "Split horizontal" })
map("n", "<leader>wv", "<C-w>v",       { desc = "Split vertical" })
map("n", "<leader>wq", "<C-w>q",       { desc = "Close window" })
map("n", "<leader>w=", "<C-w>=",       { desc = "Equalize windows" })
map("n", "<leader>wo", "<C-w>o",       { desc = "Close other windows" })
map("n", "<leader>wT", "<C-w>T",       { desc = "Break to new tab" })
map("n", "<leader>wm", "<C-w>_<C-w>|", { desc = "Maximize window", silent = true })

-- ═══════════════════════════════════════════════════════════════════════════
-- §3  VSCode-GRADE EDITING BINDINGS
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Comment toggle (Space + /) — User preference ─────────────────────────
-- Neovim 0.10+ has native gc operator; eliminate normal mode gcc overlap warning
pcall(vim.keymap.del, "n", "gcc")
map("o", "c", "<cmd>normal! _<cr>", { desc = "Current line motion" })
map("n", "<leader>/", "gcc", { desc = "Toggle comment line", remap = true })
map("v", "<leader>/", "gc",  { desc = "Toggle comment block", remap = true })

-- ── Block Navigation & Indentation — Tab / Shift-Tab ─────────────────────────
map("n", "<Tab>",          "}",     { desc = "Next block",          silent = true })
map("n", "<S-Tab>",        "{",     { desc = "Previous block",      silent = true })
map("v", "<Tab>",          ">gv",   { desc = "Indent selection",    silent = true })
map("v", "<S-Tab>",        "<gv",   { desc = "Unindent selection",  silent = true })
map("i", "<S-Tab>",        "<C-d>", { desc = "Dedent (insert)",     silent = true })

-- ── Select all (Ctrl-A) ────────────────────────────────────────────────────
map("n", "<C-a>", "ggVG",      { desc = "Select all", silent = true })
map("i", "<C-a>", "<Esc>ggVG", { desc = "Select all", silent = true })
map("v", "<C-a>", "<Esc>ggVG", { desc = "Select all", silent = true })

-- ── Save (Ctrl-S) ─────────────────────────────────────────────────────────
map({ "n", "i", "v", "s" }, "<C-S>", "<cmd>w<cr><esc>", { desc = "Save file", silent = true })
map("n", "<leader>W",        "<cmd>w!<cr>",              { desc = "Force save" })

-- ── Undo / Redo (Ctrl-Z / Ctrl-Y) ─────────────────────────────────────────
map("n", "<C-z>", "u",          { desc = "Undo" })
map("i", "<C-z>", "<C-o>u",     { desc = "Undo" })
map("n", "<C-y>", "<C-r>",      { desc = "Redo" })
map("i", "<C-y>", "<C-o><C-r>", { desc = "Redo" })

-- ── Quit (Ctrl-Q) — useful for closing floats without :q ──────────────────
map("n", "<C-q>", "<cmd>close<cr>", { desc = "Close window/float", silent = true })

-- ── New line below / above — Ctrl+Enter / Ctrl+Shift+Enter ────────────────
map("i", "<C-CR>",   "<End><CR>",         { desc = "New line below (insert)", silent = true })
map("n", "<C-CR>",   "o<Esc>",            { desc = "New line below",          silent = true })
map("i", "<C-S-CR>", "<Home><CR><Up>",    { desc = "New line above (insert)", silent = true })
map("n", "<C-S-CR>", "O<Esc>",            { desc = "New line above",          silent = true })

-- ── Delete word backward / forward — Ctrl+Backspace / Ctrl+Delete ─────────
map("i", "<C-BS>",  "<C-w>",   { desc = "Delete word backward (insert)", silent = true })
map("i", "<C-Del>", "<C-o>dw", { desc = "Delete word forward  (insert)", silent = true })
map("n", "<C-BS>",  "db",      { desc = "Delete word backward",          silent = true })
map("n", "<C-Del>", "dw",      { desc = "Delete word forward",           silent = true })

-- ── Smart Home — first non-blank / column 0 toggle ────────────────────────
map("n", "<Home>", function()
  local cur = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  local first_nonblank = (line:find("%S") or 1) - 1
  if cur[2] == first_nonblank then
    vim.api.nvim_win_set_cursor(0, { cur[1], 0 })
  else
    vim.api.nvim_win_set_cursor(0, { cur[1], first_nonblank })
  end
end, { desc = "Smart Home", silent = true })
map("n", "<End>",  "$",       { desc = "End of line",          silent = true })
map("i", "<Home>", "<C-o>^",  { desc = "Smart Home (insert)",  silent = true })
map("v", "<Home>", "^",       { desc = "Smart Home (visual)",  silent = true })
map("v", "<End>",  "$",       { desc = "End of line (visual)", silent = true })

-- ── Cut / Copy / Paste — clipboard ────────────────────────────────────────
map("n", "<C-x>", "dd",      { desc = "Cut line",        silent = true })
map("n", "<C-c>", "yy",      { desc = "Copy line",       silent = true })
map("v", "<C-c>", '"+y',     { desc = "Copy to clipboard", silent = true })
map("v", "<C-x>", '"+x',     { desc = "Cut to clipboard",  silent = true })
map({ "n", "v" }, "<C-v>", '"+p',   { desc = "Paste from clipboard", silent = true })
map("i",          "<C-v>", '<C-r>+', { desc = "Paste from clipboard (insert)", silent = true })

-- Guard middle-click / wheel click from pasting into unmodifiable buffers (avoids E21: Cannot make changes, 'modifiable' is off)
map({ "n", "v" }, "<MiddleMouse>", function()
  if vim.bo.modifiable then
    vim.cmd('normal! "+p')
  end
end, { desc = "Paste on middle click if modifiable", silent = true })
map("i", "<MiddleMouse>", function()
  if vim.bo.modifiable then
    vim.cmd('normal! "+p')
  end
end, { desc = "Paste on middle click if modifiable", silent = true })

-- Explicit clipboard yanking
map("n", "<leader>y", '"+y',  { desc = "Copy to clipboard" })
map("v", "<leader>y", '"+y',  { desc = "Copy to clipboard" })
map("n", "<leader>Y", '"+Y',  { desc = "Copy line to clipboard" })

-- ── Duplicate line (Alt-Shift-J/K) — VSCode Alt+Shift+Down/Up ────────────
map("n", "<A-S-j>",  "<cmd>t.<cr>",         { desc = "Duplicate line down",      silent = true })
map("n", "<A-S-k>",  "<cmd>t.-1<cr>",       { desc = "Duplicate line up",        silent = true })
map("i", "<A-S-j>",  "<Esc><cmd>t.<cr>gi",  { desc = "Duplicate line down",      silent = true })
map("v", "<A-S-j>",  ":t'><cr>gv",          { desc = "Duplicate selection down", silent = true })
map("v", "<A-S-k>",  ":t'<-1<cr>gv",        { desc = "Duplicate selection up",   silent = true })
map("n", "<leader>dl", "yyp",               { desc = "Duplicate line",           silent = true })

-- ── Move lines (Alt-J/K) — VSCode Alt+Down/Up ─────────────────────────────
map("n", "<A-j>", "<cmd>m .+1<cr>==",        { desc = "Move line down", silent = true })
map("n", "<A-k>", "<cmd>m .-2<cr>==",        { desc = "Move line up",   silent = true })
map("i", "<A-j>", "<Esc><cmd>m .+1<cr>==gi", { desc = "Move line down", silent = true })
map("i", "<A-k>", "<Esc><cmd>m .-2<cr>==gi", { desc = "Move line up",   silent = true })
map("v", "<A-j>", ":m '>+1<cr>gv=gv",        { desc = "Move selection down", silent = true })
map("v", "<A-k>", ":m '<-2<cr>gv=gv",        { desc = "Move selection up",   silent = true })

-- ── Fold / Unfold ──────────────────────────────────────────────────────────
map("n", "<C-S-[>", "zc", { desc = "Close fold",    silent = true })
map("n", "<C-S-]>", "zo", { desc = "Open fold",     silent = true })

-- ═══════════════════════════════════════════════════════════════════════════
-- §4  ESSENTIAL DEVELOPER KEYMAPS
-- ═══════════════════════════════════════════════════════════════════════════

-- Clear search highlight on Escape
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight", silent = true })

-- Better indenting (stay in visual mode)
map("v", "<", "<gv", { desc = "Indent left",  silent = true })
map("v", ">", ">gv", { desc = "Indent right", silent = true })

-- Paste without overwriting register
map("x", "p", '"_dP', { desc = "Paste (keep register)", silent = true })

-- Join lines without cursor jump
map("n", "J", "mzJ`z", { desc = "Join lines (cursor stays)", silent = true })

-- Center screen after scroll / search
map("n", "<C-d>", "<C-d>zz", { desc = "Page down (centered)", silent = true })
map("n", "<C-u>", "<C-u>zz", { desc = "Page up (centered)",   silent = true })
map("n", "n",     "nzzzv",   { desc = "Next match (centered)", silent = true })
map("n", "N",     "Nzzzv",   { desc = "Prev match (centered)", silent = true })
map("n", "*",     "*zzzv",   { desc = "Search word fwd (centered)", silent = true })
map("n", "#",     "#zzzv",   { desc = "Search word bwd (centered)", silent = true })

-- Add blank lines without leaving normal mode
map("n", "]<space>", "<cmd>put =repeat(nr2char(10),v:count1)<cr>",  { desc = "Blank line below", silent = true })
map("n", "[<space>", "<cmd>put! =repeat(nr2char(10),v:count1)<cr>", { desc = "Blank line above", silent = true })

-- ═══════════════════════════════════════════════════════════════════════════
-- §5  BUFFER MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════

map("n", "<S-h>",      "<cmd>bprevious<cr>", { desc = "Prev buffer",          silent = true })
map("n", "<S-l>",      "<cmd>bnext<cr>",     { desc = "Next buffer",          silent = true })
map("n", "<leader>bb", "<cmd>e #<cr>",       { desc = "Switch to other buf",  silent = true })
map("n", "<leader>bd", function()
  if _G.Snacks and _G.Snacks.bufdelete then
    Snacks.bufdelete()
  else
    vim.cmd("bdelete")
  end
end, { desc = "Delete buffer", silent = true })
map("n", "<leader>bD", "<cmd>bdelete!<cr>",  { desc = "Delete buffer (force)", silent = true })
map("n", "<leader>bn", "<cmd>bnext<cr>",     { desc = "Next buffer",          silent = true })
map("n", "<leader>bp", "<cmd>bprevious<cr>", { desc = "Prev buffer",          silent = true })
map("n", "<leader>bo", "<cmd>%bd|e#|bd#<cr>", { desc = "Close other buffers", silent = true })

-- ═══════════════════════════════════════════════════════════════════════════
-- §6  QUICKFIX / LOCATION LIST
-- ═══════════════════════════════════════════════════════════════════════════

map("n", "[q", "<cmd>cprev<cr>zz", { desc = "Prev quickfix", silent = true })
map("n", "]q", "<cmd>cnext<cr>zz", { desc = "Next quickfix", silent = true })
map("n", "[l", "<cmd>lprev<cr>zz", { desc = "Prev loclist",  silent = true })
map("n", "]l", "<cmd>lnext<cr>zz", { desc = "Next loclist",  silent = true })
map("n", "<leader>xq", function()
  if vim.fn.getqflist({ winid = 0 }).winid ~= 0 then
    vim.cmd("cclose")
  else
    vim.cmd("copen")
  end
end, { desc = "Toggle quickfix" })

-- ═══════════════════════════════════════════════════════════════════════════
-- §7  DIAGNOSTIC NAVIGATION
-- ═══════════════════════════════════════════════════════════════════════════

map("n", "]d", function() vim.diagnostic.goto_next() end,  { desc = "Next diagnostic" })
map("n", "[d", function() vim.diagnostic.goto_prev() end,  { desc = "Prev diagnostic" })
map("n", "]e", function() vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR }) end, { desc = "Next error" })
map("n", "[e", function() vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR }) end, { desc = "Prev error" })
map("n", "]w", function() vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.WARN }) end,  { desc = "Next warning" })
map("n", "[w", function() vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.WARN }) end,  { desc = "Prev warning" })
map("n", "<leader>cd", function() vim.diagnostic.open_float() end, { desc = "Line diagnostics" })

-- ═══════════════════════════════════════════════════════════════════════════
-- §8  TERMINAL
-- ═══════════════════════════════════════════════════════════════════════════

map("t", "<Esc><Esc>",  "<C-\\><C-n>",              { desc = "Exit terminal mode" })
map("n", "<leader>tT",  "<cmd>terminal<cr>",          { desc = "Terminal (current)" })
map("n", "<leader>tv",  "<cmd>vsplit | terminal<cr>", { desc = "Terminal (vsplit)" })
map("n", "<leader>th",  "<cmd>split  | terminal<cr>", { desc = "Terminal (split)" })

-- ═══════════════════════════════════════════════════════════════════════════
-- §9  TABS
-- ═══════════════════════════════════════════════════════════════════════════

map("n", "<leader><tab>n", "<cmd>tabnew<cr>",      { desc = "New tab" })
map("n", "<leader><tab>d", "<cmd>tabclose<cr>",    { desc = "Close tab" })
map("n", "<leader><tab>]", "<cmd>tabnext<cr>",     { desc = "Next tab" })
map("n", "<leader><tab>[", "<cmd>tabprevious<cr>", { desc = "Prev tab" })
map("n", "<leader><tab>f", "<cmd>tabfirst<cr>",    { desc = "First tab" })
map("n", "<leader><tab>l", "<cmd>tablast<cr>",     { desc = "Last tab" })

-- ═══════════════════════════════════════════════════════════════════════════
-- §10  UI TOGGLES + MISC
-- ═══════════════════════════════════════════════════════════════════════════

if not _G.Snacks then
  map("n", "<leader>ul", "<cmd>set number! relativenumber!<cr>", { desc = "Toggle line numbers" })
  map("n", "<leader>uw", "<cmd>set wrap!<cr>",                    { desc = "Toggle word wrap" })
  map("n", "<leader>uL", "<cmd>set list!<cr>",                    { desc = "Toggle list chars" })
  map("n", "<leader>us", "<cmd>set spell!<cr>",                   { desc = "Toggle spelling" })
end
map("n", "<leader>uc", function()
  vim.o.conceallevel = vim.o.conceallevel == 0 and 2 or 0
end, { desc = "Toggle conceallevel" })

map("n", "<leader>ui", "<cmd>Inspect<cr>",     { desc = "Inspect highlight groups" })
map("n", "<leader>uI", "<cmd>InspectTree<cr>", { desc = "Inspect Treesitter tree" })
map("n", "<leader>uS", function() require("theme").select_theme() end, { desc = "Language Syntax Theme" })

map("n", "<leader>qq", "<cmd>qa<cr>",          { desc = "Quit all" })
map("n", "<leader>L",  "<cmd>Lazy<cr>",        { desc = "Lazy plugin manager" })
map("n", "<leader>M",  "<cmd>Mason<cr>",       { desc = "Mason tool manager" })

-- ── Search & Replace ────────────────────────────────────────────────────────
map("n", "<leader>sr", ":%s/\\<<C-r><C-w>\\>//g<Left><Left>", { desc = "Replace word under cursor" })

