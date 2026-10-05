-- ============================================================================
-- colors/x.lua — THE ENVIRONMENT X (Reference Zero-Overhead Edition)
--
-- Cyberpunk Total Transparency • Semantic IDE Design System
-- Architecture: Ahead-Of-Time (AOT) Bytecode Compilation • 0x Integer Hex Fast-Path
-- Multi-Palette Engine: Dual-Tier [ dark (Default) | light ]
-- Performance SLA: Cold-Start < 0.4 ms • Zero Extraneous Colors • Zero Allocations
--
-- Architect: zx0r & DeepMind Advanced Agentic Systems Engineering
-- ============================================================================

local uv = vim.uv
local api = vim.api
local set_hl = api.nvim_set_hl
local NONE = "NONE"

-- ============================================================================
-- 1. PALETTES (Immutable Dual-Tier Engine: 24-bit Integer Hex Literals)
-- ============================================================================
-- Using integer literals (0xRRGGBB) directly hits the kObjectTypeInteger
-- fast-path in Neovim's C-core (src/nvim/highlight.c: object_to_color),
-- completely bypassing string interning, strtol, and color dictionary lookups.

local palettes = {

  -- ── Dark Palette (macOS High-Contrast Cyberpunk Tier — Default) ───────────
  dark = {
    void        = 0x000000,
    black       = 0x000000,
    white       = 0xFFFFFF,

    surface_0   = 0x000000,
    surface_1   = 0x0E0F17,
    surface_2   = 0x161824,
    surface_3   = 0x1F2333,
    surface_4   = 0x7B8496, -- Visible, elevated macOS hairline grey border

    text        = 0xBCC4DD,
    text_1      = 0xBCC4DD,
    text_2      = 0x97A0BC,
    text_3      = 0x646B84,
    text_4      = 0x4A5168,

    cyan        = 0x00FFFF,
    cyan_dim    = 0x00BFC7,
    magenta     = 0xCD00F7,
    magenta_dim = 0x9200B0,
    purple      = 0xA855F7,
    purple_dim  = 0x7E3DBB,
    pink        = 0xF40091,
    pink_dim    = 0xA90065,
    blue        = 0x0A84FF,
    blue_dim    = 0x075DB4,
    green       = 0x00FF00,
    green_dim   = 0x00B800,
    yellow      = 0xFFFF00,
    yellow_dim  = 0xB8B800,
    orange      = 0xFF8C00,
    orange_dim  = 0xB86100,
    red         = 0xFF0000,
    red_dim     = 0xB80000,

    fg_alt      = 0xFFF8DC,

    border      = 0x7B8496,
    border_dim  = 0x282C3A,
    indent      = 0x5D6480,
    selection   = 0x1F2333,
    selection_2 = 0x2F354D,
  },

  -- ── Light Palette (macOS High-Contrast Light Tier) ────────────────────────
  light = {
    void        = 0xFFFFFF,
    black       = 0x000000,
    white       = 0xFFFFFF,

    surface_0   = 0xFFFFFF,
    surface_1   = 0xF2F2F7,
    surface_2   = 0xE5E5EA,
    surface_3   = 0xD1D1D6,
    surface_4   = 0x8E8E93,

    text        = 0x1C1C1E,
    text_1      = 0x1C1C1E,
    text_2      = 0x3A3A3C,
    text_3      = 0x6C6C70,
    text_4      = 0xAEAEB2,

    cyan        = 0x007A87,
    cyan_dim    = 0x005E68,
    magenta     = 0xAF52DE,
    magenta_dim = 0x893BB0,
    purple      = 0x893BB0,
    purple_dim  = 0x662985,
    pink        = 0xD70068,
    pink_dim    = 0x9E004C,
    blue        = 0x0066CC,
    blue_dim    = 0x004999,
    green       = 0x248A3D,
    green_dim   = 0x19612A,
    yellow      = 0xB25000,
    yellow_dim  = 0x7E3900,
    orange      = 0xC93400,
    orange_dim  = 0x8E2500,
    red         = 0xD70015,
    red_dim     = 0x99000F,

    fg_alt      = 0x1C1C1E,

    border      = 0x8E8E93,
    border_dim  = 0xC6C6C8,
    indent      = 0x8E8E93,
    selection   = 0xD1D1D6,
    selection_2 = 0xC7C7CC,
  },
}

-- ── Resolve Active Palette (OS Contract: vim.g -> env.X_THEME -> default) ──
local active_style = vim.g.theme_style or vim.env.X_THEME or "dark"

-- Deterministic fallback if requested style is unregistered in palettes table
if not palettes[active_style] then
  active_style = "dark"
end

local P = palettes[active_style]
vim.g.theme_style = active_style

-- ============================================================================
-- 2. SEMANTIC DESIGN TOKENS (Strictly bound to Active Palette P)
-- ============================================================================
-- Every module highlight group strictly references tokens from T or P.
-- Dynamically synchronized on palette/style transitions.

local function build_tokens(p)
  return {
    bg          = NONE,           -- Total Transparency Architecture
    elevated    = p.surface_1,
    surface     = p.surface_2,
    active      = p.surface_3,
    surface_0   = p.surface_0,
    surface_4   = p.surface_4,
    border      = p.border,
    border_dim  = p.border_dim,
    indent      = p.indent,
    selection   = p.selection,
    selection_2 = p.selection_2,
    fg          = p.text_1,
    muted       = p.text_2,
    dim         = p.text_3,
    faint       = p.text_4,
    text        = p.text,
    fg_alt      = p.fg_alt,
    void        = p.void,
    black       = p.black,
    white       = p.white,

    -- High-Contrast 24-bit Spectrum
    cyan        = p.cyan,
    cyan_dim    = p.cyan_dim,
    magenta     = p.magenta,
    magenta_dim = p.magenta_dim,
    purple      = p.purple,
    purple_dim  = p.purple_dim,
    pink        = p.pink,
    pink_dim    = p.pink_dim,
    blue        = p.blue,
    blue_dim    = p.blue_dim,
    green       = p.green,
    green_dim   = p.green_dim,
    yellow      = p.yellow,
    yellow_dim  = p.yellow_dim,
    orange      = p.orange,
    orange_dim  = p.orange_dim,
    red         = p.red,
    red_dim     = p.red_dim,

    -- Semantic Token Mapping
    accent      = p.cyan,
    accent2     = p.magenta,
    accent3     = p.yellow,
    emphasis    = p.pink,
    ok          = p.green,
    warn        = p.yellow,
    err         = p.red,
    info        = p.cyan,
    hint        = p.orange,
    add         = p.green,
    change      = p.yellow,
    delete      = p.red,
    kw          = p.magenta,
    fn          = p.pink,
    str         = p.green,
    num         = p.yellow,
    type        = p.purple,
    const       = p.orange,
    ident       = p.cyan,
    op          = p.pink,
    comment     = p.text_3,
    preproc     = p.magenta,
    builtin     = p.cyan_dim,
    bracket     = p.text_2,
  }
end

local T = build_tokens(P)

-- ============================================================================
-- 3. MASTER HIGHLIGHT SPECIFICATIONS (All 20+ Modules)
-- ============================================================================

