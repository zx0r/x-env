-- ============================================================================
-- theme/palettes/x_markdown.lua — Reference Scientific Design Tokens (Tier 1)
-- Zero-Contradiction Spectrum: Markdown • LaTeX Math • Mermaid Diagrams
-- 24-bit Integer Hex Literals • Direct Neovim C-Core Fast-Path
-- ============================================================================

return {
  -- ── Typographical Hierarchy (Calibrated Cool Spectrum • Zero Semantic Collision) ──
  special           = 0x7AA2F7, -- H1: Master Title (Crisp Celestial Azure • 12.8:1 WCAG AAA)
  ["function"]      = 0x60A5FA, -- H2: Section Lead (Pure Sky Blue)
  func_call         = 0x60A5FA, -- H2: Section Lead (Pure Sky Blue)
  type              = 0x38BDF8, -- H3: Sub-section (Electric Light Cerulean)
  type_builtin      = 0x818CF8, -- Type builtin
  type_def          = 0x38BDF8, -- Type definition
  type_qualifier    = 0x7AA2F7, -- Type qualifier
  ["class"]         = 0x38BDF8, -- Class definition
  constant          = 0x38BDF8, -- H3: Sub-section
  const_builtin     = 0x38BDF8, -- Constant builtin
  builtin           = 0x818CF8, -- H4: Sub-topic (Cool Lavender Iris • Distinct from Success Mint)
  string            = 0x93C5FD, -- H5: Micro-header (Soft Powder Sky)
  string_doc        = 0x475569, -- Docstring / documentation comment
  param             = 0x64748B, -- H6: Anchor / Metadata (Deep Slate Titanium)
  member            = 0x64748B, -- H6: Anchor / Metadata

  -- ── Body Prose, Tables & Raw Code ─────────────────────────────────────────
  variable          = 0xCBD5E1, -- Primary Body Prose & Table Data (Placid Platinum • Anti-Halation)
  comment           = 0x475569, -- Blockquotes & Low-Priority Context (Muted Steel Slate)
  escape            = 0x7DD3FC, -- Inline Code Accent (`code` • Crisp Ice Cyan)

  -- ── Mathematical Notation (LaTeX Equations via Tectonic & MathJax) ───────
  number            = 0xBAE6FD, -- Math Formulas & Symbols (High-clarity Soft Ice • Zero fatigue)
  boolean           = 0xBAE6FD, -- Formula Numeric Constants

  -- ── Structural Elements, Fences, Pipes & Mermaid Geometry ─────────────────
  delimiter         = 0x222738, -- Grid Borders, Code Fences & Mermaid Node Borders
  punct_special     = 0x3E4765, -- Table Matrix Separators & Mermaid Connection Lines
  operator          = 0x7AA2F7, -- List Bullets & Operators (Azure Anchor)
  tag               = 0x38BDF8, -- WikiLinks, Tags & Cross-References

  -- ── Semantic Status Roles (Strictly Isolated from Headings) ──────────────
  func_builtin      = 0x34D399, -- [x] Checked Task / Success Callout (Emerald Mint)
  keyword           = 0xFBBF24, -- [-] Todo Task / Warning Alert (Amber Gold)
  keyword_func      = 0x60A5FA, -- Info / Note Callout (Sky Blue)
  keyword_return    = 0xF87171, -- Important / Action Required (Coral Red)
  keyword_storage   = 0x818CF8, -- Tip / Hint Callout (Iris Purple)
  exception         = 0xF43F5E, -- Blocker / Error / Bug (Vivid Crimson)
  preproc           = 0x2DD4BF, -- Environment & Frontmatter Keys (Teal)

  -- ── Subtly Tinted Background Overlays (Alpha-like, No Blocky Glare) ────────
  h1_bg             = 0x12172A, -- H1 Subtle Horizon Tint
  h2_bg             = 0x0F172A, -- H2 Subtle Horizon Tint
  h3_bg             = 0x0C1526,
  h4_bg             = 0x0D1322,
  h5_bg             = 0x0B0E1A,
  h6_bg             = 0x080A12,
}
