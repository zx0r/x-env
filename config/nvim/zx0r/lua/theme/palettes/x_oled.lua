-- ============================================================================
-- theme/syntax/x_oled.lua — Design Tokens (Tier 1)
-- 24-bit Integer Hex Literals • Direct Neovim C-Core Fast-Path
-- ============================================================================

return {
  builtin           = 0x00FF79,
  operator          = 0x0000CE,
  variable          = 0x31A6FF,
  delimiter         = 0x803D00,
  punct_special     = 0x803D00,
  comment           = 0x4C4C4C,
  special           = 0xF800FF,
  tag               = 0xFFFFFF,
  member            = 0x31A6FF,
  param             = 0x9799FF,
  type              = 0xFF0000,
  type_builtin      = 0xFF0000,
  type_def          = 0xFF0086,
  type_qualifier    = 0xF800FF,
  ["class"]         = 0xFF0000,
  ["function"]      = 0xFF0086,
  func_builtin      = 0x603F80,
  func_call         = 0x782EC1,
  keyword           = 0xF800FF,
  keyword_func      = 0x07FF00,
  keyword_return    = 0x07FF00,
  keyword_storage   = 0xFF0000,
  exception         = 0x07FF00,
  preproc           = 0x07FF00,
  constant          = 0x07FF00,
  const_builtin     = 0x07FF00,
  number            = 0xC6FF00,
  boolean           = 0x07FF00,
  string            = 0xFFF800,
  string_doc        = 0x4C4C4C,
  regexp            = 0xFFF800,
  escape            = 0xFF00AA,
}