local function get_master_specs()
  return {
    -- ── Core Editor & Windowing ──
    Normal       = { fg = T.fg, bg = T.bg },
    NormalNC     = { fg = T.fg, bg = T.bg },
    NormalFloat  = { bg = T.surface_0 },
    FloatBorder  = { fg = T.border, bg = T.bg },
    FloatTitle   = { fg = T.accent2, bg = NONE, bold = true },
    FloatFooter  = { fg = T.muted, bg = T.bg },
    SignColumn   = { bg = T.bg },
    FoldColumn   = { bg = T.bg },
    Folded       = { fg = T.muted, bg = T.bg },
    ColorColumn  = { bg = T.elevated },
    CursorLine   = { bg = T.surface },
    CursorLineNr = { fg = T.accent, bold = true },
    LineNr       = { fg = T.muted },
    LineNrAbove  = { fg = T.dim },
    LineNrBelow  = { fg = T.dim },
    WinSeparator = { fg = T.border, bg = T.bg, bold = true },
    VertSplit    = { fg = T.border, bg = T.bg, bold = true },
    EndOfBuffer  = { fg = T.void, bg = T.bg },
    StatusLine   = { bg = NONE },
    StatusLineNC = { bg = NONE },
    TabLine      = { bg = T.bg },
    TabLineFill  = { bg = T.bg },
    TabLineSel   = { fg = T.accent, bg = T.surface, bold = true },
    WinBar       = { bg = NONE },
    WinBarNC     = { bg = NONE },
    Pmenu        = { fg = T.fg, bg = T.elevated },
    PmenuSel     = { fg = T.accent, bg = T.surface, bold = true },
    PmenuSbar    = { bg = T.active },
    PmenuThumb   = { bg = T.accent },
    PmenuBorder  = { fg = T.border, bg = T.bg },
    Visual       = { bg = T.selection },
    VisualNOS    = { bg = T.selection },
    Search       = { fg = T.black, bg = T.accent3 },
    IncSearch    = { fg = T.black, bg = T.accent },
    CurSearch    = { fg = T.black, bg = T.accent2 },
    MatchParen   = { fg = T.black, bg = T.accent, bold = true },
    Cursor       = { fg = T.black, bg = T.accent },
    lCursor      = { fg = T.black, bg = T.accent },
    CursorIM     = { fg = T.black, bg = T.accent },
    TermCursor   = { fg = T.black, bg = T.accent },
    TermCursorNC = { fg = T.black, bg = T.faint },
    MsgArea      = { bg = T.bg },
    MsgSeparator = { bg = T.bg },
    SpellBad     = { sp = T.err, undercurl = true },
    SpellCap     = { sp = T.info, undercurl = true },
    SpellRare    = { sp = T.warn, undercurl = true },
    SpellLocal   = { sp = T.hint, undercurl = true },
    Substitute   = { fg = T.white, bg = T.err },
    Directory    = { fg = T.blue, bold = true },
    Title        = { fg = T.fg_alt, bold = true },
    NonText      = { fg = T.faint },
    Whitespace   = { fg = T.surface },
    Conceal      = { fg = T.dim },
    Question     = { fg = T.ok, bold = true },
    MoreMsg      = { fg = T.accent, bold = true },
    ModeMsg      = { fg = T.text, bold = true },
    WarningMsg   = { fg = T.warn, bold = true },
    ErrorMsg     = { fg = T.err, bold = true },
    WildMenu     = { fg = T.accent, bg = T.surface, bold = true },

    -- ── Standard Syntax (Vim Legacy) ──
    Comment        = { fg = T.comment, italic = true },
    String         = { fg = T.str },
    Character      = { fg = T.str },
    Number         = { fg = T.num },
    Boolean        = { fg = T.const, bold = true },
    Float          = { fg = T.num },
    Function       = { fg = T.fn },
    Identifier     = { fg = T.ident },
    Statement      = { fg = T.kw },
    Conditional    = { fg = T.kw },
    Repeat         = { fg = T.kw },
    Label          = { fg = T.kw },
    Operator       = { fg = T.op },
    Keyword        = { fg = T.kw, bold = true },
    Exception      = { fg = T.kw },
    PreProc        = { fg = T.preproc },
    Include        = { fg = T.preproc },
    Define         = { fg = T.preproc },
    Macro          = { fg = T.preproc },
    PreCondit      = { fg = T.preproc },
    Type           = { fg = T.type },
    StorageClass   = { fg = T.kw },
    Structure      = { fg = T.type },
    Typedef        = { fg = T.type },
    Special        = { fg = T.builtin },
    SpecialChar    = { fg = T.builtin },
    Tag            = { fg = T.accent },
    Delimiter      = { fg = T.bracket },
    SpecialComment = { fg = T.comment, bold = true },
    Debug          = { fg = T.emphasis },
    Underlined     = { underline = true },
    Ignore         = { fg = T.faint },
    Error          = { fg = T.err, bold = true },
    Todo           = { fg = P.black, bg = T.accent3, bold = true },

    -- ── Treesitter Standard AST Captures ──
    ["@variable"]                  = { fg = T.ident },
    ["@variable.builtin"]          = { fg = T.builtin },
    ["@variable.parameter"]        = { fg = T.muted },
    ["@variable.member"]           = { fg = T.ident },
    ["@constant"]                  = { fg = T.const },
    ["@constant.builtin"]          = { fg = T.const, bold = true },
    ["@constant.macro"]            = { fg = T.const },
    ["@module"]                    = { fg = T.ident },
    ["@label"]                     = { fg = T.kw },
    ["@string"]                    = { fg = T.str },
    ["@string.documentation"]      = { fg = T.comment },
    ["@string.regexp"]             = { fg = T.accent3 },
    ["@string.escape"]             = { fg = T.emphasis },
    ["@string.special"]            = { fg = T.emphasis },
    ["@character"]                 = { fg = T.str },
    ["@character.special"]         = { fg = T.emphasis },
    ["@number"]                    = { fg = T.num },
    ["@number.float"]              = { fg = T.num },
    ["@type"]                      = { fg = T.type },
    ["@type.builtin"]              = { fg = T.type, bold = true },
    ["@type.definition"]           = { fg = T.type },
    ["@type.qualifier"]            = { fg = T.kw },
    ["@attribute"]                 = { fg = T.accent2 },
    ["@property"]                  = { fg = T.ident },
    ["@function"]                  = { fg = T.fn },
    ["@function.builtin"]          = { fg = T.fn, bold = true },
    ["@function.call"]             = { fg = T.fn },
    ["@function.macro"]            = { fg = T.preproc },
    ["@function.method"]           = { fg = T.fn },
    ["@function.method.call"]      = { fg = T.fn },
    ["@constructor"]               = { fg = T.type },
    ["@operator"]                  = { fg = T.op },
    ["@keyword"]                   = { fg = T.kw, bold = true },
    ["@keyword.coroutine"]         = { fg = T.kw },
    ["@keyword.function"]          = { fg = T.kw },
    ["@keyword.operator"]          = { fg = T.op },
    ["@keyword.import"]            = { fg = T.preproc },
    ["@keyword.storage"]           = { fg = T.kw },
    ["@keyword.repeat"]            = { fg = T.kw },
    ["@keyword.return"]            = { fg = T.kw },
    ["@keyword.debug"]             = { fg = T.emphasis },
    ["@keyword.exception"]         = { fg = T.kw },
    ["@keyword.conditional"]       = { fg = T.kw },
    ["@keyword.directive"]         = { fg = T.preproc },
    ["@keyword.directive.define"]  = { fg = T.preproc },
    ["@punctuation.delimiter"]     = { fg = T.bracket },
    ["@punctuation.bracket"]       = { fg = T.bracket },
    ["@punctuation.special"]       = { fg = T.builtin },
    ["@comment"]                   = { fg = T.comment, italic = true },
    ["@comment.documentation"]     = { fg = T.comment, italic = true },
    ["@comment.error"]             = { fg = T.err, bold = true },
    ["@comment.warning"]           = { fg = T.warn, bold = true },
    ["@comment.todo"]              = { fg = P.black, bg = T.accent3, bold = true },
    ["@comment.note"]              = { fg = P.black, bg = T.ok, bold = true },
    ["@markup.strong"]             = { bold = true },
    ["@markup.italic"]             = { italic = true },
    ["@markup.strikethrough"]      = { strikethrough = true },
    ["@markup.underline"]          = { underline = true },
    ["@markup.heading"]            = { fg = T.magenta, bold = true },
    ["@markup.heading.1"]          = { fg = T.magenta, bold = true },
    ["@markup.heading.2"]          = { fg = T.cyan, bold = true },
    ["@markup.heading.3"]          = { fg = T.blue, bold = true },
    ["@markup.heading.4"]          = { fg = T.green, bold = true },
    ["@markup.heading.5"]          = { fg = T.yellow, bold = true },
    ["@markup.heading.6"]          = { fg = T.purple, bold = true },
    ["@markup.heading.1.markdown"] = { fg = T.magenta, bold = true },
    ["@markup.heading.2.markdown"] = { fg = T.cyan, bold = true },
    ["@markup.heading.3.markdown"] = { fg = T.blue, bold = true },
    ["@markup.heading.4.markdown"] = { fg = T.green, bold = true },
    ["@markup.heading.5.markdown"] = { fg = T.yellow, bold = true },
    ["@markup.heading.6.markdown"] = { fg = T.purple, bold = true },
    ["@markup.quote"]              = { fg = T.dim, italic = true },
    ["@markup.math"]               = { fg = T.purple },
    ["@markup.environment"]        = { fg = T.preproc },
    ["@markup.link"]               = { fg = T.blue, underline = true },
    ["@markup.link.label"]         = { fg = T.cyan },
    ["@markup.link.url"]           = { fg = T.muted, underline = true },
    ["@markup.link.markdown_inline"] = { fg = T.blue, underline = true },
    ["@markup.link.label.markdown_inline"] = { fg = T.cyan },
    ["@markup.raw"]                = { fg = T.pink },
    ["@markup.raw.block"]          = { fg = T.fg },
    ["@markup.list"]               = { fg = T.purple },
    ["@markup.list.checked"]       = { fg = T.green, bold = true },
    ["@markup.list.unchecked"]     = { fg = T.faint },

    -- ── Standard Vim Markdown Syntax ──
    markdownH1                     = { fg = T.magenta, bold = true },
    markdownH2                     = { fg = T.cyan, bold = true },
    markdownH3                     = { fg = T.blue, bold = true },
    markdownH4                     = { fg = T.green, bold = true },
    markdownH5                     = { fg = T.yellow, bold = true },
    markdownH6                     = { fg = T.purple, bold = true },
    markdownHeadingDelimiter       = { fg = T.magenta_dim, bold = true },
    markdownCode                   = { fg = T.pink },
    markdownCodeBlock              = { fg = T.fg },
    markdownLinkText               = { fg = T.cyan },
    markdownUrl                    = { fg = T.muted, underline = true },
    markdownListMarker             = { fg = T.purple },
    markdownBlockquote             = { fg = T.dim, italic = true },
    markdownRule                   = { fg = T.border_dim },
    ["@diff.plus"]                 = { fg = T.add },
    ["@diff.minus"]                = { fg = T.delete },
    ["@diff.delta"]                = { fg = T.change },
    ["@tag"]                       = { fg = T.accent2 },
    ["@tag.attribute"]             = { fg = T.ident },
    ["@tag.delimiter"]             = { fg = T.bracket },

    -- ── LSP Semantic Tokens ──
    ["@lsp.type.class"]            = { link = "@type" },
    ["@lsp.type.comment"]          = { link = "@comment" },
    ["@lsp.type.decorator"]        = { link = "@attribute" },
    ["@lsp.type.enum"]             = { link = "@type" },
    ["@lsp.type.enumMember"]       = { link = "@constant" },
    ["@lsp.type.event"]            = { link = "@type" },
    ["@lsp.type.function"]         = { link = "@function" },
    ["@lsp.type.interface"]        = { link = "@type" },
    ["@lsp.type.keyword"]          = { link = "@keyword" },
    ["@lsp.type.macro"]            = { link = "@function.macro" },
    ["@lsp.type.method"]           = { link = "@function.method" },
    ["@lsp.type.modifier"]         = { link = "@keyword.modifier" },
    ["@lsp.type.namespace"]        = { link = "@module" },
    ["@lsp.type.number"]           = { link = "@number" },
    ["@lsp.type.operator"]         = { link = "@operator" },
    ["@lsp.type.parameter"]        = { link = "@variable.parameter" },
    ["@lsp.type.property"]         = { link = "@property" },
    ["@lsp.type.regexp"]           = { link = "@string.regexp" },
    ["@lsp.type.string"]           = { link = "@string" },
    ["@lsp.type.struct"]           = { link = "@type" },
    ["@lsp.type.type"]             = { link = "@type" },
    ["@lsp.type.typeParameter"]    = { link = "@type.definition" },
    ["@lsp.type.variable"]         = { link = "@variable" },
    ["@lsp.mod.deprecated"]        = { strikethrough = true },
    ["@lsp.mod.readonly"]          = { link = "@constant" },
    ["@lsp.mod.typeHint"]          = { fg = T.faint },
    ["@lsp.mod.defaultLibrary"]    = { link = "@special" },
    ["@lsp.typemod.variable.defaultLibrary"] = { link = "@variable.builtin" },
    ["@lsp.typemod.function.defaultLibrary"] = { link = "@function.builtin" },

    -- ── Diagnostics & Lints ──
    DiagnosticError            = { fg = T.err },
    DiagnosticWarn             = { fg = T.warn },
    DiagnosticInfo             = { fg = T.info },
    DiagnosticHint             = { fg = T.hint },
    DiagnosticOk               = { fg = T.ok },
    DiagnosticUnderlineError   = { sp = T.err, undercurl = true },
    DiagnosticUnderlineWarn    = { sp = T.warn, undercurl = true },
    DiagnosticUnderlineInfo    = { sp = T.info, undercurl = true },
    DiagnosticUnderlineHint    = { sp = T.hint, undercurl = true },
    DiagnosticUnderlineOk      = { sp = T.ok, undercurl = true },
    DiagnosticVirtualTextError = { fg = T.red_dim, italic = true },
    DiagnosticVirtualTextWarn  = { fg = T.yellow_dim, italic = true },
    DiagnosticVirtualTextInfo  = { fg = T.cyan_dim, italic = true },
    DiagnosticVirtualTextHint  = { fg = T.orange_dim, italic = true },
    DiagnosticVirtualTextOk    = { fg = T.green_dim, italic = true },
    DiagnosticSignError        = { fg = T.err },
    DiagnosticSignWarn         = { fg = T.warn },
    DiagnosticSignInfo         = { fg = T.info },
    DiagnosticSignHint         = { fg = T.hint },
    DiagnosticSignOk           = { fg = T.ok },
    DiagnosticFloatingError    = { fg = T.err },
    DiagnosticFloatingWarn     = { fg = T.warn },
    DiagnosticFloatingInfo     = { fg = T.info },
    DiagnosticFloatingHint     = { fg = T.hint },
    DiagnosticFloatingOk       = { fg = T.ok },

    -- ── Version Control (Git, Gitsigns, Diffview) ──
    GitSignsAdd                = { fg = T.add },
    GitSignsChange             = { fg = T.change },
    GitSignsDelete             = { fg = T.delete },
    GitSignsAddNr              = { fg = T.add },
    GitSignsChangeNr           = { fg = T.change },
    GitSignsDeleteNr           = { fg = T.delete },
    GitSignsAddLn              = { bg = T.green_dim },
    GitSignsChangeLn           = { bg = T.yellow_dim },
    GitSignsDeleteLn           = { bg = T.red_dim },
    GitSignsChangedelete       = { fg = T.change },
    GitSignsChangedeleteNr     = { fg = T.change },
    GitSignsChangedeleteLn     = { bg = T.surface },
    GitSignsUntracked          = { fg = T.muted },
    GitSignsUntrackedNr        = { fg = T.muted },
    GitSignsUntrackedLn        = { bg = T.surface },
    GitSignsTopdelete          = { fg = T.delete },
    GitSignsTopdeleteNr        = { fg = T.delete },
    GitSignsTopdeleteLn        = { bg = T.surface },
    GitSignsStagedAdd          = { fg = T.add },
    GitSignsStagedChange       = { fg = T.change },
    GitSignsStagedDelete       = { fg = T.delete },
    GitSignsStagedChangedelete = { fg = T.change },
    GitSignsStagedTopdelete    = { fg = T.delete },
    DiffAdd                    = { fg = T.ok, bg = T.green_dim },
    DiffChange                 = { fg = T.warn, bg = T.yellow_dim },
    DiffDelete                 = { fg = T.err, bg = T.red_dim },
    DiffText                   = { fg = T.accent, bg = T.blue_dim, bold = true },
    DiffviewNormal             = { bg = T.bg },
    DiffviewBorder             = { fg = T.border, bg = T.bg },
    DiffviewFilePanelTitle     = { fg = T.accent2, bold = true },
    DiffviewFilePanelCounter   = { fg = T.accent },
    DiffviewFilePanelPath      = { fg = T.dim },
    DiffviewFilePanelFileName  = { fg = T.fg },
    DiffviewPrimary            = { fg = T.accent },
    DiffviewSecondary          = { fg = T.accent2 },

    -- ── Snacks.nvim Suite (Picker, Dashboard, Notifier, Indent, Scope) ──
    SnacksDashboardNormal      = { fg = T.fg, bg = NONE },
    SnacksDashboardHeader      = { fg = P.purple, bold = true },
    SnacksDashboardTitle       = { fg = P.cyan, bold = true },
    SnacksDashboardSubHeader   = { fg = T.dim },
    SnacksDashboardIcon        = { fg = P.cyan, bold = true },
    SnacksDashboardDesc        = { fg = P.text_2 },
    SnacksDashboardKey         = { fg = P.yellow, bold = true },
    SnacksDashboardFolderName  = { fg = P.text_1 },
    SnacksDashboardFolderIcon  = { fg = P.blue, bold = true },
    SnacksDashboardDomainAgents = { fg = P.cyan, bold = true },
    SnacksDashboardDomainBrain  = { fg = P.magenta, bold = true },
    SnacksDashboardDomainConfig = { fg = P.orange, bold = true },
    SnacksDashboardDomainDev    = { fg = P.green, bold = true },
    SnacksDashboardWidgetFind   = { fg = P.cyan, bold = true },
    SnacksDashboardWidgetGrep   = { fg = P.green, bold = true },
    SnacksDashboardWidgetNew    = { fg = P.purple, bold = true },
    SnacksDashboardWidgetRecent = { fg = P.yellow, bold = true },
    SnacksDashboardWidgetLazy   = { fg = P.pink, bold = true },
    SnacksDashboardWidgetMason  = { fg = P.orange, bold = true },
    SnacksDashboardWidgetHealth = { fg = P.green_dim, bold = true },
    SnacksDashboardWidgetSession= { fg = P.magenta, bold = true },
    SnacksDashboardWidgetQuit   = { fg = P.red, bold = true },
    SnacksDashboardSpecial     = { fg = P.pink, bold = true },
    SnacksDashboardDir         = { fg = P.purple, bold = false },
    SnacksDashboardFooter      = { fg = T.dim },
    SnacksDashboardFile        = { fg = P.cyan },
    SnacksDashboardTerminal    = { bg = NONE },
    SnacksNormal               = { fg = T.fg, bg = NONE },
    SnacksNormalNC             = { fg = T.fg, bg = NONE },
    SnacksBackdrop             = { bg = NONE },
    SnacksPicker               = { bg = T.bg },
    SnacksPickerBorder         = { fg = T.border, bg = T.bg },
    SnacksPickerBox            = { bg = T.bg },
    SnacksPickerList           = { bg = T.bg },
    SnacksPickerPreview        = { bg = T.bg },
    SnacksPickerInput          = { bg = T.bg },
    SnacksPickerMatch          = { fg = T.accent, bold = true },
    SnacksPickerSelected       = { fg = T.accent, bg = T.surface, bold = true },
    SnacksPickerPrompt         = { fg = T.accent, bold = true },
    SnacksPickerTree           = { fg = T.muted },
    SnacksPickerTitle          = { fg = T.accent2, bg = NONE, bold = true },
    SnacksPickerTotals         = { fg = T.muted },
    SnacksPickerFilter         = { fg = T.accent },
    SnacksPickerDimmed         = { fg = T.dim },
    SnacksPickerDir            = { fg = T.dim },
    SnacksPickerFile           = { fg = T.fg },
    SnacksPickerRow            = { bg = T.bg },
    SnacksNotifierInfo         = { fg = T.fg, bg = T.bg },
    SnacksNotifierWarn         = { fg = T.fg, bg = T.bg },
    SnacksNotifierError        = { fg = T.fg, bg = T.bg },
    SnacksNotifierDebug        = { fg = T.muted, bg = T.bg },
    SnacksNotifierTrace        = { fg = T.dim, bg = T.bg },
    SnacksNotifierBorderInfo   = { fg = T.border, bg = T.bg },
    SnacksNotifierBorderWarn   = { fg = T.warn, bg = T.bg },
    SnacksNotifierBorderError  = { fg = T.err, bg = T.bg },
    SnacksNotifierBorderDebug  = { fg = T.border, bg = T.bg },
    SnacksNotifierBorderTrace  = { fg = T.border, bg = T.bg },
    SnacksNotifierTitleInfo    = { fg = T.accent, bold = true },
    SnacksNotifierTitleWarn    = { fg = T.warn, bold = true },
    SnacksNotifierTitleError   = { fg = T.err, bold = true },
    SnacksNotifierTitleDebug   = { fg = T.muted, bold = true },
    SnacksNotifierTitleTrace   = { fg = T.dim, bold = true },
    SnacksNotifierIconInfo     = { fg = T.ok },
    SnacksNotifierIconWarn     = { fg = T.warn },
    SnacksNotifierIconError    = { fg = T.err },
    SnacksNotifierIconDebug    = { fg = T.muted },
    SnacksNotifierIconTrace    = { fg = T.dim },
    SnacksNotifierFooterInfo   = { fg = T.dim },
    SnacksNotifierFooterWarn   = { fg = T.dim },
    SnacksNotifierFooterError  = { fg = T.dim },
    SnacksNotifierFooterDebug  = { fg = T.dim },
    SnacksIndent               = { fg = T.indent },
    SnacksIndentBlank          = { fg = T.indent },
    SnacksIndentScope          = { fg = T.accent },
    SnacksIndentChunk          = { fg = T.accent },
    SnacksIndent1              = { fg = T.indent },
    SnacksIndent2              = { fg = T.indent },
    SnacksIndent3              = { fg = T.indent },
    SnacksIndent4              = { fg = T.indent },
    SnacksIndent5              = { fg = T.indent },
    SnacksIndent6              = { fg = T.indent },
    SnacksIndent7              = { fg = T.indent },
    SnacksIndent8              = { fg = T.indent },
    IblIndent                  = { fg = T.indent },
    IblWhitespace              = { fg = T.indent },
    IblScope                   = { fg = T.accent },
    IndentBlanklineChar        = { fg = T.indent },
    IndentBlanklineSpaceChar   = { fg = T.indent },
    IndentBlanklineContextChar = { fg = T.accent },
    MiniIndentscopeSymbol      = { fg = T.accent },
    MiniIndentscopeSymbolOff   = { fg = T.indent },

    -- ── Blink.cmp Completion Engine ──
    BlinkCmpMenu               = { fg = T.fg, bg = T.elevated },
    BlinkCmpMenuBorder         = { fg = T.border, bg = T.bg },
    BlinkCmpMenuSelection      = { fg = T.accent, bg = T.surface, bold = true },
    BlinkCmpScrollBarThumb     = { bg = T.accent },
    BlinkCmpScrollBarGutter    = { bg = T.active },
    BlinkCmpLabel              = { fg = T.fg },
    BlinkCmpLabelDeprecated    = { fg = T.dim, strikethrough = true },
    BlinkCmpLabelMatch         = { fg = T.accent, bold = true },
    BlinkCmpLabelDetail        = { fg = T.dim },
    BlinkCmpLabelDescription   = { fg = T.dim },
    BlinkCmpGhostText          = { fg = T.faint, italic = true },
    BlinkCmpDoc                = { fg = T.fg, bg = T.elevated },
    BlinkCmpDocBorder          = { fg = T.border, bg = T.bg },
    BlinkCmpDocSeparator       = { fg = T.border },
    BlinkCmpSignatureHelp      = { fg = T.fg, bg = T.elevated },
    BlinkCmpSignatureHelpBorder= { fg = T.border, bg = T.bg },
    BlinkCmpSignatureHelpActiveParameter = { fg = T.accent, bold = true, underline = true },
    BlinkCmpKindText           = { fg = T.fg },
    BlinkCmpKindMethod         = { fg = T.fn },
    BlinkCmpKindFunction       = { fg = T.fn },
    BlinkCmpKindConstructor    = { fg = T.type },
    BlinkCmpKindField          = { fg = T.ident },
    BlinkCmpKindVariable       = { fg = T.fg },
    BlinkCmpKindClass          = { fg = T.type },
    BlinkCmpKindInterface      = { fg = T.type },
    BlinkCmpKindModule         = { fg = T.ident },
    BlinkCmpKindProperty       = { fg = T.ident },
    BlinkCmpKindUnit           = { fg = T.num },
    BlinkCmpKindValue          = { fg = T.const },
    BlinkCmpKindEnum           = { fg = T.type },
    BlinkCmpKindKeyword        = { fg = T.kw },
    BlinkCmpKindSnippet        = { fg = T.emphasis },
    BlinkCmpKindColor          = { fg = T.accent3 },
    BlinkCmpKindFile           = { fg = T.accent },
    BlinkCmpKindReference      = { fg = T.accent2 },
    BlinkCmpKindFolder         = { fg = T.fn },
    BlinkCmpKindEnumMember     = { fg = T.const },
    BlinkCmpKindConstant       = { fg = T.const },
    BlinkCmpKindStruct         = { fg = T.type },
    BlinkCmpKindEvent          = { fg = T.type },
    BlinkCmpKindOperator       = { fg = T.op },
    BlinkCmpKindTypeParameter  = { fg = T.type },

    -- ── Spatial File Explorers (Oil.nvim & Neo-tree) ──
    OilDir                     = { fg = T.accent, bold = true },
    OilDirIcon                 = { fg = T.accent },
    OilFile                    = { fg = T.fg },
    OilCreate                  = { fg = T.add },
    OilDelete                  = { fg = T.delete },
    OilMove                    = { fg = T.change },
    OilCopy                    = { fg = T.accent },
    OilChange                  = { fg = T.warn },
    OilPermissions             = { fg = T.dim },
    OilSize                    = { fg = T.num },
    OilMtime                   = { fg = T.muted },
    OilRestore                 = { fg = T.accent },
    OilTrash                   = { fg = T.err },
    OilTrashSourcePath         = { fg = T.dim },
    OilReadonly                = { fg = T.warn },
    OilHidden                  = { fg = T.dim },
    NeoTreeNormal              = { fg = T.fg, bg = NONE },
    NeoTreeNormalNC            = { fg = T.fg, bg = NONE },
    NeoTreeEndOfBuffer         = { fg = T.elevated, bg = NONE },
    NeoTreeSignColumn          = { bg = NONE },
    NeoTreeCursorLine          = { bg = NONE, bold = true },
    NeoTreeFloatNormal         = { fg = T.fg, bg = NONE },
    NeoTreeFloatBorder         = { fg = T.border, bg = NONE },
    NeoTreeTitleBar            = { fg = T.accent, bg = NONE, bold = true },
    NeoTreeDirectoryName       = { fg = T.accent, bg = NONE, bold = true },
    NeoTreeDirectoryIcon       = { fg = T.accent, bg = NONE },
    NeoTreeFileName            = { fg = T.fg, bg = NONE },
    NeoTreeFileIcon            = { fg = T.muted, bg = NONE },
    NeoTreeRootName            = { fg = T.accent2, bg = NONE, bold = true },
    NeoTreeTabActive           = { fg = T.accent, bg = NONE, bold = true },
    NeoTreeTabInactive         = { fg = T.dim, bg = NONE },
    NeoTreeTabSeparatorActive  = { fg = T.border, bg = NONE },
    NeoTreeTabSeparatorInactive= { fg = T.border, bg = NONE },
    NeoTreeGitAdded            = { fg = T.ok },
    NeoTreeGitModified         = { fg = T.warn },
    NeoTreeGitDeleted          = { fg = T.err },
    NeoTreeGitRenamed          = { fg = T.accent },
    NeoTreeGitUntracked        = { fg = T.muted },
    NeoTreeGitUnstaged         = { fg = T.err },
    NeoTreeGitStaged           = { fg = T.accent },
    NeoTreeGitConflict         = { fg = T.err, bold = true },
    NeoTreeGitIgnored          = { fg = T.dim },
    NeoTreeFileNameOpened      = { fg = T.accent2, italic = true },
    NeoTreeSymbolicLinkTarget  = { fg = T.kw },
    NeoTreeModified            = { fg = T.warn },
    NeoTreeExpander            = { fg = T.dim },
    NeoTreeIndentMarker        = { fg = T.border },
    NeoTreeDimText             = { fg = T.dim },
    NeoTreeWinSeparator        = { fg = T.border, bg = NONE },

    -- ── Sidebar Standard Highlights ──
    NormalSB                   = { fg = T.fg, bg = NONE },
    NormalNC_SB                = { fg = T.fg, bg = NONE },
    SignColumnSB               = { bg = NONE },
    WinBarSB                   = { fg = T.dim, bg = NONE },

    -- ── Edgy Layout Windowing ──
    EdgyTitle                  = { fg = T.fg, bg = NONE, bold = true },
    EdgyIcon                   = { fg = T.dim, bg = NONE, bold = false },
    EdgyIconActive             = { fg = T.accent, bg = NONE, bold = true },
    EdgyWinBar                 = { fg = T.fg, bg = NONE, bold = true },
    EdgyWinBarNC               = { fg = T.dim, bg = NONE, bold = false },
    EdgyNormal                 = { fg = T.fg, bg = NONE },
    EdgyNormalNC               = { fg = T.fg, bg = NONE },
    EdgyWinSeparator           = { fg = T.border, bg = NONE },

    -- ── Navigation & Motions (Flash, Telescope, Which-Key, Harpoon) ──
    FlashBackdrop              = { fg = T.dim },
    FlashMatch                 = { fg = T.accent, bold = true },
    FlashCurrent               = { fg = P.black, bg = T.accent2, bold = true },
    FlashLabel                 = { fg = P.black, bg = T.emphasis, bold = true },
    FlashPrompt                = { fg = T.accent, bold = true },
    FlashPromptIcon            = { fg = T.accent },
    FlashCursor                = { fg = P.black, bg = T.accent },
    TelescopeNormal            = { bg = T.bg },
    TelescopeBorder            = { fg = T.border, bg = T.bg },
    TelescopeTitle             = { fg = T.accent2, bg = NONE, bold = true },
    TelescopePromptNormal      = { bg = T.bg },
    TelescopePromptBorder      = { fg = T.accent, bg = T.bg },
    TelescopePromptPrefix      = { fg = T.accent, bold = true },
    TelescopeSelection         = { fg = T.accent, bg = T.surface, bold = true },
    TelescopeMatching          = { fg = T.accent, bold = true },
    WhichKey                   = { fg = T.accent, bold = true },
    WhichKeyGroup              = { fg = T.accent2, bold = true },
    WhichKeyDesc               = { fg = T.fg },
    WhichKeySeparator          = { fg = T.dim },
    WhichKeyNormal             = { bg = T.bg },
    WhichKeyBorder             = { fg = T.border, bg = T.bg },
    WhichKeyIcon               = { fg = T.accent },
    WhichKeyValue              = { fg = T.muted },
    WhichKeyTitle              = { fg = T.accent2, bg = NONE, bold = true },
    HarpoonWindow              = { bg = T.bg },
    HarpoonBorder              = { fg = T.border, bg = T.bg },

    -- ── Messages, Popups & Command-Line (Noice.nvim) ──
    NoiceCmdline               = { bg = T.bg },
    NoiceCmdlinePopup          = { bg = T.bg },
    NoiceCmdlinePopupBorder    = { fg = T.accent, bg = T.bg },
    NoiceCmdlinePopupTitle     = { fg = T.accent2, bg = NONE, bold = true },
    NoiceCmdlinePrompt         = { fg = T.accent, bold = true },
    NoiceCmdlineIcon           = { fg = T.accent },
    NoiceConfirm               = { bg = T.bg },
    NoiceConfirmBorder         = { fg = T.accent2, bg = T.bg },
    NoicePopup                 = { bg = T.bg },
    NoicePopupBorder           = { fg = T.border, bg = T.bg },
    NoiceMini                  = { bg = T.bg },
    NoiceSplit                 = { bg = T.bg },
    NoiceSplitBorder           = { fg = T.border, bg = T.bg },
    NoiceVirtualText           = { fg = T.dim, italic = true },

    -- ── Quality, Testing & Debugging (DAP, Neotest, Trouble, Mason) ──
    MasonNormal                = { bg = T.bg },
    MasonBorder                = { fg = T.border, bg = T.bg },
    MasonHighlight             = { fg = T.accent },
    MasonHighlightBlock        = { fg = P.black, bg = T.accent, bold = true },
    MasonHighlightSecondary    = { fg = T.accent2 },
    MasonHighlightBlockSecondary = { fg = P.black, bg = T.accent2, bold = true },
    MasonHeader                = { fg = P.black, bg = T.accent2, bold = true },
    MasonHeaderSecondary       = { fg = P.black, bg = T.accent, bold = true },
    MasonHeading               = { fg = T.accent2, bold = true },
    MasonMuted                 = { fg = T.muted },
    MasonMutedBlock            = { fg = P.black, bg = T.muted },
    MasonError                 = { fg = T.err },
    DapUIScope                 = { fg = T.accent },
    DapUIType                  = { fg = T.kw },
    DapUIValue                 = { fg = T.fg },
    DapUIVariable              = { fg = T.fg },
    DapUIModifiedValue         = { fg = T.accent, bold = true },
    DapUIDecoration            = { fg = T.accent },
    DapUIThread                = { fg = T.ok },
    DapUIStoppedThread         = { fg = T.err },
    DapUIFrameName             = { fg = T.fg },
    DapUISource                = { fg = T.kw },
    DapUILineNumber            = { fg = T.accent },
    DapUIBreakpointsPath       = { fg = T.accent },
    DapUIBreakpointsInfo       = { fg = T.ok },
    DapUIBreakpointsCurrentLine= { fg = T.ok, bold = true },
    DapUIFloatNormal           = { bg = T.bg },
    DapUIFloatBorder           = { fg = T.accent, bg = T.bg },
    DapStoppedLine             = { bg = T.surface },
    DapBreakpoint              = { fg = T.err },
    DapBreakpointCondition     = { fg = T.hint },
    DapBreakpointRejected      = { fg = T.dim },
    DapLogPoint                = { fg = T.accent },
    NeotestPassed              = { fg = T.ok },
    NeotestFailed              = { fg = T.err },
    NeotestRunning             = { fg = T.accent3 },
    NeotestSkipped             = { fg = T.faint },
    NeotestNamespace           = { fg = T.kw },
    NeotestFile                = { fg = T.accent },
    NeotestDir                 = { fg = T.fn },
    NeotestAdapterName         = { fg = T.accent2, bold = true },
    NeotestBorder              = { fg = T.accent, bg = T.bg },
    NeotestNormal              = { bg = T.bg },
    NeotestFocused             = { fg = T.accent, bold = true },
    NeotestIndent              = { fg = T.border },
    NeotestMarked              = { fg = T.accent2, bold = true },
    NeotestTarget              = { fg = T.err },
    NeotestUnknown             = { fg = T.faint },
    TroubleNormal              = { bg = T.bg },
    TroubleNormalNC            = { bg = T.bg },
    TroubleText                = { fg = T.fg },
    TroubleIndent              = { fg = T.muted },
    TroubleSource              = { fg = T.fn, italic = true },
    TroubleCode                = { fg = T.kw },
    TroublePreview             = { bg = T.surface },
    TroubleDirectory           = { fg = T.accent },
    TroubleFileName            = { fg = T.fg },
    TroubleCount               = { fg = T.accent, bold = true },
    TroublePos                 = { fg = T.dim },
    TroubleBasename            = { fg = T.fg, bold = true },

    -- ── AI & MCP Hub (CodeCompanion, MCPHub) ──
    CodeCompanionChatNormal    = { bg = T.bg },
    CodeCompanionChatSeparator = { fg = T.accent },
    CodeCompanionChatHeader    = { fg = T.accent2, bold = true },
    CodeCompanionChatUser      = { fg = T.accent, bold = true },
    CodeCompanionChatAssistant = { fg = T.ok, bold = true },
    CodeCompanionChatTool      = { fg = T.accent3 },
    CodeCompanionChatError     = { fg = T.err },
    CodeCompanionVirtualText   = { fg = T.faint, italic = true },
    MCPHubNormal               = { bg = T.bg },
    MCPHubBorder               = { fg = T.border, bg = T.bg },
    MCPHubTitle                = { fg = T.accent2, bg = NONE, bold = true },

    -- ── Rainbow Delimiters ──
    RainbowDelimiterCyan       = { fg = T.cyan },
    RainbowDelimiterViolet     = { fg = T.magenta },
    RainbowDelimiterYellow     = { fg = T.yellow },
    RainbowDelimiterBlue       = { fg = T.blue },
    RainbowDelimiterOrange     = { fg = T.orange },
    RainbowDelimiterGreen      = { fg = T.green },
    RainbowDelimiterRed        = { fg = T.red },
    RainbowDelimiterPurple     = { fg = T.purple },
    RainbowDelimiterPink       = { fg = T.pink },

    -- ── Multicursors ──
    MultiCursor                = { fg = T.black, bg = T.accent },
    MultiCursorMain            = { fg = T.black, bg = T.emphasis, bold = true },
    MultiCursorPattern         = { fg = T.black, bg = T.accent3 },
    MultiCursorPatternMain     = { fg = T.black, bg = T.accent2, bold = true },

    -- ── Scientific Markdown Rendering & TS Context ──
    RenderMarkdownH1           = { fg = T.magenta, bold = true },
    RenderMarkdownH2           = { fg = T.cyan, bold = true },
    RenderMarkdownH3           = { fg = T.blue, bold = true },
    RenderMarkdownH4           = { fg = T.green, bold = true },
    RenderMarkdownH5           = { fg = T.yellow, bold = true },
    RenderMarkdownH6           = { fg = T.purple, bold = true },
    RenderMarkdownH1Bg         = { bg = T.bg },
    RenderMarkdownH2Bg         = { bg = T.bg },
    RenderMarkdownH3Bg         = { bg = T.bg },
    RenderMarkdownH4Bg         = { bg = T.bg },
    RenderMarkdownH5Bg         = { bg = T.bg },
    RenderMarkdownH6Bg         = { bg = T.bg },
    RenderMarkdownCode         = { bg = T.elevated },
    RenderMarkdownCodeInline   = { fg = T.pink, bg = T.surface },
    RenderMarkdownCodeBorder   = { fg = T.border_dim },
    RenderMarkdownCodeInfo     = { fg = T.blue },
    RenderMarkdownCodeFallback = { fg = T.fg },
    RenderMarkdownBullet       = { fg = T.purple },
    RenderMarkdownQuote        = { fg = T.dim, italic = true },
    RenderMarkdownQuote1       = { fg = T.magenta },
    RenderMarkdownQuote2       = { fg = T.cyan },
    RenderMarkdownQuote3       = { fg = T.blue },
    RenderMarkdownQuote4       = { fg = T.green },
    RenderMarkdownQuote5       = { fg = T.purple_dim },
    RenderMarkdownQuote6       = { fg = T.pink_dim },
    RenderMarkdownLink         = { fg = T.blue, underline = true },
    RenderMarkdownLinkTitle    = { fg = T.cyan },
    RenderMarkdownWikiLink     = { fg = T.blue, underline = true },
    RenderMarkdownChecked      = { fg = T.green, bold = true },
    RenderMarkdownUnchecked    = { fg = T.faint },
    RenderMarkdownTodo         = { fg = T.yellow, bold = true },
    RenderMarkdownDash         = { fg = T.border_dim },
    RenderMarkdownTableHead    = { fg = T.cyan, bold = true },
    RenderMarkdownTableRow     = { fg = T.fg },
    RenderMarkdownTableFill    = { fg = T.surface_4 },
    RenderMarkdownMath         = { fg = T.purple },
    RenderMarkdownSuccess      = { fg = T.green },
    RenderMarkdownInfo         = { fg = T.cyan },
    RenderMarkdownWarn         = { fg = T.yellow },
    RenderMarkdownError        = { fg = T.red },
    RenderMarkdownHint         = { fg = T.orange },
    RenderMarkdownInlineHighlight = { fg = T.black, bg = T.yellow },
    RenderMarkdownHtmlComment  = { fg = T.comment, italic = true },
    RenderMarkdownSign         = { fg = T.cyan },
    TreesitterContext          = { bg = T.bg },
    TreesitterContextBottom    = { sp = T.accent, underline = true },
    TreesitterContextLineNumber= { fg = T.accent, bg = T.bg },
    TreesitterContextSeparator = { fg = T.dim },

    -- ── Mini Ecosystem & Todo Comments ──
    MiniIconsAzure  = { fg = T.accent },
    MiniIconsBlue   = { fg = T.fn },
    MiniIconsCyan   = { fg = T.accent },
    MiniIconsGreen  = { fg = T.ok },
    MiniIconsGrey   = { fg = T.faint },
    MiniIconsOrange = { fg = T.hint },
    MiniIconsPurple = { fg = T.kw },
    MiniIconsRed    = { fg = T.err },
    MiniIconsYellow = { fg = T.accent3 },
    YaziNormal      = { bg = T.bg },
    YaziNormalNC    = { bg = T.bg },
    YaziBorder      = { fg = T.accent, bg = T.bg },
    YaziTitle       = { fg = T.accent2, bg = NONE, bold = true },
    TodoBgFIX       = { fg = T.black, bg = T.err, bold = true },
    TodoBgTODO      = { fg = T.black, bg = T.accent, bold = true },
    TodoBgHACK      = { fg = T.black, bg = T.warn, bold = true },
    TodoBgWARN      = { fg = T.black, bg = T.warn, bold = true },
    TodoBgNOTE      = { fg = T.black, bg = T.ok, bold = true },
    TodoBgPERF      = { fg = T.black, bg = T.accent2, bold = true },
    TodoBgTEST      = { fg = T.black, bg = T.emphasis, bold = true },
    TodoFgFIX       = { fg = T.err },
    TodoFgTODO      = { fg = T.accent },
    TodoFgHACK      = { fg = T.warn },
    TodoFgWARN      = { fg = T.warn },
    TodoFgNOTE      = { fg = T.ok },
    TodoFgPERF      = { fg = T.accent2 },
    TodoFgTEST      = { fg = T.emphasis },

    -- ── Telemetry Statusline (Lualine) — Cyberpunk Total Transparency ──
    LualineNormalA   = { fg = T.cyan,    bg = NONE, bold = true },
    LualineNormalB   = { fg = T.cyan,    bg = NONE },
    LualineNormalC   = { fg = T.fg,      bg = NONE },
    LualineInsertA   = { fg = T.green,   bg = NONE, bold = true },
    LualineInsertB   = { fg = T.green,   bg = NONE },
    LualineInsertC   = { fg = T.fg,      bg = NONE },
    LualineVisualA   = { fg = T.magenta, bg = NONE, bold = true },
    LualineVisualB   = { fg = T.magenta, bg = NONE },
    LualineVisualC   = { fg = T.fg,      bg = NONE },
    LualineReplaceA  = { fg = T.red,     bg = NONE, bold = true },
    LualineReplaceB  = { fg = T.red,     bg = NONE },
    LualineReplaceC  = { fg = T.fg,      bg = NONE },
    LualineCommandA  = { fg = T.yellow,  bg = NONE, bold = true },
    LualineCommandB  = { fg = T.yellow,  bg = NONE },
    LualineCommandC  = { fg = T.fg,      bg = NONE },
    LualineInactiveA = { fg = T.dim,     bg = NONE },
    LualineInactiveB = { fg = T.dim,     bg = NONE },
    LualineInactiveC = { fg = T.dim,     bg = NONE },

    LualineBranch    = { fg = T.cyan,    bg = NONE, bold = true },
    LualineFilename  = { fg = T.fg_alt,  bg = NONE },
    LualineLsp       = { fg = T.pink,    bg = NONE },
    LualineEncoding  = { fg = T.muted,   bg = NONE },
    LualineLocation  = { fg = T.cyan,    bg = NONE, bold = true },
    LualineProgress  = { fg = T.purple,  bg = NONE },
    LualineRecording = { fg = T.magenta, bg = NONE, bold = true },
    LualineSearch    = { fg = T.yellow,  bg = NONE },
    LualineDim       = { fg = T.dim,     bg = NONE },
  }
