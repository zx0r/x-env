-- ============================================================================
-- plugins/ui-dashboard.lua — Dashboard & Workspace Launcher Domain
--
-- Responsibility:
--   • Cyberpunk Telemetry ASCII Header
--   • Workspace Dock Dynamic Filesystem Inspector ($X_ROOT / ~/x)
--   • Discrete Grid Navigation Controller (j/k/h/l/<Tab>/<CR>)
--   • Declarative Snacks Dashboard Presentation Specification
--
-- Neovim >= 0.12
-- ============================================================================

-- ── Cyberpunk Telemetry Dashboard Header ────────────────────────────────────
local function cyberpunk_header()
  return {
    {
      align = "center",
      text = {
        { "  ██╗  ██╗    ", hl = "SnacksDashboardHeader" },
        { "W O R K S P A C E                           ", hl = "SnacksDashboardTitle" },
      },
    },
    {
      align = "center",
      text = {
        { "  ╚██╗██╔╝                                                ", hl = "SnacksDashboardHeader" },
      },
    },
    {
      align = "center",
      text = {
        { "   ╚███╔╝     ", hl = "SnacksDashboardHeader" },
        { "▪ Declarative ▪ Immutable ▪ High-Performance", hl = "SnacksDashboardDesc" },
      },
    },
    {
      align = "center",
      text = {
        { "   ██╔██╗     ", hl = "SnacksDashboardHeader" },
        { "▪ Masterpiece of CLI Architecture           ", hl = "SnacksDashboardDesc" },
      },
    },
    {
      align = "center",
      text = {
        { "  ██╔╝ ██╗    ", hl = "SnacksDashboardHeader" },
        { "▪ [ Architect: zx0r ]                       ", hl = "SnacksDashboardDesc" },
      },
    },
    {
      align = "center",
      padding = 1,
      text = {
        { "  ╚═╝  ╚═╝                                                ", hl = "SnacksDashboardHeader" },
      },
    },
  }
end

-- ── Dashboard Workspace Dock & Discrete Controller ──────────────────────────
local _dashboards = {}

