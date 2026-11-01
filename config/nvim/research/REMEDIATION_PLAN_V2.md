# REMEDIATION PLAN v2 — Post-Refactoring Stabilization

**Дата:** 2026-10-01
**Scope:** Zero-overhead hardening, anti-pattern elimination, ownership deconfliction
**Baseline:** 12.5ms cold start (headless). All P0–P7 from v1 completed.
**Target:** ≤ 12ms cold, 0 anti-patterns, 0 duplicate ownership, 0 arch violations
**Method:** 4-agent parallel audit (core, language/LSP, navigation/workspace, UI) + cross-domain scan

---

## EXECUTIVE SUMMARY

The v1 remediation achieved structural alignment (23 domains, flat composition, correct naming).
This audit reveals **28 remaining defects** across 6 categories:

| Category            | CRITICAL | HIGH | MEDIUM | LOW | Total |
|---------------------|----------|------|--------|-----|-------|
| CONFIG_ERROR        | 2        | 2    | 2      | 1   | 7     |
| ARCH_VIOLATION      | —        | 3    | 1      | —   | 4     |
| ANTIPATTERN         | —        | 3    | 1      | —   | 4     |
| PERF / ZERO_OVERHEAD| 1        | 2    | 3      | 1   | 7     |
| DUPLICATE           | —        | 1    | 2      | 1   | 4     |
| OWNERSHIP_CONFLICT  | —        | 1    | 1      | —   | 2     |

---

## PHASE 0 — CRITICAL DEFECTS (blocks correctness)

### C-01 · `diagnostics.lua` — Top-level execution during spec phase
> **Severity:** CRITICAL · **Category:** ARCH_VIOLATION / ZERO_OVERHEAD