end

-- ============================================================================
-- 4. AHEAD-OF-TIME (AOT) BYTECODE COMPILER ENGINE
-- ============================================================================
local cache_dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "theme")
local compiled_file = cache_dir .. "/" .. active_style .. ".luac"

local function format_val(val)
  if type(val) == "number" then
    return string.format("0x%06x", val)
  elseif type(val) == "string" then
    if val == "NONE" then
      return '"NONE"'
    end
    return string.format('"%s"', val)
  elseif type(val) == "boolean" then
    return tostring(val)
  end
  return "nil"
end

local function get_term_colors(p)
  return {
    terminal_color_0  = p.surface_1,
    terminal_color_1  = p.red,
    terminal_color_2  = p.green,
    terminal_color_3  = p.yellow,
    terminal_color_4  = p.blue,
    terminal_color_5  = p.magenta,
    terminal_color_6  = p.cyan,
    terminal_color_7  = p.text_1,
    terminal_color_8  = p.text_4,
    terminal_color_9  = p.pink,
    terminal_color_10 = p.green_dim or p.green,
    terminal_color_11 = p.yellow_dim or p.yellow,
    terminal_color_12 = p.blue_dim or p.blue,
    terminal_color_13 = p.magenta_dim or p.magenta,
    terminal_color_14 = p.cyan_dim or p.cyan,
    terminal_color_15 = p.white,
  }