local function setup_discrete_controller(buf, win)
  win = win or vim.fn.bufwinid(buf)
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end

  local dash = _dashboards[buf]
  local lines = (dash and dash.lines) or vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local target_dir = os.getenv("X_ROOT") or (os.getenv("HOME") .. "/x")

  local levels = {}
  local dock_level_idx = nil

  -- 1. Identify dock rows and interactive cells
  if dash and dash.items then
    for _, it in ipairs(dash.items) do
      if it.is_dock and it._ and it._.row then
        local line = lines[it._.row] or ""
        local cells = {}
        local start = 1
        for _, d_item in ipairs(it.dock_items or {}) do
          local p1 = line:find("│", start)
          if not p1 then
            break
          end
          local p2 = line:find("│", p1 + 3)
          if not p2 then
            break
          end
          local text = line:sub(p1 + 3, p2 - 1)
          local rel = text:find("%S") or 1
          local col0 = (p1 + 3 - 1) + rel - 1
          table.insert(cells, {
            idx = #cells + 1,
            key = d_item.key,
            name = d_item.name,
            path = d_item.path or (target_dir .. "/" .. d_item.name),
            col = col0,
          })
          start = p2
        end
        if #cells > 0 then
          table.insert(levels, {
            type = "dock",
            row = it._.row,
            cells = cells,
            selected = 1,
          })
          if not dock_level_idx then
            dock_level_idx = #levels
          end
        end
      end
    end
  end

  -- Fallback if dash.items was not tagged
  if #levels == 0 then
    for r, l in ipairs(lines) do
      if l:find("│") and not l:find("[┌╭└╰├]") then
        local cells = {}
        local start = 1
        while true do
          local p1 = l:find("│", start)
          if not p1 then
            break
          end
          local p2 = l:find("│", p1 + 3)
          if not p2 then
            break
          end
          local text = l:sub(p1 + 3, p2 - 1)
          local key = text:match("%[([a-z0-9])%]")
          local name = text:match("([%w_%-]+)%s*$")
          if name then
            local rel = (key and text:find("%[" .. key .. "%]")) or text:find("%S") or 1
            local col0 = (p1 + 3 - 1) + rel - 1
            table.insert(cells, {
              idx = #cells + 1,
              key = key,
              name = name,
              col = col0,
              path = target_dir .. "/" .. name,
            })
          end
          start = p2
        end
        if #cells > 0 then
          table.insert(levels, {
            type = "dock",
            row = r,
            cells = cells,
            selected = 1,
          })
          if not dock_level_idx then
            dock_level_idx = #levels
          end
        end
      end
    end
  end

  -- 2. Identify action rows
  if dash and dash.items then
    local action_items = {}
    for _, it in ipairs(dash.items) do
      if it.action and it._ and not it.hidden and not it.is_dock then
        table.insert(action_items, it)
      end
    end
    table.sort(action_items, function(a, b)
      return a._.row < b._.row
    end)

    for _, it in ipairs(action_items) do
      local line = lines[it._.row] or ""
      local col = line:find("[%w%d%p]", (it._.col or 0) + 1) or ((it._.col or 0) + 1)
      table.insert(levels, {
        type = "action",
        row = it._.row,
        col = col - 1,
        action = it.action,
        desc = it.desc or it.key or "action",
      })
    end
  end

  if #levels == 0 then
    return
  end

  local cur_lvl_idx = dock_level_idx or 1

  local function jump_to(lvl_idx, col_override)
    cur_lvl_idx = math.max(1, math.min(#levels, lvl_idx))
    local lvl = levels[cur_lvl_idx]
    if lvl.type == "dock" then
      local c = col_override or lvl.cells[lvl.selected].col
      vim.api.nvim_win_set_cursor(win, { lvl.row, c })
    else
      vim.api.nvim_win_set_cursor(win, { lvl.row, lvl.col })
    end
  end

  -- Intercept CursorMoved: prevent floating, enforce strict discrete lock
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = vim.api.nvim_create_augroup("snacks_dashboard_cursor", { clear = true }),
    buffer = buf,
    callback = function()
      local cur = vim.api.nvim_win_get_cursor(win)
      local r, c = cur[1], cur[2]

      local matching_lvl_idx = nil
      for idx, lvl in ipairs(levels) do
        if lvl.row == r then
          matching_lvl_idx = idx
          break
        end
      end

      if matching_lvl_idx then
        cur_lvl_idx = matching_lvl_idx
        local lvl = levels[cur_lvl_idx]
        if lvl.type == "dock" then
          local best = lvl.cells[1]
          local min_d = math.abs(c - best.col)
          for _, cell in ipairs(lvl.cells) do
            local d = math.abs(c - cell.col)
            if d < min_d then
              min_d = d
              best = cell
            end
          end
          lvl.selected = best.idx
          if cur[2] ~= best.col then
            vim.api.nvim_win_set_cursor(win, { lvl.row, best.col })
          end
        else
          if cur[2] ~= lvl.col then
            vim.api.nvim_win_set_cursor(win, { lvl.row, lvl.col })
          end
        end
      else
        -- Landed off-grid (header, border, subtitle, gap, footer) -> Snap to nearest valid row
        local best_idx = 1
        local min_dist = math.abs(r - levels[1].row)
        for idx, lvl in ipairs(levels) do
          local dist = math.abs(r - lvl.row)
          if dist < min_dist then
            min_dist = dist
            best_idx = idx
          end
        end
        jump_to(best_idx)
      end
    end,
  })

  -- Vertical discrete hops: j / k / <Down> / <Up>
  local function move_v(delta)
    local next_idx = math.max(1, math.min(#levels, cur_lvl_idx + delta))
    jump_to(next_idx)
  end

  vim.keymap.set("n", "j", function()
    move_v(1)
  end, { buffer = buf, silent = true, desc = "Next Item" })
  vim.keymap.set("n", "<Down>", function()
    move_v(1)
  end, { buffer = buf, silent = true, desc = "Next Item" })
  vim.keymap.set("n", "k", function()
    move_v(-1)
  end, { buffer = buf, silent = true, desc = "Prev Item" })
  vim.keymap.set("n", "<Up>", function()
    move_v(-1)
  end, { buffer = buf, silent = true, desc = "Prev Item" })

  -- Horizontal discrete hops & locking
  local function move_h(delta, wrap)
    local lvl = levels[cur_lvl_idx]
    local hit_edge = false
    if lvl.type == "dock" then
      local n = #lvl.cells
      local new_idx
      if wrap then
        new_idx = ((lvl.selected - 1 + delta) % n) + 1
      else
        new_idx = math.max(1, math.min(n, lvl.selected + delta))
        if new_idx == lvl.selected then
          hit_edge = true
        end
      end
      lvl.selected = new_idx
      jump_to(cur_lvl_idx, lvl.cells[new_idx].col)
    else
      -- Horizontal movement locked on action rows (zero drifting)
      hit_edge = true
      jump_to(cur_lvl_idx)
    end

    if hit_edge and not wrap then
      local dir = delta > 0 and "l" or "h"
      local cur_win = vim.api.nvim_get_current_win()
      vim.cmd("wincmd " .. dir)
      if cur_win == vim.api.nvim_get_current_win() then
        local ok, ss = pcall(require, "smart-splits")
        if ok then
          if dir == "h" then
            ss.move_cursor_left()
          end
          if dir == "l" then
            ss.move_cursor_right()
          end
        end
      end
    end
  end

  vim.keymap.set("n", "L", function()
    move_h(1, false)
  end, { buffer = buf, silent = true, desc = "Next Cell" })
  vim.keymap.set("n", "<Right>", function()
    move_h(1, false)
  end, { buffer = buf, silent = true, desc = "Next Cell" })
  vim.keymap.set("n", "H", function()
    move_h(-1, false)
  end, { buffer = buf, silent = true, desc = "Prev Cell" })
  vim.keymap.set("n", "<Left>", function()
    move_h(-1, false)
  end, { buffer = buf, silent = true, desc = "Prev Cell" })

  -- Tab cycles cells on dock, moves items vertically on actions
  vim.keymap.set("n", "<Tab>", function()
    local lvl = levels[cur_lvl_idx]
    if lvl.type == "dock" then
      move_h(1, true)
    else
      move_v(1)
    end
  end, { buffer = buf, silent = true, desc = "Cycle Forward" })

  vim.keymap.set("n", "<S-Tab>", function()
    local lvl = levels[cur_lvl_idx]
    if lvl.type == "dock" then
      move_h(-1, true)
    else
      move_v(-1)
    end
  end, { buffer = buf, silent = true, desc = "Cycle Backward" })

  -- Enter execution
  vim.keymap.set("n", "<CR>", function()
    local lvl = levels[cur_lvl_idx]
    if not lvl then
      return
    end
    if lvl.type == "dock" then
      local cell = lvl.cells[lvl.selected]
      if cell then
        vim.api.nvim_set_current_dir(cell.path)
        Snacks.dashboard.pick("files", { cwd = cell.path })
        return
      end
    elseif lvl.type == "action" then
      if dash and dash.find then
        local item = dash:find(vim.api.nvim_win_get_cursor(win))
        if item and item.action then
          return dash:action(item.action)
        end
      end
      if type(lvl.action) == "function" then
        if dash then
          lvl.action(dash)
        else
          lvl.action()
        end
      elseif type(lvl.action) == "string" then
        if lvl.action:find("^:") then
          vim.cmd(lvl.action:sub(2))
        elseif dash then
          dash:action(lvl.action)
        else
          local keys = vim.api.nvim_replace_termcodes(lvl.action, true, true, true)
          vim.api.nvim_feedkeys(keys, "tm", true)
        end
      end
    end
  end, { buffer = buf, silent = true, desc = "Execute Selection" })

  -- Block stray editing keystrokes without blocking action/dock keys
  local active_keys = {}
  for _, lvl in ipairs(levels) do
    if lvl.type == "dock" then
      for _, cell in ipairs(lvl.cells) do
        if cell.key then
          active_keys[cell.key] = true
        end
      end
    end
  end
  if dash and dash.items then
    for _, it in ipairs(dash.items) do
      if it.key then
        active_keys[it.key] = true
      end
    end
  end
  local candidate_noops = {
    "i", "I", "a", "A", "o", "O", "c", "C", "s", "S",
    "r", "R", "d", "D", "x", "X", "p", "P", "u", "U",
    "~", "<", ">", "=",
  }
  for _, k in ipairs(candidate_noops) do
    if not active_keys[k:lower()] and not active_keys[k] then
      vim.keymap.set({ "n", "x" }, k, "<nop>", { buffer = buf, silent = true, nowait = true })
    end
  end

  -- Buffer cleanup
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      _dashboards[buf] = nil
    end,
  })

  -- Initial placement
  jump_to(cur_lvl_idx)