[diagnostics.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/diagnostics.lua#L11-L40)

**Problem:** `vim.diagnostic.config()` is called at module root, outside any plugin `config`
function. lazy.nvim executes this code during filesystem traversal to build its spec cache.
This pollutes global state before any plugin has loaded and adds unnecessary work to the
startup critical path.

**Fix:** Wrap in a virtual plugin spec:
```lua
return {
  {
    "x0r/diagnostics-policy",
    virtual = true,
    event = "VeryLazy",
    config = function()
      vim.diagnostic.config({ ... })
    end,
  },
}
```

**Validation:** `nvim --startuptime /tmp/s.log '+qa'` — no diagnostic config in early phase.

---

### C-02 · `language.lua:226` — LSP server config directory mismatch
> **Severity:** CRITICAL · **Category:** CONFIG_ERROR

[language.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/language.lua#L226)

**Problem:** Comment says server settings belong in `~/.config/nvim/after/lsp/*.lua`, but
actual files are at `~/.config/nvim/lsp/*.lua` (no `after/` prefix). For Neovim ≥ 0.12
with `vim.lsp.config()` + `vim.lsp.enable()`, server configs go in `lsp/` (not `after/lsp/`).
The comment is misleading but the file placement is **correct**.

**Fix:** Update the comment to match reality:
```lua
-- They belong in ~/.config/nvim/lsp/*.lua (Neovim >= 0.12 native LSP config)
```

**Validation:** `:lua print(vim.lsp.config('lua_ls'))` returns expected settings.

---

## PHASE 1 — HIGH-SEVERITY PERFORMANCE

### H-01 · `ui-status.lua:423-440` — 60fps statusline refresh with CursorMoved binding
> **Severity:** HIGH · **Category:** PERF

[ui-status.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui-status.lua#L423-L440)

**Problem:** `refresh_time = 16` (60fps) combined with `CursorMoved` and `CursorMovedI`
events. Every cursor movement triggers a full statusline re-render. This causes measurable
main-thread overhead during typing and navigation — the two most latency-sensitive operations.

**Fix:**
```lua
refresh = {
  statusline = 200,      -- 5fps — sufficient for mode/diagnostics/branch
  tabline = 1000,
  winbar = 1000,
  -- REMOVE refresh_time entirely (deprecated in recent lualine)
  events = {
    "WinEnter",
    "BufEnter",
    "BufWritePost",
    "SessionLoadPost",
    "FileChangedShellPost",
    "VimResized",
    "ModeChanged",         -- keep: mode indicator needs this
    -- REMOVE: CursorMoved, CursorMovedI, Filetype
  },
},
```

**Validation:** Type rapidly in a large file — no visible jank. `:Snacks profiler` shows
no lualine in top-10 hot functions.

---

### H-02 · `syntax.lua:38` — Treesitter `lazy = false` with sync parser check
> **Severity:** HIGH · **Category:** ZERO_OVERHEAD

[syntax.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/syntax.lua#L38)
[syntax.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/syntax.lua#L158-L169)

**Problem:** `nvim-treesitter` is set to `lazy = false`, which loads it during startup.
The `config` function iterates ~40 languages calling `nvim_get_runtime_file` synchronously —
an I/O-intensive operation on the main thread during every cold start.

**Fix:**
```lua
lazy = false,  -- KEEP: treesitter must be available for highlight/indent before BufRead
-- But wrap parser check in vim.schedule:
config = function(opts)
  -- ... setup ...
  vim.schedule(function()
    local missing = {}
    for _, lang in ipairs(opts.ensure_installed or {}) do
      if #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".*", false) == 0 then
        missing[#missing + 1] = lang
      end
    end
    if #missing > 0 then
      require("nvim-treesitter").install(missing)
    end
  end)
end,
```

**Validation:** `nvim --startuptime` — treesitter config time drops by ~1ms.

---

### H-03 · `core/keymaps.lua:47-57` — Core → plugin coupling via `require("smart-splits")`
> **Severity:** HIGH · **Category:** ARCH_VIOLATION

[keymaps.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/keymaps.lua#L47-L57)

**Problem:** Core keymaps directly `pcall(require, "smart-splits")`. Core must never
reference plugins. This creates an implicit dependency that violates the domain boundary.

**Fix:** Remove the smart-splits fallback from `core/keymaps.lua`. Move the unified
navigation logic to `terminal.lua` (which owns smart-splits), overriding the default
wincmd mappings there:
```lua
-- In lua/plugins/terminal.lua, inside smart-splits keys:
keys = {
  { "<C-h>", function() require("smart-splits").move_cursor_left() end, desc = "Focus left" },
  { "<C-j>", function() require("smart-splits").move_cursor_down() end, desc = "Focus down" },
  -- ... etc
},
```

Core keymaps should keep only the basic `<C-w>h/j/k/l` fallback.

**Validation:** `:verbose nmap <C-h>` — owned by smart-splits plugin, not core.

---

## PHASE 2 — ANTI-PATTERN ELIMINATION

### A-01 · `core/keymaps.lua:94` — Private API `require("vim._comment")`
> **Severity:** HIGH · **Category:** ANTIPATTERN

[keymaps.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/keymaps.lua#L94-L95)

**Problem:** Uses `require("vim._comment").toggle_lines()` — an underscore-prefixed
internal Neovim module with no stability guarantee. Can break on any Neovim update.

**Fix:** Use the native `gc` operator available since Neovim 0.10:
```lua
map("n", "<leader>/", "gcc", { desc = "Toggle comment line", remap = true })
map("v", "<leader>/", "gc",  { desc = "Toggle comment block", remap = true })
```

**Validation:** `<leader>/` toggles comments. `:lua print(require("vim._comment"))` — not called.

---

### A-02 · `core/lib/health.lua:159` — Core health check couples to mcphub plugin
> **Severity:** HIGH · **Category:** ARCH_VIOLATION

[health.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/lib/health.lua#L159-L177)

**Problem:** Core health module directly `require("mcphub")`. Core must not import plugins.

**Fix:** Remove the MCP section from core health. mcphub should register its own
`:checkhealth mcphub` provider. If custom health integration is needed, use a pattern-match:
```lua
-- Remove lines 156-180 entirely.
-- MCP health belongs in ai.lua or mcphub's own health provider.
```

**Validation:** `:checkhealth core` — no mcphub references.

---

### A-03 · `ai.lua:188-191` — Blocking `vim.system():wait()` in prompt generator
> **Severity:** HIGH · **Category:** ANTIPATTERN

[ai.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ai.lua#L188-L191)

**Problem:** `vim.system({"git", "diff", "--cached"}):wait()` blocks the main UI thread
synchronously. On large repos with substantial staged changes, this freezes the editor.

**Fix:** Use async pattern or pre-fetch:
```lua
content = function(context, callback)
  vim.system(
    { "git", "diff", "--cached" },
    { text = true },
    function(result)
      local diff = (result.stdout or ""):gsub("%s+$", "")
      vim.schedule(function()
        callback(string.format(
          "Write a conventional commit message for:\n```diff\n%s\n```",
          diff
        ))
      end)
    end
  )
end,
```
If CodeCompanion requires synchronous return, gate the command with a size check:
`vim.system({"git", "diff", "--cached", "--stat"}):wait()` first to verify diff is < 10KB.

**Validation:** Stage a 1MB diff → trigger commit prompt → no UI freeze.

---

### A-04 · `quality.lua:245` — Sync `fs_stat` for linter selection at config-time
> **Severity:** MEDIUM · **Category:** ANTIPATTERN

[quality.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/quality.lua#L245)

**Problem:** `vim.uv.fs_stat("selene.toml")` resolves against CWD at config-time.
If Neovim starts in a directory without `selene.toml`, Lua files in projects that
DO have it will get `luacheck` instead of `selene`. Global decision from local context.

**Fix:** Use dynamic per-buffer resolution:
```lua
lua = function()
  local buf_dir = vim.fn.expand("%:p:h")
  local selene = vim.fs.find("selene.toml", { upward = true, path = buf_dir })[1]
  return selene and { "selene" } or { "luacheck" }
end,
```

**Validation:** Open Lua file in selene project → `:lua print(vim.inspect(require("lint").linters_by_ft.lua))` → `{"selene"}`.

---

## PHASE 3 — DUPLICATE OWNERSHIP

### D-01 · `explorer.lua` — `set_edgy_hl()` duplicated across edgy + yazi init blocks
> **Severity:** HIGH · **Category:** DUPLICATE

[explorer.lua L187-209](file:///Users/x0r/.config/nvim/x0r/lua/plugins/explorer.lua#L187-L209)
[explorer.lua L294-316](file:///Users/x0r/.config/nvim/x0r/lua/plugins/explorer.lua#L294-L316)

**Problem:** Identical `set_edgy_hl()` function defined twice. Two `ColorScheme` autocmds
registered without augroup, both setting the same highlights. Double execution on every
colorscheme change.

**Fix:** Extract to a single location — the `edgy.nvim` `init` block owns Edgy highlights.
Remove the duplicate from yazi's `init`:
```lua
-- yazi.nvim init: REMOVE set_edgy_hl entirely
-- edgy.nvim init: KEEP, but add augroup with clear = true
init = function()
  local function set_edgy_hl() ... end
  local grp = vim.api.nvim_create_augroup("x0r_edgy_hl", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = grp, callback = set_edgy_hl })
  set_edgy_hl()
end,
```

**Validation:** `vim.api.nvim_get_autocmds({ event = "ColorScheme" })` — single Edgy HL entry.

---

### D-02 · `navigation.lua:224-230` — Duplicate picker keybindings
> **Severity:** LOW · **Category:** DUPLICATE

[navigation.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/navigation.lua#L224-L230)

**Problem:** `buffers` mapped to both `<leader>,` and `<leader>fb`. `grep` mapped to both
`<leader>/` and `<leader>sg`. `files` mapped to both `<leader><space>` and `<leader>ff`.
Not a bug, but duplicates keymap real estate and makes `:verbose nmap` noisy.

**Fix:** Decision required — keep either the short aliases OR the grouped `<leader>f*`/`<leader>s*`
variants. Recommendation: keep both intentionally as convenience aliases, but document
the mapping policy in a comment.

**Validation:** Intentional — no action unless user prefers consolidation.

---

### D-03 · `explorer.lua` — Three file explorers with overlapping scope
> **Severity:** MEDIUM · **Category:** OWNERSHIP_CONFLICT

[explorer.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/explorer.lua)

**Problem:** neo-tree (sidebar), oil.nvim (edit-style), and yazi (terminal FM) are all
active. Neo-tree's `<leader>be` (buffer source) overlaps Snacks picker `<leader>fb`.
Neo-tree's `<leader>ge` (git status) overlaps Diffview/Gitsigns.

**Fix:** This is an intentional multi-tool design. But clarify ownership boundaries:
```
neo-tree    → sidebar tree navigation (<leader>e)
oil.nvim    → inline directory editing (-)
yazi        → terminal file manager (<leader>-)
```
Remove neo-tree's buffer source (`<leader>be`) — Snacks picker owns buffer listing.
Remove neo-tree's git_status source (`<leader>ge`) — vcs.lua owns git status views.

**Validation:** `:verbose nmap <leader>be` — not mapped. `:verbose nmap <leader>ge` — not mapped.

---

## PHASE 4 — ZERO OVERHEAD HARDENING

### Z-01 · `init.lua:74-77` — `bench.setup()` called but doesn't exist
> **Severity:** MEDIUM · **Category:** CONFIG_ERROR

[init.lua](file:///Users/x0r/.config/nvim/x0r/init.lua#L74-L77)

**Problem:** The UIEnter deferred block calls `bench.setup()` via pcall, which silently
fails because `bench.lua` has no `setup` function. Dead code that adds a require + pcall
to the post-startup path.

**Fix:** Either:
- Remove the call entirely (bench is a manual tool)
- OR implement `M.setup()` in bench.lua if initialization is needed

```lua
-- Simplified:
vim.api.nvim_create_autocmd("UIEnter", {
  group = deferred,
  once = true,
  callback = function()
    -- Bench is on-demand via :CoreBench* commands. No setup needed.
  end,
})
```

If the entire autocmd body is empty, remove it.

**Validation:** No error in `:messages` after startup.

---

### Z-02 · `core/lib/telemetry.lua:35` — 100ms polling timer on main thread
> **Severity:** MEDIUM · **Category:** ZERO_OVERHEAD

[telemetry.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/lib/telemetry.lua#L35-L43)

**Problem:** Even though telemetry is opt-in (`:CoreTelemetryStart`), once started it runs
a 100ms repeating timer that schedules work to the main thread. This adds GC pressure and
contributes ~0.1ms per tick of scheduling overhead.

**Fix:** Increase interval to 500ms (still catches >500ms freezes, which are the only
ones users notice). Or switch to passive observation via `SafeState`:
```lua
-- Replace timer with SafeState event (fires when Neovim is idle):
vim.api.nvim_create_autocmd("SafeState", {
  group = group,
  callback = function()
    local now = vim.uv.hrtime()
    -- Process lag detection here
  end,
})
```

**Validation:** `:CoreTelemetryStart` → `vim.uv.walk(function(h) print(h:get_type()) end)` — no timer.

---

### Z-03 · `ui-discovery.lua:24` — WhichKey loaded on UIEnter
> **Severity:** MEDIUM · **Category:** ZERO_OVERHEAD

[ui-discovery.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui-discovery.lua#L24)

**Problem:** `event = "UIEnter"` loads which-key before the user has pressed any key.
Adds ~2-4ms to first-paint latency.

**Fix:**
```lua
event = "VeryLazy",
```

**Validation:** `:Lazy profile` — which-key no longer in early-load group.

---

### Z-04 · `coding.lua:400` — `guess-indent.nvim` loaded on BufReadPre
> **Severity:** LOW · **Category:** ZERO_OVERHEAD

[coding.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/coding.lua#L400-L402)

**Problem:** `BufReadPre` fires before the buffer content is visible. Indent detection
only needs content, not pre-content. Loading here adds work to the render critical path.

**Fix:**
```lua
event = { "BufReadPost", "BufNewFile" },
```

**Validation:** Open file — indent still detected. No visible delay.

---

## PHASE 5 — GLOBALS & STATE HYGIENE

### G-01 · `ui.lua:190-192` — `_G.dd` and `_G.bt` debug globals
> **Severity:** LOW · **Category:** ANTIPATTERN

[ui.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui.lua#L190-L192)

**Problem:** Pollutes global namespace with debug functions. Also overwrites `vim.print`.

**Fix:** Acceptable for development, but guard with a flag:
```lua
if vim.env.NVIM_DEBUG then
  _G.dd = function(...) Snacks.debug.inspect(...) end
  _G.bt = function() Snacks.debug.backtrace() end
  vim.print = _G.dd
end
```

**Validation:** Normal startup → `_G.dd == nil`. With `NVIM_DEBUG=1` → `_G.dd` available.

---

### G-02 · `ui-dashboard.lua:43-44` — `_G._x0r_dashboards` mutable global state
> **Severity:** MEDIUM · **Category:** ANTIPATTERN

[ui-dashboard.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui-dashboard.lua#L43-L44)

**Problem:** Dashboard instances stored in `_G._x0r_dashboards`. Module-scoped local
would be cleaner.

**Fix:**
```lua
-- At module scope (top of the returned table's config function):
local dashboards = {}
-- Replace all _G._x0r_dashboards with dashboards
```

**Validation:** `:lua print(_G._x0r_dashboards)` → `nil`.

---

## PHASE 6 — CONFIGURATION CORRECTNESS

### F-01 · `navigation.lua:171-183` — Harpoon 2 with Harpoon 1 API opts
> **Severity:** HIGH · **Category:** CONFIG_ERROR

[navigation.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/navigation.lua#L171-L183)

**Problem:** Plugin uses `branch = "harpoon2"` but `opts` uses `global_settings = { ... }`,
which is the Harpoon 1 API. Harpoon 2 uses `settings = { ... }`. The config is silently
ignored.

**Fix:**
```lua
opts = {
  settings = {
    save_on_toggle = true,
    save_on_change = true,
  },
  default = {
    display = function(list_item)
      return vim.fn.fnamemodify(list_item.value, ":.")
    end,
  },
},
```

Remove `excluded_filetypes` (not a Harpoon 2 concept) and `enter_on_sendcmd` / `tmux_autoclose_windows`.

**Validation:** `:lua print(vim.inspect(require("harpoon").config.settings))` — shows expected values.

---

### F-02 · `debugging.lua:267-269` — Python DAP `pythonPath` boolean coercion
> **Severity:** HIGH · **Category:** CONFIG_ERROR

[debugging.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/debugging.lua#L267-L269)

**Problem:** `vim.fn.exepath("python3") ~= "" and vim.fn.exepath("python3") or "python"` —
looks correct at first glance, but calls `exepath` twice (minor perf issue). Actually this
IS correct in Lua because `vim.fn.exepath("python3")` returns a string (truthy), not a
boolean. The `~= ""` produces a boolean, but the `and` then returns the second operand
(the string) when the boolean is true. **False alarm from auditor — logic is correct.**

**Fix:** Still optimize to avoid double syscall:
```lua
pythonPath = function()
  local conda = vim.env.CONDA_PREFIX
  if conda then return conda .. "/bin/python" end
  local py3 = vim.fn.exepath("python3")
  return py3 ~= "" and py3 or "python"
end,
```

**Validation:** DAP Python launches with correct interpreter.

---

### F-03 · `authoring.lua:52-58` — ColorScheme autocmd without augroup
> **Severity:** MEDIUM · **Category:** CONFIG_ERROR

[authoring.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/authoring.lua#L52-L58)

**Problem:** `render-markdown.nvim`'s ColorScheme autocmd has no augroup with `clear = true`.
Sourcing the config multiple times (`:Lazy reload`) spawns duplicate autocmds.

**Fix:**
```lua
local grp = vim.api.nvim_create_augroup("x0r_render_markdown_hl", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = grp,
  callback = function() ... end,
})
```

**Validation:** `:Lazy reload render-markdown.nvim` × 3 → single autocmd in `:au ColorScheme`.

---

### F-04 · `core/options.lua:90` — Documented foldexpr defer that doesn't exist
> **Severity:** LOW · **Category:** CONFIG_ERROR

[options.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/options.lua#L90)

**Problem:** Comment says `foldexpr` is deferred to `UIEnter` in `autocmds.lua`, but no
such autocmd exists.

**Fix:** Either implement the deferred foldexpr setup or update the comment to reflect
that Treesitter handles foldexpr via its own config.

**Validation:** Comment matches implementation.

---

## PHASE 7 — ARCHITECTURE REFINEMENTS

### R-01 · `core/lib/secops.lua:33-50` — Sync buffer scan blocks main thread
> **Severity:** MEDIUM · **Category:** PERF

[secops.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/lib/secops.lua#L33-L50)

**Problem:** `scan_buffer` reads all lines synchronously and iterates with pattern matching.
For buffers > 10K lines, this noticeably blocks the UI. The function is only called via
`:SecOpsScan` command, but the user expects it to be instant.

**Fix:** Chunk the scan across `vim.schedule` iterations:
```lua
function M.scan_buffer(buf, callback)
  buf = buf or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local findings = {}
  local chunk_size = 1000
  local i = 1

  local function process_chunk()
    local limit = math.min(i + chunk_size - 1, #lines)
    for lnum = i, limit do
      for _, p in ipairs(patterns) do
        local col = lines[lnum]:find(p.pat)
        if col then
          findings[#findings + 1] = { lnum = lnum, col = col, pattern_name = p.name }
        end
      end
    end
    i = limit + 1
    if i <= #lines then
      vim.schedule(process_chunk)
    else
      callback(findings)
    end
  end
  process_chunk()
end
```

**Validation:** Open 50K-line file → `:SecOpsScan` → no freeze.

---

### R-02 · `workspace.lua:97` — Global `cd` on BufEnter
> **Severity:** CRITICAL · **Category:** ANTIPATTERN

[workspace.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/workspace.lua#L97)

**Problem:** `vim.cmd("cd " .. root)` changes the **global** CWD every time a buffer
is entered. This breaks:
- Background LSP processes expecting stable CWD
- Terminal buffers with relative paths
- Async formatters/linters running in the background
- Any plugin that cached CWD at startup

**Fix:** Use tab-local directory:
```lua
vim.cmd("tcd " .. vim.fn.fnameescape(root))
```

Or better, use window-local:
```lua
vim.cmd("lcd " .. vim.fn.fnameescape(root))
```

**Validation:** Open files from different projects in splits → each window's `:pwd`
shows its own project root. Background tasks unaffected.

---

### R-03 · `ui.lua:223-225` — `package.preload` mock for nvim-web-devicons
> **Severity:** LOW · **Category:** ANTIPATTERN

[ui.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui.lua#L223-L225)

**Problem:** Monkey-patches `package.preload["nvim-web-devicons"]` to redirect to
`mini.icons`. This is the standard `mini.icons` integration pattern documented upstream.
**Acceptable — no action needed.**

**Validation:** N/A.

---

### R-04 · `core/lazy.lua:55-73` — Bootstrap animation timer on startup
> **Severity:** LOW · **Category:** ZERO_OVERHEAD

[lazy.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/lazy.lua#L55-L73)

**Problem:** 80ms repeating timer during bootstrap creates animation. Only runs during
first-ever bootstrap (not normal startups). Acceptable tradeoff for UX.

**Fix:** No action — runs only once during initial setup.

**Validation:** N/A (bootstrap-only path).

---

### R-05 · `core/lazy.lua:101` — Bootstrap uses `_G.Snacks.notify`
> **Severity:** LOW · **Category:** ARCH_VIOLATION

[lazy.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/lazy.lua#L101)

**Problem:** Core bootstrap references `_G.Snacks`. Only executes during first bootstrap,
when Snacks will have just been installed. Edge case but technically a coupling violation.

**Fix:** Replace with `vim.notify()`:
```lua
vim.notify("Установка ядра завершена!\nЗапустите :MasonToolsInstall", vim.log.levels.INFO)
```

**Validation:** Fresh bootstrap → notification appears.

---

## PHASE 8 — ftplugin CORRECTNESS

### FT-01 · `after/ftplugin/python.lua:29-38` — Dead code for `.dvc` filetype
> **Severity:** LOW · **Category:** CONFIG_ERROR

[python.lua](file:///Users/x0r/.config/nvim/x0r/after/ftplugin/python.lua#L29-L38)

**Problem:** Checks if filename ends in `.dvc` and changes filetype to `yaml`. But this
ftplugin only runs for Python-detected files. A `.dvc` file won't be detected as Python.

**Fix:** Move to `ftdetect/dvc.lua`:
```lua
vim.filetype.add({ extension = { dvc = "yaml" } })
```

Remove the dead code from `python.lua`.

**Validation:** Open `file.dvc` → `:set ft?` → `yaml`.

---

### FT-02 · `after/ftplugin/python.lua:10-25` — Sync venv detection on every BufEnter
> **Severity:** MEDIUM · **Category:** PERF

[python.lua](file:///Users/x0r/.config/nvim/x0r/after/ftplugin/python.lua#L10-L25)

**Problem:** `detect_venv()` performs multiple `vim.uv.fs_stat()` calls on every Python
file open.

**Fix:** Cache per project root:
```lua
local venv_cache = {}
local function detect_venv()
  local root = vim.fs.root(0, { "pyproject.toml", ".git" }) or vim.fn.getcwd()
  if venv_cache[root] ~= nil then
    vim.env.VIRTUAL_ENV = venv_cache[root] or nil
    return
  end
  -- ... existing detection logic ...
  venv_cache[root] = result or false
end
```

**Validation:** Open 10 Python files from same project → `fs_stat` called only once.

---

## EXECUTION ORDER

```text
Priority 1 (blocks correctness):
  C-01  diagnostics.lua top-level execution
  R-02  workspace.lua global cd
  F-01  harpoon API version mismatch

Priority 2 (measurable perf impact):
  H-01  lualine 60fps + CursorMoved
  H-02  treesitter sync parser check
  H-03  core→plugin coupling in keymaps

Priority 3 (correctness/hygiene):
  A-01  vim._comment private API
  A-02  health→mcphub coupling
  A-03  ai.lua blocking git diff
  D-01  explorer duplicate set_edgy_hl
  F-02  debugging.lua double exepath
  F-03  authoring.lua missing augroup

Priority 4 (refinements):
  Z-01  init.lua dead bench.setup call
  Z-02  telemetry 100ms timer
  Z-03  which-key UIEnter → VeryLazy
  Z-04  guess-indent BufReadPre → BufReadPost
  A-04  quality.lua sync selene detection
  G-01  debug globals
  G-02  dashboard global state
  R-01  secops sync scan
  R-05  bootstrap _G.Snacks ref

Priority 5 (documentation/cleanup):
  C-02  LSP dir comment fix
  D-02  picker duplicate keymaps (intentional)
  D-03  explorer ownership boundaries
  F-04  foldexpr comment
  FT-01 dvc dead code
  FT-02 python venv caching
```

---

## VALIDATION MATRIX

| #    | Check                      | Command                                                           | Expected                    |
|------|----------------------------|-------------------------------------------------------------------|-----------------------------|
| V-01 | Syntax / import            | `nvim --headless '+qa'`                                           | Exit 0                      |
| V-02 | Cold startup (20 runs)     | `hyperfine --warmup 3 --runs 20 'nvim --headless +qa'`            | ≤ 12ms mean                 |
| V-03 | No globals                 | `:lua for k,v in pairs(_G) do if k:match("^_x0r") then print(k) end end` | Empty            |
| V-04 | No debug globals (prod)    | `:lua print(_G.dd, _G.bt)`                                       | `nil nil` (without DEBUG)   |
| V-05 | Timer audit                | `vim.uv.walk(function(h) if h:get_type()=="timer" and h:is_active() then print("ACTIVE TIMER") end end)` | 0 active timers when idle |
| V-06 | Diagnostic config deferred | `nvim --startuptime /tmp/s.log '+qa' && grep diagnostic /tmp/s.log` | Not in early phase        |
| V-07 | Lualine refresh            | Type in large file → `:Snacks profiler`                           | Lualine not in top-10       |
| V-08 | Keymap ownership           | `:verbose nmap <C-h>`                                             | smart-splits or wincmd only |
| V-09 | No duplicate autocmds      | `:au ColorScheme` → count Edgy entries                            | Single entry                |
| V-10 | Workspace CWD              | `:pwd` in split with files from 2 projects                        | Correct per-window root     |
| V-11 | Harpoon settings           | `:lua print(require("harpoon").config.settings.save_on_toggle)`   | `true`                      |
| V-12 | Domain count               | `ls lua/plugins/*.lua \| wc -l`                                   | 23                          |
| V-13 | Secret scan                | `grep -rn 'sk-ant-\|sk-proj-\|API_KEY=' lua/`                    | Empty                       |

---

**Commit strategy:** One commit per priority group. Each commit must pass V-01 + V-02.