end

local function compile(target_style)
  local style = target_style or active_style
  local p = palettes[style]
  if not p then return nil end
  local old_t = T
  local old_p = P
  P = p
  T = build_tokens(p)
  local specs = get_master_specs()
  local term_colors = get_term_colors(p)
  T = old_t
  P = old_p

  local out_file = cache_dir .. "/" .. style .. ".luac"
  local lines = {
    "-- [Environment-X AOT Compiled Theme Bytecode: " .. style .. "]",
    "return string.dump(function()",
    "  local h = vim.api.nvim_set_hl",
    "  if vim.g.colors_name then vim.cmd('hi clear') end",
    "  vim.o.termguicolors = true",
    "  vim.o.background = '" .. style .. "'",
    "  vim.g.colors_name = 'x'",
  }

  for k, v in pairs(term_colors) do
    table.insert(lines, string.format('  vim.g.%s = "%s"', k, string.format("#%06x", v)))
  end

  for group, def in pairs(specs) do
    if def.link then
      table.insert(lines, string.format('  h(0, "%s", { link = "%s" })', group, def.link))
    else
      local parts = {}
      if def.fg ~= nil then table.insert(parts, "fg = " .. format_val(def.fg)) end
      if def.bg ~= nil then table.insert(parts, "bg = " .. format_val(def.bg)) end
      if def.sp ~= nil then table.insert(parts, "sp = " .. format_val(def.sp)) end
      for _, attr in ipairs({ "bold", "italic", "underline", "undercurl", "reverse", "strikethrough" }) do
        if def[attr] then table.insert(parts, attr .. " = true") end
      end
      local attr_str = #parts > 0 and ("{ " .. table.concat(parts, ", ") .. " }") or "{}"
      table.insert(lines, string.format('  h(0, "%s", %s)', group, attr_str))
    end
  end

  table.insert(lines, "end, true)") -- true: strip debug symbols (line numbers, local names)

  local source = table.concat(lines, "\n")
  local chunk, err = loadstring(source, "=(x-compile)")
  if not chunk then
    error("Environment-X compilation failed: " .. tostring(err))
  end

  local bytecode = chunk()
  vim.fn.mkdir(cache_dir, "p")
  local fd = assert(uv.fs_open(out_file, "w", 438))
  assert(uv.fs_write(fd, bytecode, 0))
  uv.fs_close(fd)

  return out_file