end

local function workspace_dock(self)
  if self and self.buf then
    _dashboards[self.buf] = self
  end
  local target = os.getenv("X_ROOT") or (os.getenv("HOME") .. "/x")
  local fd = vim.uv.fs_scandir(target)
  if not fd then
    return {}
  end

  local dirs = {}
  while true do
    local name, t = vim.uv.fs_scandir_next(fd)
    if not name then
      break
    end
    if t == "directory" and not name:match("^%.") then
      dirs[#dirs + 1] = name
    end
  end
  if #dirs == 0 then
    return {}
  end
  table.sort(dirs, function(a, b)
    return a:lower() < b:lower()
  end)

  local domain_meta = {
    agents = { icon = " ", hl = "SnacksDashboardIcon", key = "a" },
    brain  = { icon = " ", hl = "SnacksDashboardIcon", key = "b" },
    config = { icon = " ", hl = "SnacksDashboardIcon", key = "c" },
    dev    = { icon = " ", hl = "SnacksDashboardIcon", key = "d" },
  }

  local reserved = { f = 1, F = 1, g = 1, G = 1, n = 1, r = 1, s = 1, q = 1, l = 1, m = 1, h = 1 }
  local used, items = {}, {}
  for _, name in ipairs(dirs) do
    local meta = domain_meta[name:lower()]
    local icon_glyph = meta and meta.icon or "󰉋 "
    local icon_hl = meta and meta.hl or "SnacksDashboardIcon"
    local key = meta and meta.key
    if key and not used[key] then
      used[key] = true
    else
      key = nil
      for i = 1, #name do
        local ch = name:sub(i, i):lower()
        if ch:match("%a") and not reserved[ch] and not used[ch] then
          key = ch
          used[ch] = true
          break
        end
      end
    end
    items[#items + 1] = {
      name = name,
      path = target .. "/" .. name,
      key = key,
      icon = icon_glyph,
      hl = icon_hl,
    }
  end

  local cols, cell_w = 4, 14
  local result = {}
  for i = 1, #items, cols do
    local chunk = {}
    for j = i, math.min(i + cols - 1, #items) do
      chunk[#chunk + 1] = items[j]
    end

    -- Borders
    local bar = string.rep("─", cell_w)
    local top = (i == 1 and "╭" or "├")
      .. (bar .. ((i == 1) and "┬" or "┼")):rep(cols - 1)
      .. bar
      .. (i == 1 and "╮" or "┤")
    result[#result + 1] = { align = "center", text = { { top, hl = "SnacksDashboardDir" } } }

    -- Content
    local tokens = {}
    for ci = 1, cols do
      tokens[#tokens + 1] = { "│", hl = "SnacksDashboardDir" }
      local it = chunk[ci]
      if not it then
        tokens[#tokens + 1] = { (" "):rep(cell_w) }
      else
        local content = (it.key and (it.key .. " ") or "") .. it.icon .. it.name
        local pad = math.max(0, cell_w - vim.api.nvim_strwidth(content))
        local l = math.floor(pad / 2)
        tokens[#tokens + 1] = { (" "):rep(l) }
        if it.key then
          tokens[#tokens + 1] = { it.key .. " ", hl = "SnacksDashboardKey" }
        end
        tokens[#tokens + 1] = { it.icon, hl = it.hl }
        tokens[#tokens + 1] = { it.name, hl = "SnacksDashboardFolderName" }
        tokens[#tokens + 1] = { (" "):rep(pad - l) }
      end
    end
    tokens[#tokens + 1] = { "│", hl = "SnacksDashboardDir" }
    result[#result + 1] = {
      is_dock = true,
      dock_items = chunk,
      align = "center",
      text = tokens,
      action = function()
        local win = vim.api.nvim_get_current_win()
        local cursor = vim.api.nvim_win_get_cursor(win)
        local line = vim.api.nvim_get_current_line()
        local box_start = line:find("│")
        local rel_col = box_start and ((cursor[2] + 1) - box_start) or 0
        local cell_idx = math.floor((rel_col - 1) / (cell_w + 1)) + 1
        local picked = (cell_idx >= 1 and cell_idx <= #chunk and not chunk[cell_idx].empty) and chunk[cell_idx] or nil
        local path = picked and picked.path or target
        vim.api.nvim_set_current_dir(path)
        Snacks.dashboard.pick("files", { cwd = path })
      end,
    }

    -- Bottom border on last row
    if i + cols > #items then
      local bot = "╰" .. (bar .. "┴"):rep(cols - 1) .. bar .. "╯"
      result[#result + 1] = { align = "center", text = { { bot, hl = "SnacksDashboardDir" } }, padding = 1 }
    end
  end

  -- Hotkeys
  for _, it in ipairs(items) do
    if it.key then
      result[#result + 1] = {
        key = it.key,
        hidden = true,
        action = function()
          vim.api.nvim_set_current_dir(it.path)
          Snacks.dashboard.pick("files", { cwd = it.path })
        end,
      }
    end
  end
  return result
end

return {
  {
    "folke/snacks.nvim",
    init = function()
      vim.api.nvim_create_autocmd("User", {
        group = vim.api.nvim_create_augroup("core_dashboard_discrete", { clear = true }),
        pattern = { "SnacksDashboardOpened", "SnacksDashboardUpdatePost" },
        callback = function(ev)
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(ev.buf) then
              setup_discrete_controller(ev.buf)
            end
          end)
        end,
      })
    end,
    opts = {
      dashboard = {
        enabled = true,
        width = 66,
        preset = {
          header = table.concat({
            "  ██╗  ██╗    W O R K S P A C E                           ",
            "  ╚██╗██╔╝                                                ",
            "   ╚███╔╝     ▪ Declarative ▪ Immutable ▪ High-Performance",
            "   ██╔██╗     ▪ Masterpiece of CLI Architecture           ",
            "  ██╔╝ ██╗    ▪ [ Architect: zx0r ]                       ",
            "  ╚═╝  ╚═╝                                                ",
          }, "\n"),
          keys = {
            { icon = " ", icon_hl = "SnacksDashboardWidgetFind", key = "f", key_hl = "SnacksDashboardKey", desc = "Find File (Local)", desc_hl = "SnacksDashboardDesc", action = ":lua Snacks.picker.files()" },
            { icon = "󰱼 ", icon_hl = "SnacksDashboardWidgetFind", key = "F", key_hl = "SnacksDashboardKey", desc = "Find File (Global)", desc_hl = "SnacksDashboardDesc", action = function() Snacks.picker.files({ cwd = os.getenv("X_ROOT") or (os.getenv("HOME") .. "/x") }) end },
            { icon = " ", icon_hl = "SnacksDashboardWidgetGrep", key = "/", key_hl = "SnacksDashboardKey", desc = "Live Grep (Local)", desc_hl = "SnacksDashboardDesc", action = ":lua Snacks.picker.grep()" },
            { icon = "󰈞 ", icon_hl = "SnacksDashboardWidgetGrep", key = "G", key_hl = "SnacksDashboardKey", desc = "Live Grep (Global)", desc_hl = "SnacksDashboardDesc", action = function() Snacks.picker.grep({ cwd = os.getenv("X_ROOT") or (os.getenv("HOME") .. "/x") }) end },
            { icon = " ", icon_hl = "SnacksDashboardWidgetNew", key = "n", key_hl = "SnacksDashboardKey", desc = "New File", desc_hl = "SnacksDashboardDesc", action = ":ene | startinsert" },
            { icon = " ", icon_hl = "SnacksDashboardWidgetRecent", key = "r", key_hl = "SnacksDashboardKey", desc = "Recent Files", desc_hl = "SnacksDashboardDesc", action = ":lua Snacks.picker.recent()" },
            { icon = "󰒲 ", icon_hl = "SnacksDashboardWidgetLazy", key = "l", key_hl = "SnacksDashboardKey", desc = "Lazy", desc_hl = "SnacksDashboardDesc", action = ":Lazy" },
            { icon = " ", icon_hl = "SnacksDashboardWidgetMason", key = "m", key_hl = "SnacksDashboardKey", desc = "Mason", desc_hl = "SnacksDashboardDesc", action = ":Mason" },
            { icon = " ", icon_hl = "SnacksDashboardWidgetHealth", key = "h", key_hl = "SnacksDashboardKey", desc = "Health", desc_hl = "SnacksDashboardDesc", action = ":checkhealth" },
            {
              icon = " ",
              icon_hl = "SnacksDashboardWidgetSession",
              key = "s",
              key_hl = "SnacksDashboardKey",
              desc = "Restore Session",
              desc_hl = "SnacksDashboardDesc",
              action = function()
                local ok, p = pcall(require, "persistence")
                if ok then
                  p.load()
                end
              end,
            },
            { icon = " ", icon_hl = "SnacksDashboardWidgetQuit", key = "q", key_hl = "SnacksDashboardKey", desc = "Quit", desc_hl = "SnacksDashboardDesc", action = ":qa" },
          },
        },
        sections = {
          cyberpunk_header,
          workspace_dock,
          { section = "keys", gap = 1, padding = 1 },
          { section = "startup" },
        },
      },
    },
  },
}

