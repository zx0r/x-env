-- NOTE:-------------------------------------------------------
--   ██╗  ██╗    W O R K S T A T I O N
--   ╚██╗██╔╝
--    ╚███╔╝     SYSTEMS OVER SCRIPTS
--    ██╔██╗     INTENT OVER DRIFT
--   ██╔╝ ██╗    AUTOMATION WITH CONTROL
--   ╚═╝  ╚═╝
-- init.lua — Yazi Runtime & Statusline Telemetry
-- Architecture:
--   • Total Transparency Architecture (bg = NONE / reset)
--   • Exact Synchronicity with Neovim lualine (ui-status.lua & master.lua)
--   • High-Performance Yazi v26 Native Component Overrides
-- Layout Domain Mapping:
--   lualine_a (mode)      → Status:mode() [󰘳 NORMAL / 󰈈 SELECT / 󰘳 UNSET]
--   lualine_c (filename)  → Status:name() [cornsilk #FFF8DC, symlink text_3]
--   lualine_y (encoding)  → Status:perm() [size in text_2 + per-char perms]
--   lualine_z (location)  → Status:position() [cyan bold 1/24]
--   lualine_y (progress)  → Status:percent() [purple 42%]
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. PALETTE CONSTANTS (master.lua Dark Tier Reference)
-- ═══════════════════════════════════════════════════════════════════════════════

local C = {
  cyan = "#00BFC7", -- soft teal (master.lua cyan_dim)
  mint = "#00FF88", -- electric mint (selection / visual select mode)
  crimson = "#FF3366", -- crimson red (cut / delete operations)
  blue = "#0A84FF", -- accent / NORMAL mode / location / directories (master.lua blue)
  magenta = "#CD00F7", -- keyword / SELECT mode / write perm (LualineVisualA)
  purple = "#A855F7", -- type / UNSET mode / progress (LualineProgress)
  pink = "#F40091", -- function / emphasis / lsp indicator
  green = "#00FF00", -- bright neon green / exec perm / yanked state
  yellow = "#FFFF00", -- warn / number / read perm / selection state
  red = "#FF0000", -- error / delete / replace perm (LualineReplaceA)
  orange = "#FF8C00", -- hint / constant / tools
  fg_alt = "#FFF8DC", -- cornsilk / filename (LualineFilename)
  text_1 = "#BCC4DD", -- primary text / header path
  text_2 = "#97A0BC", -- muted text / encoding / size (LualineEncoding)
  text_3 = "#646B84", -- comment / dim info / symlink target
  text_4 = "#4A5168", -- faint / inactive permissions
  border_dim = "#5D6480", -- visible elevated border hairline (master.lua indent/border tier)
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. PLUGIN INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════════

local full_border_ok, full_border = pcall(require, "full-border")
if full_border_ok and full_border and full_border.setup then
  full_border:setup {
    type = ui.Border.ROUNDED,
  }
end

local git_ok, git = pcall(require, "git")
if git_ok and git and git.setup then git:setup() end

-- Mermaid renderer: configured for high-res Retina local mmdc rendering
local mermaid_ok, mermaid = pcall(require, "mermaid")
if mermaid_ok and mermaid and mermaid.setup then
  mermaid:setup {
    backend = "mmdc",
    format = "png",
    timeout = 10,
  }
end

local mime_ok, mime = pcall(require, "mime-ext")
if mime_ok and mime and mime.setup then mime:setup() end

-- LaTeX renderer: tectonic → PDF → pdftoppm → PNG (Adaptive DPI)
local latex_ok, latex = pcall(require, "latex")
if latex_ok and latex and latex.setup then latex:setup {
  timeout = 15,
  dpi = "auto",
} end

-- Markdown renderer: glow with atomic disk cache
local md_ok, md = pcall(require, "markdown")
if md_ok and md and md.setup then md:setup {
  style = "dark",
  timeout = 15,
} end

-- Fast Ripgrep & FD Search Engine: frank.yazi with Bat preview
local frank_ok, frank = pcall(require, "frank")
if frank_ok and frank and frank.setup then frank:setup {
  bat = "--style=numbers --theme=x",
} end

-- macOS Native Finder Tags: mactag.yazi
local mactag_ok, mactag = pcall(require, "mactag")
if mactag_ok and mactag and mactag.setup then
  mactag:setup {
    keys = {
      r = "Red",
      o = "Orange",
      y = "Yellow",
      g = "Green",
      b = "Blue",
      p = "Purple",
    },
    colors = {
      Red = "#ee7b70",
      Orange = "#f5bd5c",
      Yellow = "#fbe764",
      Green = "#91fc87",
      Blue = "#5fa3f8",
      Purple = "#cb88f8",
    },
    order = 500,
  }
end

-- Fast Disk Usage Analyzer: what-size.yazi
local what_size_ok, what_size = pcall(require, "what-size")
if what_size_ok and what_size and what_size.setup then
  what_size:setup {
    priority = 400,
    LEFT = "",
    RIGHT = " ",
  }
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. HEADER — Clean Transparent CWD
-- ═══════════════════════════════════════════════════════════════════════════════

--- Check whether a file or directory metadata denotes read-only / write-protected / root ownership
---@param cha table|nil
---@return boolean
local function is_protected(cha)
  if not cha then return false end
  if cha.uid == 0 then return true end
  local ok, perm = pcall(function() return cha:perm() end)
  if ok and perm then
    if #perm >= 10 and perm:sub(3, 3) == "-" then
      return true
    elseif #perm == 9 and perm:sub(2, 2) == "-" then
      return true
    end
  end
  return false
end

--- Check whether the current working directory itself is read-only or protected
---@param cwd any
---@return boolean
local function is_dir_protected(cwd)
  if not cwd then return false end
  local s = tostring(cwd)
  if s == "/" or s:match("^/etc") or s:match("^/private") or s:match("^/System") or s:match("^/usr") or s:match("^/bin") or s:match("^/sbin") or s:match("^/var") or s:match("^/opt") then
    return true
  end
  local parent = cx.active.parent
  if parent and parent.files then
    for _, f in ipairs(parent.files) do
      if tostring(f.url) == s then
        return is_protected(f.cha)
      end
    end
  end
  if parent and parent.hovered and tostring(parent.hovered.url) == s then
    return is_protected(parent.hovered.cha)
  end
  return false
end

function Header:cwd()
  local cwd = cx.active.current.cwd
  if not cwd then return ui.Span("") end
  local spans = {
    ui.Span("󰄾 "):style(ui.Style():fg(C.cyan):bold()),
    ui.Span(tostring(cwd)):style(ui.Style():fg(C.text_1):bold()),
  }

  if is_dir_protected(cwd) then
    spans[#spans + 1] = ui.Span("   "):style(ui.Style():fg(C.red):bold())
  end

  return ui.Line(spans)
end

-- Notify when navigating into read-only or protected directories
ps.sub("cd", function()
  local cwd = cx.active.current.cwd
  if is_dir_protected(cwd) then
    ya.notify {
      title = "Read-Only Directory",
      content = "Directory write-protected. Mutations prohibited.",
      level = "warn",
      timeout = 3,
    }
  end
end)

-- Suppress default raw count in header (eliminates duplicate number in front of telemetry)
function Header:count() return ui.Line {} end

-- [Header Operation Telemetry] Transparent top bar status badge (Header.RIGHT)
Header:children_add(function()
  local spans = {}

  -- 1. Selected count (Bright Yellow, 100% transparent background)
  local selected = 0
  if cx.active and cx.active.selected then
    for _ in pairs(cx.active.selected) do
      selected = selected + 1
    end
  end
  if selected > 0 then
    spans[#spans + 1] = ui.Span(string.format("󰄲 %d SELECTED", selected))
      :style(ui.Style():fg(C.yellow):bold())
  end

  -- 2. Yanked / Cut count (Bright Neon Green / Red, 100% transparent background)
  local yanked = (cx.yanked and #cx.yanked) or 0
  if yanked > 0 then
    if #spans > 0 then spans[#spans + 1] = ui.Span("  ") end
    if cx.yanked.is_cut then
      spans[#spans + 1] = ui.Span(string.format("󰆐 %d CUT", yanked))
        :style(ui.Style():fg(C.red):bold())
    else
      spans[#spans + 1] = ui.Span(string.format("󰆏 %d YANKED", yanked))
        :style(ui.Style():fg(C.green):bold())
    end
  end

  if #spans == 0 then return ui.Line {} end

  spans[#spans + 1] = ui.Span(" ")
  return ui.Line(spans)
end, 1000, Header.RIGHT)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. LINEMODE (Lock Placed Snug to Left of File Size)
-- ═══════════════════════════════════════════════════════════════════════════════
function Linemode:size()
  local size = self._file:size()
  local s
  if size then
    s = ya.readable_size(size)
  else
    local folder = cx.active:history(self._file.url)
    s = folder and tostring(#folder.files) or ""
  end

  if is_protected(self._file.cha) then
    return {
      ui.Span(" "):style(ui.Style():fg(C.red):bold()),
      ui.Span(s),
    }
  end

  return ui.Span(s)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. STATUSLINE (Mode & Devicon Filename on Left, Metadata & Size on Right)
-- ═══════════════════════════════════════════════════════════════════════════════

function Status:mode()
  local mode = self._tab.mode
  local style = self:style()
  local icon, name

  if mode.is_select then
    icon, name = "󰈈", "SELECT"
  elseif mode.is_unset then
    icon, name = "󰘳", "UNSET"
  else
    icon, name = "󰘳", "NORMAL"
  end

  return ui.Line {
    ui.Span(string.format(" %s %s ", icon, name)):style(style.main),
    ui.Span(" "),
  }
end

-- Suppress file size on the left
function Status:length() return ui.Line {} end

-- Neovim/lualine-style filename with devicon and symlink target
function Status:name()
  local h = cx.active.current.hovered
  if not h then return ui.Line {} end

  local icon = th.icon:match(h)
  local spans = {}

  if icon then spans[#spans + 1] = ui.Span(icon.text):style(icon.style) end

  spans[#spans + 1] = ui.Span(h.name):style(ui.Style():fg(C.fg_alt):bold())

  if is_protected(h.cha) then
    spans[#spans + 1] = ui.Span("   "):style(ui.Style():fg(C.red):bold())
  end

  if h.link_to then
    spans[#spans + 1] = ui.Span(" -> " .. tostring(h.link_to))
      :style(ui.Style():fg(C.text_3):italic())
  end

  return ui.Line(spans)
end

-- Right side: file ownership (uid:gid) placed before size
Status:children_add(function()
  local h = cx.active.current.hovered
  if not h or ya.target_family() ~= "unix" then return ui.Line {} end

  local uid = ya.user_name(h.cha.uid) or tostring(h.cha.uid)
  local gid = ya.group_name(h.cha.gid) or tostring(h.cha.gid)

  return ui.Line {
    ui.Span(uid):style(ui.Style():fg(C.purple)),
    ui.Span(":"):style(ui.Style():fg(C.text_3)),
    ui.Span(gid):style(ui.Style():fg(C.purple)),
    ui.Span("  "),
  }
end, 600, Status.RIGHT)

-- Right side: file size metadata placed before permissions
Status:children_add(function()
  local h = cx.active.current.hovered
  if not h then return ui.Line {} end

  local size = h:size()
  if not size then return ui.Line {} end

  return ui.Line {
    ui.Span(ya.readable_size(size) .. "  "):style(ui.Style():fg(C.text_2)),
  }
end, 500, Status.RIGHT)