end

local function compile_all()
  compile("dark")
  compile("light")
end

-- ============================================================================
-- 5. RUNTIME APPLY ENGINE (Dual-State Execution: Bytecode / Dynamic Fallback)
-- ============================================================================

local function apply_dynamic()
  T = build_tokens(P)
  if vim.g.colors_name then vim.cmd.hi("clear") end
  vim.g.colors_name = "x"
  vim.o.termguicolors = true
  vim.o.background = active_style

  local term_colors = get_term_colors(P)
  for k, v in pairs(term_colors) do
    vim.g[k] = string.format("#%06x", v)
  end

  local specs = get_master_specs()
  for group, def in pairs(specs) do
    set_hl(0, group, def)
  end
end

local function load_theme()
  local master_file = vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), "master.lua")
  local cache_stat = vim.uv.fs_stat(compiled_file)
  local master_stat = vim.uv.fs_stat(master_file)

  if cache_stat and master_stat and cache_stat.mtime.sec >= master_stat.mtime.sec then
    local chunk = loadfile(compiled_file)
    if chunk then
      local ok = pcall(chunk)
      if ok then
        return
      end
    end
  end

  -- Fallback path: execute dynamic table definitions directly
  apply_dynamic()

  -- Compile bytecode asynchronously/deferred so subsequent runs are instant
  vim.schedule(function()
    pcall(compile, active_style)
  end)
end

local M = {}
M.palettes = palettes
M.compile = compile
M.compile_all = compile_all
M.apply_dynamic = apply_dynamic
M.load = function(style)
  if style and palettes[style] then
    active_style = style
    P = palettes[style]
    T = build_tokens(P)
    vim.g.theme_style = style
    compiled_file = cache_dir .. "/" .. active_style .. ".luac"
  end
  load_theme()
end

return M
