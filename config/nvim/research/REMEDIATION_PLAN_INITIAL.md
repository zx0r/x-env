# REMEDIATION PLAN — Neovim x0r

**Дата:** 2026-09-30 **Scope:** полная стабилизация, доменное выравнивание, UI-реструктуризация,
runtime-оптимизация **Источники:** `NVIM_ARCHITECTURE_AUDIT_2026-09-30.md`, рецензия архитектора,
`README.md` (capability model), UI-model correction **Правило:** каждое изменение — один коммит,
одна валидация. Не смешивать фазы.

---

## TARGET ARCHITECTURE

```text
x0r/
├── init.lua
├── lazy-lock.json
├── README.md
│
├── lua/
│   ├── core/                          ФУНДАМЕНТ (0 domain/plugin deps; lazy.lua = bootstrap boundary)
│   │   ├── perf.lua                   startup performance
│   │   ├── options.lua                editor settings
│   │   ├── keymaps.lua                global bindings
│   │   ├── autocmds.lua               event handlers
│   │   ├── lazy.lua                   plugin manager
│   │   └── lib/
│   │       ├── guard.lua              large-file protection
│   │       ├── bench.lua              profiling harness
│   │       ├── health.lua             health checks
│   │       ├── secops.lua             security utilities
│   │       └── telemetry.lua          observability (opt-in)
│   │
│   └── plugins/                       CAPABILITY DOMAINS (auto-import)
│       │
│       │  ── Code Intelligence ──
│       ├── language.lua           ①   LSP orchestration, capabilities, attach
│       ├── syntax.lua             ②   Treesitter parsers, textobjects, context
│       ├── coding.lua             ③   Completion, formatting, snippets, pairs, surround
│       ├── diagnostics.lua        ④   Diagnostic model, routing, presentation policy
│       ├── quality.lua            ⑤   Linters, static analysis, metrics, complexity
│       │
│       │  ── Execution ──
│       ├── debugging.lua          ⑥   DAP adapters, debug UI
│       ├── testing.lua            ⑦   Test runners, adapters, coverage
│       │
│       │  ── Workspace ──
│       ├── navigation.lua         ⑧   Motions, jumps, pins, picker, search
│       ├── workspace.lua          ⑨   Project context, sessions, root detection
│       ├── explorer.lua           ⑩   Filesystem: tree, oil, external FM
│       ├── terminal.lua           ⑪   Shell, multiplexer integration
│       ├── vcs.lua                ⑫   Git signs, diff, worktree, blame
│       │
│       │  ── Content ──
│       ├── data.lua               ⑬   Databases, notebooks, REPL
│       ├── infrastructure.lua     ⑭   Docker, Terraform, K8s, Ansible
│       ├── authoring.lua          ⑮   Markdown, Quarto, LaTeX, docs
│       │
│       │  ── Tooling ──
│       ├── toolchain.lua          ⑯   Mason: install, discovery, registry
│       ├── ai.lua                 ⑰   LLM, MCP, agents
│       │
│       │  ── Presentation Layer ──
│       ├── ui.lua                 ⑱   Shared UI framework primitives
│       ├── ui-dashboard.lua       ⑲   Dashboard / startup surface
│       ├── ui-messages.lua        ⑳   Notifications, cmdline, messages
│       ├── ui-status.lua          ㉑   Statusline, winbar, tabline, statuscolumn
│       ├── ui-theme.lua           ㉒   Colorscheme, highlights, visual styling
│       └── ui-discovery.lua       ㉓   Keymap / command discoverability
│
├── lsp/                               Server overrides ONLY
│   ├── lua_ls.lua
│   ├── jsonls.lua
│   └── yamlls.lua
│
├── after/ftplugin/                    Buffer-local ONLY
│   ├── go.lua
│   ├── python.lua
│   ├── rust.lua
│   └── markdown.lua
│
├── colors/                            Colorscheme implementation
│   └── environment-x.lua
│
└── scripts/
    └── benchmark.py
```

**23 capability domains. Flat composition. Single `{ import = "plugins" }`.**

---

## DOMAIN SEMANTIC MODEL (из README)

```text
language.lua         "What does the code mean?"
syntax.lua           "What is the structural form of the code?"
coding.lua           "How is code edited or transformed?"
diagnostics.lua      "What problems/signals have been produced?"
quality.lua          "How is code statically evaluated?"
debugging.lua        "What happens during execution?"
testing.lua          "Does the system behave correctly?"
navigation.lua       "How is information found and selected?"
workspace.lua        "What project/context am I operating in?"
explorer.lua         "How are filesystem objects manipulated?"
terminal.lua         "How are external processes interacted with?"
vcs.lua              "How is source history managed?"
data.lua             "How are data-oriented workflows handled?"
infrastructure.lua   "How are infrastructure systems operated?"
authoring.lua        "How are technical documents authored/rendered?"
toolchain.lua        "How are external development tools provisioned?"
ai.lua               "How are AI/agent capabilities integrated?"
ui-*.lua             "How are capabilities presented and interacted with?"
```

---

## PHASE 0 — CRITICAL STABILIZATION

> Блокирующие дефекты. Конфиг не production-grade без этих fixes.

| ID        | File                            | Change                                                              | Validation                                              |
| --------- | ------------------------------- | ------------------------------------------------------------------- | ------------------------------------------------------- |
| **P0-01** | `lua/plugins/language.lua:~507` | Fix syntax error: добавить пропущенный `end`                        | `nvim --headless '+qa'` exits 0                         |
| **P0-02** | `lua/core/autocmds.lua:117`     | `require("lib.guard")` → `require("core.lib.guard")`                | Open 2MB file → `:lua print(vim.b.large_file)` = `true` |
| **P0-03** | `lua/plugins/`                  | Удалить `ui-dash__.lua` из plugins/ (архивировать в `x0r/archive/`) | `ls lua/plugins/ui-dash*` → только один файл            |
| **P0-04** | `lua/plugins/navigation.lua`    | Удалить Neo-tree блок целиком (дублирует `explorer.lua`)            | `:verbose nmap <leader>e` → единственный owner          |
| **P0-05** | `lua/plugins/vcs.lua`           | Заменить все `TodoFzfLua` / fzf-lua вызовы на `Snacks.picker`       | Все worktree/TODO команды работают без ошибок           |

**Commit:** `fix(critical): stabilize config — guard path, syntax, duplicates`

---

## PHASE 1 — DOMAIN ALIGNMENT

> Привести файловую структуру в соответствие с README capability model.

| ID        | Current file                 | Action                              | Target file          | Deps  |
| --------- | ---------------------------- | ----------------------------------- | -------------------- | ----- |
| **P1-01** | `treesitter.lua`             | **Rename**                          | `syntax.lua`         | P0    |
| **P1-02** | `debug.lua`                  | **Rename**                          | `debugging.lua`      | P0    |
| **P1-03** | `infra.lua`                  | **Rename** + заселить               | `infrastructure.lua` | P0    |
| **P1-04** | `markdown.lua`               | **Rename**                          | `authoring.lua`      | P0    |
| **P1-05** | —                            | **Create** `diagnostics.lua`        | `diagnostics.lua`    | P1-01 |
| **P1-06** | —                            | **Create** `workspace.lua`          | `workspace.lua`      | P0    |
| **P1-07** | `language.lua` (Mason block) | **Extract** Mason → `toolchain.lua` | `toolchain.lua`      | P1-05 |

### P1-05: `diagnostics.lua` — новый домен

Извлечь из `language.lua` всю diagnostic policy:

```lua
-- lua/plugins/diagnostics.lua
-- Domain: "What problems/signals have been produced?"
-- Owner: diagnostic model, routing, presentation
return {
  -- vim.diagnostic.config ownership
  -- diagnostic signs, virtual text, float policy
  -- severity sorting, source display
  -- update_in_insert policy
  -- large-file diagnostic policy
  -- trouble.nvim (if used)
}
```

**Принцип:** `language.lua` производит diagnostics (LSP), `quality.lua` производит diagnostics
(nvim-lint, selene, vale), но `diagnostics.lua` владеет **presentation и routing policy**.

### P1-06: `workspace.lua` — новый домен

```lua
-- lua/plugins/workspace.lua
-- Domain: "What project/context am I operating in?"
-- Owner: project detection, root, sessions, workspace switching
return {
  -- project root detection
  -- session management
  -- workspace-specific settings
  -- .editorconfig integration
  -- project-local configuration trust
}
```

### P1-07: `toolchain.lua` — извлечение Mason

```lua
-- lua/plugins/toolchain.lua
-- Domain: "How are external development tools provisioned?"
-- Owner: Mason, tool installation, binary discovery, registry
return {
  {
  "mason-org/mason.nvim",
  lazy = false,
  opts = {},
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    cmd = "MasonToolsInstall",
    opts = {
      ensure_installed = { ... }, -- full tool list
      run_on_start = false,       -- FIX: no installer at startup
      auto_update = false,
    },
  },
}
```

**Commit:** `refactor(domains): align file names with README capability model`

---

## PHASE 2 — UI LAYER RESTRUCTURING

> Реструктуризация UI в соответствии с Neovim UI protocol model.

| ID        | Current files     | Action                            | Target file        | Deps         |
| --------- | ----------------- | --------------------------------- | ------------------ | ------------ |
| **P2-01** | `ui-core.lua`     | **Rename** → чистые UI primitives | `ui.lua`           | P1           |
| **P2-02** | `ui_dash.lua`     | **Rename**                        | `ui-dashboard.lua` | P0-03        |
| **P2-03** | `ui-notify.lua`   | **Rename** + расширить scope      | `ui-messages.lua`  | P2-01        |
| **P2-04** | `ui-whichkey.lua` | **Rename**                        | `ui-discovery.lua` | P1           |
| **P2-05** | `ui-styler.lua`   | **Merge** → `ui-theme.lua`        | `ui-theme.lua`     | P1           |
| **P2-06** | `ui-ux.lua`       | **Decompose** по владельцам       | (distribute)       | P2-01, P2-05 |

### P2-01: `ui.lua` — shared UI primitives only

```lua
-- lua/plugins/ui.lua
-- Domain: Shared UI framework primitives
-- NOT: dashboard, NOT: notifications, NOT: theme
-- NOT: picker (→ navigation), NOT: terminal (→ terminal)
-- NOT: bigfile (→ core policy), NOT: profiler (→ core/lib)
--
-- lazy.nvim merges Snacks opts fragments across domain files.
-- Each capability domain owns its own Snacks fragment.
return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      -- Shared UI framework integration and plugin registration.
      -- Plugin specification location does not define semantic ownership.
      bigfile      = { enabled = true },
      profiler     = { enabled = true },
      input        = { enabled = true },
      quickfile    = { enabled = true },
      words        = { enabled = true },
      zen          = { enabled = true },
    },
  },
}
```

**Domain-owned Snacks fragments** (lazy.nvim auto-merges `opts`):

```lua
-- lua/plugins/navigation.lua: picker specification
{ "folke/snacks.nvim", opts = { picker = { enabled = true } } }

-- lua/plugins/terminal.lua: terminal specification
{ "folke/snacks.nvim", opts = { terminal = { enabled = true } } }
```

**Policy-level ownership for core capabilities**:
While `ui.lua` registers the `bigfile` and `profiler` plugin specs (since `core/` modules do not return plugin specs), semantic ownership remains outside `ui.lua`:
- `core/lib/guard.lua` → large-file policy and logic
- `core/lib/bench.lua` → profiling execution policy

### P2-03: `ui-messages.lua` — message system

```lua
-- lua/plugins/ui-messages.lua
-- Domain: Messages / notifications / cmdline presentation
-- Semantic scope: all message surfaces per Neovim UI protocol
return {
  -- Snacks notifier opts (merged via lazy.nvim spec merge):
  {
    "folke/snacks.nvim",
    opts = {
      notifier = {
        enabled = true,
        timeout = 3000,
      },
    },
  },
  -- vim.notify override, LSP progress handling
  -- cmdline presentation (if noice used)
  -- message history
}
```

### P2-06: `ui-ux.lua` decomposition

| Current content      | Target owner             | Rationale                |
| -------------------- | ------------------------ | ------------------------ |
| `indent guides`      | `ui.lua` (Snacks.indent) | UI primitive             |
| `scroll animation`   | `ui.lua` (Snacks.scroll) | UI rendering             |
| `word highlighting`  | `ui.lua` (Snacks.words)  | UI primitive             |
| `zen mode`           | `ui.lua` (Snacks.zen)    | UI view                  |
| `rainbow-delimiters` | `syntax.lua`             | Structural visualization |
| `highlight-undo`     | `coding.lua`             | Edit feedback            |
| `highlight-colors`   | `ui-theme.lua`           | Visual styling           |
| `modicator`          | `ui-status.lua`          | Mode state presentation  |

После decomposition `ui-ux.lua` **удаляется** — его содержимое распределено по семантическим
владельцам.

**Commit:** `refactor(ui): restructure UI layer per Neovim protocol model`

---

## PHASE 3 — OWNERSHIP CONSOLIDATION

> Устранить duplicate ownership, globals, phantom dependencies.

| ID        | File(s)              | Change                                                         | Validation                              |
| --------- | -------------------- | -------------------------------------------------------------- | --------------------------------------- |
| **P3-01** | `core/keymaps.lua`   | Удалить `_G.core_wk_groups`                                    | `:lua print(_G.core_wk_groups)` → `nil` |
| **P3-02** | `ui-discovery.lua`   | Перенести which-key group registration сюда через `wk.add()`   | Groups отображаются корректно           |
| **P3-03** | `explorer.lua`       | Удалить `_G._diff_Node` / `_G._diff_Name` → module-local state | No `_G._diff_*` in global scope         |
| **P3-04** | `ui-discovery.lua`   | Удалить stale icon rules для fzf-lua/neotest                   | Нет ссылок на несуществующие плагины    |
| **P3-05** | `testing.lua`        | Заселить neotest spec + adapter                                | Файл не пустой, intent documented       |
| **P3-06** | `quality.lua`        | Заселить: selene (conditional), vale, code metrics             | Файл не пустой                          |
| **P3-07** | `infrastructure.lua` | Заселить: Dockerfile ft, terraform-ls, helm-ls                 | Файл не пустой                          |
| **P3-08** | `core/lazy.lua`      | `install.missing = false` — explicit provisioning via `:Lazy install`; not a perf issue, a reproducibility/supply-chain concern | Clean machine requires explicit install  |

### P3-05: `testing.lua` — заселение

```lua
-- lua/plugins/testing.lua
-- Domain: "Does the system behave correctly?"
-- Status: scaffolded — enable adapters per active workflows
return {
  {
    "nvim-neotest/neotest",
    cmd = "Neotest",
    keys = {
      { "<leader>tt", function() require("neotest").run.run() end, desc = "Run nearest test" },
      { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run file" },
      { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Toggle summary" },
    },
    dependencies = {
      "nvim-neotest/nvim-nio",
      -- Enable adapters as needed:
      -- "nvim-neotest/neotest-python",
      -- "nvim-neotest/neotest-go",
      -- "rouge8/neotest-rust",
      -- "marilari88/neotest-vitest",
    },
    opts = function()
      return {
        adapters = {
          -- require("neotest-python"),
          -- require("neotest-go"),
        },
      }
    end,
  },
}
```

**Commit:** `fix(ownership): consolidate globals, populate empty domains`

---

## PHASE 4 — API MODERNIZATION

| ID        | File                               | Change                                                                                                       | Risk   | Validation                                                  |
| --------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------ | ----------------------------------------------------------- |
| **P4-01** | `syntax.lua`                       | Align с upstream nvim-treesitter rewrite: `lazy = false`, parser install → explicit `:TSUpdate` / build hook | Medium | `:checkhealth nvim-treesitter` — no install on file open    |
| **P4-02** | `coding.lua`                       | blink.cmp: `version = "1.*"` (semantic guard against v2 ABI break)                                           | Low    | `:Lazy` shows pinned v1.x                                   |
| **P4-03** | `colors/environment-x.lua`         | Lualine theme → `lua/lualine/themes/environment_x.lua`; удалить `package.preload` hack                       | Medium | Lualine loads theme without preload                         |
| **P4-04** | `ui-theme.lua`                     | Merge `ui-styler.lua` content; удалить `package.loaded` monkey patches из nightfox                           | Low    | No `package.loaded` mutations                               |
| **P4-05** | `language.lua` → `diagnostics.lua` | Diagnostic config extraction: `vim.diagnostic.config` ownership → `diagnostics.lua`                          | Medium | `:lua print(vim.diagnostic.config())` shows expected config |

**Commit:** `refactor(api): treesitter lifecycle, blink pin, theme cleanup`

---

## PHASE 5 — RUNTIME OPTIMIZATION

| ID        | File                               | Change                                                                                                                                                 | Validation                                |
| --------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------- |
| **P5-01** | `core/lib/telemetry.lua`           | Timer → opt-in via `:CoreTelemetryStart`/`:CoreTelemetryStop`; bounded ring buffer (1000 entries max); remove auto-start from `init.lua` UIEnter block | `vim.uv.walk` → 0 active timers when idle |
| **P5-02** | `core/autocmds.lua` + `coding.lua` | Remove `BufWritePre` whitespace trim from autocmds; let Conform own all whitespace via `trim_whitespace` + `trim_newlines` formatters                  | Single mutation per save                  |
| **P5-03** | `quality.lua`                      | Remove `InsertLeave` trigger from nvim-lint; lint on `BufWritePost` only                                                                               | No lint on typing stop                    |
| **P5-04** | `toolchain.lua`                    | `run_on_start = false` in mason-tool-installer                                                                                                         | No installer check during normal startup  |
| **P5-05** | `coding.lua`                       | Conform: evaluate `format_after_save` vs `format_on_save`; reduce 3000ms timeout                                                                       | Measure save latency                      |

**Commit:** `perf(runtime): opt-in telemetry, single format owner, no startup installer`

---

## PHASE 6 — FEATURE ADDITIONS (from x0r_old)

| ID        | Target file        | Addition                                                     | Trigger       | Risk |
| --------- | ------------------ | ------------------------------------------------------------ | ------------- | ---- |
| **P6-01** | `coding.lua`       | `tzachar/highlight-undo.nvim` — visual feedback on undo/redo | `VeryLazy`    | Low  |
| **P6-02** | `ui-theme.lua`     | `brenoprata10/nvim-highlight-colors` — inline color preview  | `BufReadPost` | Low  |
| **P6-03** | `syntax.lua`       | `HiPhish/rainbow-delimiters.nvim` — nested bracket colors    | `BufReadPost` | Low  |
| **P6-04** | `coding.lua`       | Biome conditional formatter for TS/JS/JSON in Conform config | via Conform   | Low  |
| **P6-05** | `quality.lua`      | Selene linter (conditional `selene.toml` detection)          | via nvim-lint | Low  |
| **P6-06** | `core/keymaps.lua` | `<Tab>` → `}`, `<S-Tab>` → `{` (block navigation)            | Immediate     | Low  |
| **P6-07** | `ui-messages.lua`  | Filter: hide `No information available` LSP hover            | via notifier  | Low  |

**Commit:** `feat: highlight-undo, color preview, rainbow brackets, biome, selene, block nav`

---

## PHASE 7 — VALIDATION

| #    | Check             | Command                                                               | Expected                   |
| ---- | ----------------- | --------------------------------------------------------------------- | -------------------------- |
| V-01 | Syntax / import   | `nvim --headless '+qa'`                                               | Exit 0                     |
| V-02 | Cold startup (20) | `hyperfine --warmup 3 --runs 20 'nvim --headless +qa'`                | ≤ 20ms                     |
| V-03 | Map collision     | `:verbose nmap <leader>e`                                             | Single owner               |
| V-04 | LSP health        | `:checkhealth vim.lsp`                                                | All OK                     |
| V-05 | Treesitter health | `:checkhealth nvim-treesitter`                                        | All OK                     |
| V-06 | Timer audit       | `vim.uv.walk(function(h) print(h:get_type(), h:is_active()) end)`     | 0 timers                   |
| V-07 | Plugin profile    | `:Lazy profile`                                                       | No unexpected eager        |
| V-08 | Lockfile          | `jq -r '.[] \| .commit' lazy-lock.json \| grep -cvE '^[0-9a-f]{40}$'` | 0                          |
| V-09 | Secret scan       | `grep -rn 'sk-ant-\|sk-proj-\|API_KEY=' lua/`                         | Empty                      |
| V-10 | Large-file        | Open 2MB file                                                         | `vim.b.large_file == true` |
| V-11 | Domain count      | `ls lua/plugins/*.lua \| wc -l`                                       | 23                         |
| V-12 | No globals        | `:lua print(_G.core_wk_groups, _G._diff_Node)`                        | `nil nil`                  |
| V-13 | Picker            | `<leader>ff`, `<leader>fg`                                            | No fzf-lua error           |
| V-14 | Dashboard         | nvim without file                                                     | Dashboard renders          |
| V-15 | Notifications     | `:lua vim.notify("test")`                                             | Notifier shows             |

---

## FILE OPERATION SUMMARY

### Renames (git mv)

```
treesitter.lua      → syntax.lua
debug.lua           → debugging.lua
infra.lua           → infrastructure.lua
markdown.lua        → authoring.lua
ui-core.lua         → ui.lua
ui_dash.lua         → ui-dashboard.lua
ui-notify.lua       → ui-messages.lua
ui-whichkey.lua     → ui-discovery.lua
```

### Creates

```
diagnostics.lua     — NEW: extracted from language.lua
workspace.lua       — NEW: project context
toolchain.lua       — NEW: extracted Mason from language.lua
```

### Deletes / Archives

```
ui-dash__.lua       → archive/
ui-styler.lua       → merge into ui-theme.lua, then delete
ui-ux.lua           → decompose into owners, then delete
```

### Result

```
Before:  25 files in plugins/ (including drafts/duplicates)
After:   23 files in plugins/ (all populated, all named per README)
```

---

## DOMAIN DEPENDENCY MAP

```text
                  ┌────────────────┐
                  │  toolchain     │
                  │  installation  │
                  │  provisioning  │
                  └───────┬────────┘
                          │
         ┌────────────────┼────────────────┐
         ↓                ↓                ↓
    language          quality         debugging
       LSP           linters            DAP
         │                │                │
         └────────┬───────┘                │
                  ↓                        │
            diagnostics ←──────────────────┘
                  │
         presentation policy
                  │
                  ↓
          ui-messages.lua


    syntax ──→ coding  (textobjects → editing)


    workspace ──→ navigation   (project-scoped search)
         │
         └──→ ui-dashboard (project entry presentation)


    vcs ──→ ui-status (git state in statusline)
```

---

## EXECUTION ORDER

```text
P0 (stabilize)  →  P1 (domains)  →  P2 (UI)  →  P3 (ownership)
                                                       │
                                          P4 (APIs)  ←─┘
                                              │
                                    P5 (runtime) ← P4
                                              │
                                    P6 (features) ← P5
                                              │
                                    P7 (validation) ← P6
```

Каждая фаза — отдельный коммит. Валидация `nvim --headless '+qa'` после каждого коммита.


---

# PHASE 8 — SUPPLEMENTARY DATA (из NVIM_ARCHITECTURE_AUDIT + OPUS Review)

> Материалы, отсутствовавшие в основном REMEDIATION_PLAN, но зафиксированные в
> `NVIM_ARCHITECTURE_AUDIT_2026-09-30.md` и рецензии Principal Architect (OPUS audit review).
> Каждая секция — справочные данные для фаз P0–P7.

---

## S1. RUNTIME BASELINE

| Параметр | Факт |
|---|---|
| OS / CPU | macOS 27.2, Darwin arm64 (T6000) |
| Neovim | `NVIM v0.12.5`, Release |
| Lua | LuaJIT 2.1.1774638290 |
| Shell / терминал при аудите | fish / `TERM=dumb` |
| Config root | `/Users/x0r/.config/nvim/x0r` (`XDG_CONFIG_HOME=/Users/x0r/.config/nvim`, `NVIM_APPNAME=x0r`) |
| Data root | `/Users/x0r/.local/share/nvim/x0r` |
| Plugin manager | lazy.nvim, 62 configured / 62 lock entries / 67 directories in data lazy root |
| Startup (current) | **45.327 ms**, headless startuptime |
| Startup (baseline after syntax repair) | 21.043 ms (диагностический симулятор) |
| Main sync block | `require("core.lazy")`: 36.373 ms elapsed (20.455 ms self) |
| Current post-startup | 62 loaded Lua modules, 107 autocmds, 212 normal maps, 2 start plugins, 1 libuv handle |
| Baseline post-startup | 59 modules, 103 autocmds, 205 normal maps, 59 lazy plugins, 3 Snacks fragments |

**Per-plugin load time command:**

```
XDG_CONFIG_HOME=/Users/x0r/.config/nvim NVIM_APPNAME=x0r nvim --headless \
  -c "lua for k,v in pairs(require('lazy').plugins()) do if v._.loaded then print(string.format('%-40s %8.2fms', v.name, (v._.loaded.time or 0))) end end" \
  -c "qa"
```

---

## S2. RUNTIME SLA TABLE

| Domain | SLA | Current | Status | Validation |
|---|---|---|---|---|
| Cold startup | ≤ 20ms headless | 45.327ms | ❌ FAIL | `nvim --headless --startuptime /tmp/s.log +qa && tail -1 /tmp/s.log` |
| Warm startup | ≤ 15ms headless | Not measured | ⚠️ | Repeat after lockfile stabilization |
| Keystroke latency | ≤ 2ms overhead | Not measured | ⚠️ | CursorMoved handler audit |
| LSP attach | Event-driven, 0 blocking | ✅ Correct | ✅ | `:LspInfo` on fresh buffer |
| Completion | Sub-2ms per-keystroke | Not measured | ⚠️ | Type in large buffer, observe lag |
| Format-on-save | ≤ 500ms or async | 3000ms sync timeout | ⚠️ RISK | `:ConformInfo`, measure save time |
| Linting | Async, bounded | ✅ Debounced | ✅ | Observe `InsertLeave` lint |
| Debug startup | 0 cost until explicit | ✅ Key-loaded | ✅ | `:Lazy` profile |
| AI/MCP startup | 0 cost until explicit | ✅ Cmd/key-loaded | ✅ | `:Lazy` profile |
| Dashboard | 0 permanent polling | ❌ CursorMoved loop | ❌ FAIL | Timer walk after dashboard open |
| Git redraw | 0 synchronous subprocess | ✅ Gitsigns async | ✅ | Process list during editing |
| Tmux escape | 0ms | Not measured | ⚠️ | `tmux show -g escape-time` |
| Kitty input delay | ≤ 1ms | Not measured | ⚠️ | `kitty.conf` audit |
| Telemetry idle | 0 timers | ❌ 100ms forever timer | ❌ FAIL | `vim.uv.walk` after UIEnter |

---

## S3. FULL SYSTEM DEPENDENCY GRAPH

### S3.1 TARGET STATE (post-remediation)

```mermaid
graph TD
    subgraph "macOS Darwin arm64"
        A["Kitty Terminal<br/>Metal / Cocoa / ProMotion"] --> B["Tmux Multiplexer<br/>Unix Socket IPC"]
        B --> C["Neovim 0.12.5<br/>LuaJIT 2.1"]
    end

    subgraph "Core Foundation"
        C --> D[init.lua]
        D --> E[core/perf.lua]
        D --> F[core/options.lua]
        D --> G[core/keymaps.lua]
        D --> H[core/lazy.lua]
        D --> I[core/autocmds.lua]

        D --> LIB["core/lib/<br/>guard · bench · health<br/>secops · telemetry"]

        H --> K[lazy.nvim]
        K --> L{"import plugins/"}
    end

    subgraph "Code Intelligence"
        L --> P01["① language.lua<br/>LSP orchestration"]
        L --> P02["② syntax.lua<br/>Treesitter parsers, textobjects"]
        L --> P03["③ coding.lua<br/>blink + conform + snippets"]
        L --> P04["④ diagnostics.lua<br/>diagnostic model, routing"]
        L --> P05["⑤ quality.lua<br/>linters, static analysis"]
    end

    subgraph "Execution"
        L --> P06["⑥ debugging.lua<br/>DAP adapters, debug UI"]
        L --> P07["⑦ testing.lua<br/>neotest, adapters, coverage"]
    end

    subgraph "Workspace"
        L --> P08["⑧ navigation.lua<br/>Flash, Harpoon, picker"]
        L --> P09["⑨ workspace.lua<br/>project root, sessions"]
        L --> P10["⑩ explorer.lua<br/>Neo-tree + Oil + Yazi"]
        L --> P11["⑪ terminal.lua<br/>shell, multiplexer"]
        L --> P12["⑫ vcs.lua<br/>Gitsigns, Diffview, worktree"]
    end

    subgraph "Content"
        L --> P13["⑬ data.lua<br/>databases, notebooks, REPL"]
        L --> P14["⑭ infrastructure.lua<br/>Docker, Terraform, K8s"]
        L --> P15["⑮ authoring.lua<br/>Markdown, Quarto, LaTeX"]
    end

    subgraph "Tooling"
        L --> P16["⑯ toolchain.lua<br/>Mason install, registry"]
        L --> P17["⑰ ai.lua<br/>LLM, MCP, agents"]
    end

    subgraph "Presentation Layer"
        L --> P18["⑱ ui.lua<br/>Snacks shared primitives"]
        L --> P19["⑲ ui-dashboard.lua<br/>startup surface"]
        L --> P20["⑳ ui-messages.lua<br/>notifications, cmdline"]
        L --> P21["㉑ ui-status.lua<br/>Lualine, winbar, tabline"]
        L --> P22["㉒ ui-theme.lua<br/>colorscheme, highlights"]
        L --> P23["㉓ ui-discovery.lua<br/>which-key, keymap help"]
    end

    subgraph "Server Overrides"
        P01 --> LSP["lsp/*.lua<br/>lua_ls · jsonls · yamlls"]
    end

    %% Cross-domain data flows
    P16 -.->|provisions| P01
    P16 -.->|provisions| P05
    P16 -.->|provisions| P06
    P16 -.->|provisions| P03
    P01 -.->|produces diagnostics| P04
    P05 -.->|produces diagnostics| P04
    P04 -.->|presentation| P20
    P02 -.->|textobjects| P03
    P09 -.->|project scope| P08
    P09 -.->|project entry| P19
    P12 -.->|git state| P21

    I --> LIB
```

### S3.2 CURRENT STATE (pre-remediation — broken edges)

```mermaid
graph TD
    subgraph "Broken Edges in Current Config"
        direction LR
        BE1["autocmds.lua: require 'lib.guard' ≠ 'core.lib.guard'<br/>→ large-file guard silently fails"]
        BE2["vcs.lua: TodoFzfLua → fzf-lua absent<br/>→ worktree/TODO commands crash"]
        BE3["navigation.lua ↔ explorer.lua: duplicate Neo-tree spec<br/>→ leader-e has two owners"]
        BE4["ui-core, ui-notify, ui_dash, ui-dash__:<br/>4 Snacks fragments → fragmented capability ownership"]
        BE5["keymaps.lua: _G.core_wk_groups → ui-whichkey<br/>→ hidden global coupling"]
    end

    style BE1 fill:#ff4444,color:#fff
    style BE2 fill:#ff4444,color:#fff
    style BE3 fill:#ff8800,color:#fff
    style BE4 fill:#ff8800,color:#fff
    style BE5 fill:#ffaa00,color:#000
```

---

## S4. ANTI-PATTERN CHECKLIST

### Architecture

- [x] duplicate domains — **Neo-tree** в `navigation.lua` + `explorer.lua`
- [x] fake domains — `testing.lua` ({}), `quality.lua` ({}), `infra.lua` ({})
- [x] fragmented Snacks ownership — same implementation configured across unrelated domain files, semantic ownership implicit
- [x] hidden plugin dependencies — `schemastore` implicit, fzf-lua phantom
- [x] cross-domain mutation — `_G.core_wk_groups`, `_G._diff_*`
- [x] runtime globals — `_G.core_wk_groups`, `_G._diff_Node`, `_G._diff_Name`
- [x] package.preload hacks — `environment-x.lua` lualine theme, `nightfox.lua`
- [x] package.loaded monkey patches — `nightfox.lua`
- [ ] ~~monolithic plugin file~~ — файлы разделены по доменам
- [ ] ~~empty abstraction layers~~ — `core/lib/` modules имеют реальный код

### Startup

- [x] startup filesystem scans — `install.missing = true` triggers
- [ ] ~~lazy=false without proof~~ — Only lazy.nvim and Snacks start plugins
- [ ] ~~VeryLazy used as catch-all~~ — Не обнаружено
- [ ] ~~synchronous shell calls~~ — Bootstrap `vim.system:wait()` justified
- [ ] ~~eager require of heavy modules~~ — Deferred correctly

### Runtime

- [x] timer polling — 100ms telemetry timer forever
- [x] CursorMoved heavy callbacks — Dashboard cursor lock in `ui-dash__.lua`
- [x] expensive statusline functions — 612 LOC lualine, Git/LSP recompute
- [x] repeated LSP queries — `CursorMoved` document highlight clear
- [ ] ~~BufEnter heavy callbacks~~ — `formatoptions` removal is lightweight
- [ ] ~~repeated filesystem scans~~ — Не обнаружено в hot path
- [ ] ~~repeated process spawning~~ — Не обнаружено

### LSP

- [x] duplicate formatting — Core trim + Conform both on BufWritePre
- [ ] ~~old lspconfig.setup()~~ — Native model used correctly ✅
- [ ] ~~native vim.lsp APIs ignored~~ — `vim.lsp.config`/`vim.lsp.enable` used ✅
- [ ] ~~duplicate LspAttach~~ — Single LspAttach handler

### Treesitter

- [x] startup parser install — `treesitter.install(missing)` on first file open
- [ ] ~~old API~~ — New rewrite API used
- [ ] ~~unconditional giant-file parsing~~ — Guard exists (but broken path)

### Picker

- [x] multiple primary pickers — Snacks + phantom fzf-lua + Telescope (text-case dep)
- [x] hidden picker fallback — Dashboard variants disagree on picker
- [x] duplicate vim.ui.select ownership — Not explicitly audited

### UI

- [x] multiple explorers — Neo-tree + Oil + Yazi (roles unclear)
- [x] multiple dashboard owners — 3 variant files
- [ ] ~~multiple statuslines~~ — Single lualine
- [ ] ~~multiple theme owners~~ — Single environment-x

### Security

- [x] AI data egress — Staged diff → remote LLM without cap/redact
- [x] modeline/exrc risks — `modeline=true` surface, `exrc=false` correct
- [x] insecure shell interpolation — Not explicitly audited
- [ ] ~~hardcoded secrets~~ — Не обнаружено

---

## S5. EXTENDED DOMAINS (пропущены в исходном аудите)

### Domain: Kitty GPU Transport & macOS Metal Optimization

> OPUS prompt Domain 3 — полностью отсутствовал в архитектурном аудите.

| Параметр | Эталонное значение | Текущий статус |
|---|---|---|
| `repaint_delay` | ≤ 10ms | Не проверено |
| `input_delay` | ≤ 1ms | Не проверено |
| `sync_to_monitor` | yes (ProMotion 120Hz) | Не проверено |
| `allow_remote_control` | `socket-only` или `no` | Не проверено |
| `listen_on` | `unix:<0600 socket>` | Не проверено |
| Nerd Font `symbol_map` | deterministic glyph mapping | Не проверено |

**Требуемое действие:** Проверить `~/.config/kitty/kitty.conf`, добавить домен в аудит с конкретными значениями.

### Domain: Tmux Low-Latency & Socket Isolation

> OPUS prompt Domain 4 — полностью отсутствовал в архитектурном аудите.

| Параметр | Эталонное значение | Текущий статус |
|---|---|---|
| `escape-time` | 0 | Не проверено |
| `focus-events` | on | Не проверено |
| `extended-keys` | on | Не проверено |
| True color passthrough | `Tc`, `RGB` terminal-features | Не проверено |
| Status bar budget | < 3.5ms per refresh | Не проверено |
| Socket permissions | 0700 directory | Не проверено |

**Требуемое действие:** Проверить `~/.config/tmux/tmux.conf` или `~/.tmux.conf`.

### Domain: DevSecOps Supply-Chain Verification

Аудит упоминает security в Domain 31, но не выполняет фактическое сканирование.

**Требуемые проверки:**

```bash
# 1. All lockfile entries are 40-char hex SHA commits
jq -r '.[] | .commit' lazy-lock.json | grep -cvE '^[0-9a-f]{40}$'
# Expected: 0

# 2. No plaintext API key patterns
grep -rn 'sk-ant-\|sk-proj-\|ANTHROPIC_API_KEY=\|OPENAI_API_KEY=' x0r/

# 3. Config directory permissions
stat -f '%Lp' x0r/ x0r/lua/ x0r/lua/core/ x0r/lua/plugins/

# 4. modelineexpr status
grep -n 'modelineexpr' x0r/lua/core/options.lua
```

### Domain: CI/CD Verification Oracle

OPUS prompt Deliverable 4 (`workstation_audit_oracle.sh`) полностью отсутствует. Это автоматизированный verification harness для всех доменов.

**Target:** `scripts/workstation_audit_oracle.sh` — POSIX/Bash скрипт, проверяющий:
- Neovim startup & runtime latency (SLA)
- SOLID architecture & non-blocking audit
- DevSecOps & supply-chain security
- Kitty GPU transport parameters
- Tmux low-latency & socket isolation
- LLMOps async & credential hygiene

---

## S6. DOMAIN OWNERSHIP MATRIX

| Responsibility | Current owner | Desired owner | Duplicate / missing | Action |
|---|---|---|---|---|
| bootstrap/options/maps/autocmds | core | core | guard path broken | repair module path |
| plugin manager | lazy | lazy | auto-install side effect | explicit provisioning |
| LSP/server overrides | language + lsp | language + lsp | docs path drift | retain/fix docs |
| Mason/toolchain | language → toolchain | toolchain.lua | DAP tools absent | align registry |
| Treesitter | treesitter → syntax | syntax.lua | install-on-open | provision separately |
| completion/format/lint | coding | coding | Ruff overlap | producer policy |
| diagnostics | language/native → diagnostics | diagnostics.lua (NEW) | multiple producers | source matrix |
| debugging | debug → debugging | debugging.lua | adapters absent | install or remove configs |
| testing | testing | testing | empty/no neotest | delete or implement |
| explorer | navigation + explorer | explorer | two Neo-tree specs | remove from navigation |
| picker | Snacks + Telescope + stale fzf | Snacks | fzf unavailable | migrate calls |
| terminal | core + Snacks + smart-splits | explicit native or Snacks | unclear | choose one UI owner |
| markdown/notebooks | data + authoring | separate, opt-in | generic markdown overlap | narrow ft triggers |
| Snacks UI | four files → ui.lua | ui.lua + domain opts merge | config order | consolidate |
| dashboard | 3 variants → ui-dashboard | ui-dashboard.lua | imports all | retain one |
| notifications | ui-notify → ui-messages | ui-messages.lua | opts dropped | merge |
| status/theme | lualine/colors | lualine + colors | package patches | remove hacks |
| workspace | — → workspace | workspace.lua (NEW) | absent | create |
| observability | core.lib | command-scoped | permanent timer | opt-in only |

---

## S7. PLUGIN INVENTORY & MISSING ITEMS

### Architecture-relevant inventory

| Plugin / capability | Domain | Trigger | Status / action |
|---|---|---|---|
| lazy.nvim | core | start | keep; disable implicit install after bootstrap |
| Snacks | UI (ui.lua) | **4 start fragments → 1** | consolidate to exactly one spec |
| nvim-lspconfig | language | BufReadPre/NewFile | keep native API model |
| rustaceanvim | language | rust ft | keep canonical Rust owner |
| Mason + tool installer | toolchain | module/default | remove `run_on_start`; reconcile tools |
| nvim-treesitter + textobjects/context | syntax | buffer events | follow rewrite's non-lazy guidance |
| blink.cmp + friendly snippets | coding | InsertEnter | pin stable v1 or perform v2 migration |
| conform | coding | save/format events | keep; single formatting owner |
| nvim-lint | quality | BufWritePost | keep; linting belongs to static analysis domain |
| nvim-dap + dap-ui + nio | debugging | keys | keep; provision declared adapters |
| Neo-tree + Oil + Yazi | explorer | cmd/keys | retain roles, remove duplicate Neo-tree spec |
| Telescope | text-case dependency | key | retain only for required extension |
| fzf-lua | **absent** | referenced | migrate to Snacks; do not add by default |
| Quarto/Otter/Render-Markdown | authoring | markdown/quarto ft | commit intentionally; constrain generic Markdown |
| Molten/image/Dadbod | data | ft/cmd | keep demand-loaded |
| CodeCompanion/MCPHub | AI | cmd/keys | keep explicit-use; cap staged diff |
| lualine/which-key/styler | UI | UIEnter/events | keep one owner each |
| neotest/adapters | **absent** | none | add only if tests are a real workflow |

### Missing or unprovisioned items

| Missing item | Evidence | Remediation file | Recommendation |
|---|---|---|---|
| `ibhagwan/fzf-lua` | `vcs.lua:345,392`, `ui-dash__.lua`, health/which-key | `vcs.lua`, dashboard | **Не добавлять.** Заменить на `Snacks.picker`, удалить `TodoFzfLua` |
| `nvim-neotest/neotest` + adapters | `testing.lua` returns `{}`; stale UI/core refs | `testing.lua` | Add only if needed; otherwise remove stale claims |
| debugpy / codelldb / js-debug | `debug.lua` configures; only delve in Mason list | `toolchain.lua` + `debugging.lua` | Add Mason packages or delete unsupported adapter blocks |
| basedpyright/gopls/ts/nil/terraform/bash/yaml/docker/sqls/marksman | enabled but absent from PATH | `language.lua` | Provision only actually used servers |
| Quarto executable | Plugin configured, binary absent | `authoring.lua` | Document prerequisite; disable preview until installed |

---

## S8. API MODERNIZATION MATRIX

| Current API | Assessment | Modern API / action |
|---|---|---|
| `vim.lsp.config`, `vim.lsp.enable` | ✅ current and correct for Neovim 0.12 | retain |
| `lsp/*.lua` runtimepath configs | ✅ current and correct | retain; fix docs from `after/lsp` to `lsp` |
| `require("nvim-treesitter").setup` + `install` | new rewrite API, but lifecycle mismatch | use current rewrite docs; `lazy = false`; explicit parser update |
| blink `version="*"` | unbounded release selection | stable `version="1.*"`; v2 needs `blink.lib` |
| multiple Snacks `config()` | fragmented capability ownership | domain-owned `opts` fragments; lazy.nvim merges deterministically |
| `package.preload/loaded` theme hooks | hidden legacy coupling | lualine theme module → `lua/lualine/themes/environment_x.lua` |
| `vim.system(...):wait()` at bootstrap/AI | synchronous by design | allow only bounded bootstrap/action |

### Коррекции из OPUS review

**Treesitter:** `lazy = false` рекомендуется потому что plugin сам manages `FileType` autocmds для parser activation. `lazy.nvim` `event = {"BufReadPost", "BufNewFile"}` технически функционально эквивалентен при корректной настройке. Фундаментальная проблема — `treesitter.install(missing)` при первом открытии файла, а не lazy/start distinction.

**blink.cmp:** На 2026-09-30 v1 branch — stable, v2 использует `blink.lib` отдельный пакет. `version = false` + lockfile тоже допустимо, но `version = "1.*"` добавляет semantic guard against accidental v2 при `:Lazy update`.

**environment-x.lua:** Это 3235 строк полноценной визуальной операционной среды поверх `nightfox.nvim` — design token system с semantic palette, lualine integration и plugin highlight coverage. `package.preload` hack решается перемещением theme файла в `lua/lualine/themes/environment_x.lua`.

---

## S9. REFERENCE IMPLEMENTATIONS

### S9.1 Fix: `autocmds.lua` guard path

**File:** `lua/core/autocmds.lua`, line 117

```lua
-- BEFORE (broken):
local ok, guard = pcall(require, "lib.guard")

-- AFTER (correct):
local ok, guard = pcall(require, "core.lib.guard")
```

### S9.2 Fix: Telemetry opt-in only

**File:** `lua/core/lib/telemetry.lua`

```lua
local timer = nil
local MAX_ENTRIES = 1000

function M.start()
  if timer then return end
  local last_tick = vim.uv.hrtime()
  timer = vim.uv.new_timer()
  timer:start(100, 100, vim.schedule_wrap(function()
    local now = vim.uv.hrtime()
    local delta_ms = (now - last_tick) / 1e6
    if delta_ms > 116 then
      if #metrics.ui_lag >= MAX_ENTRIES then
        table.remove(metrics.ui_lag, 1)
      end
      table.insert(metrics.ui_lag, delta_ms - 100)
      metrics.frames_dropped = metrics.frames_dropped + 1
    end
    last_tick = vim.uv.hrtime()
  end))
  vim.notify("Telemetry started", vim.log.levels.INFO)
end

function M.stop()
  if timer then
    timer:stop()
    timer:close()
    timer = nil
    vim.notify("Telemetry stopped", vim.log.levels.INFO)
  end
end

-- Remove M.setup() auto-start; replace with commands only:
vim.api.nvim_create_user_command("CoreTelemetryStart", M.start, {})
vim.api.nvim_create_user_command("CoreTelemetryStop", M.stop, {})
```

Then in `init.lua`, remove the `core.lib.telemetry` auto-setup from the UIEnter block.

### S9.3 Fix: Conform whitespace ownership

**File:** `lua/core/autocmds.lua` — удалить `BufWritePre` trim

```lua
-- DELETE this block entirely:
-- vim.api.nvim_create_autocmd("BufWritePre", {
--   pattern = "*",
--   callback = function()
--     local save_cursor = vim.fn.getpos(".")
--     vim.cmd([[%s/\s\+$//e]])
--     vim.fn.setpos(".", save_cursor)
--   end,
-- })
```

**File:** `lua/plugins/coding.lua` — Conform owns all whitespace:

```lua
formatters_by_ft = {
  ["_"] = { "trim_whitespace", "trim_newlines" },
  -- ... per-ft formatters
}
```

### S9.4 Feature: Biome conditional formatter

**File:** `lua/plugins/coding.lua`, Conform `formatters_by_ft`

```lua
javascript = function(bufnr)
  if require("conform").get_formatter_info("biome", bufnr).available then
    return { "biome" }
  end
  return { "prettier" }
end,
typescript = function(bufnr)
  if require("conform").get_formatter_info("biome", bufnr).available then
    return { "biome" }
  end
  return { "prettier" }
end,
json = function(bufnr)
  if require("conform").get_formatter_info("biome", bufnr).available then
    return { "biome" }
  end
  return { "prettier" }
end,
```

### S9.5 Feature: Selene linter

**File:** `lua/plugins/quality.lua`, nvim-lint `linters_by_ft`

```lua
-- Add conditional selene for Lua:
lua = { "selene" },

-- In nvim-lint config, add condition:
local lint = require("lint")
lint.linters.selene.condition = function(ctx)
  return vim.fs.find("selene.toml", { path = ctx.filename, upward = true })[1]
end
```

### S9.6 Feature: Lualine theme relocation

**Move:** `package.preload` hack → proper module file

```
# Create directory:
mkdir -p lua/lualine/themes/

# Extract theme table from colors/environment-x.lua
# into lua/lualine/themes/environment_x.lua as a proper module:
-- lua/lualine/themes/environment_x.lua
return {
  normal   = { ... },
  insert   = { ... },
  visual   = { ... },
  replace  = { ... },
  command  = { ... },
  inactive = { ... },
}
```

Then delete the `package.preload["lualine.themes.environment_x"]` block from `colors/environment-x.lua`.

---

## S10. PERFORMANCE FINDINGS

| Priority | Finding / evidence | Root cause | Fix / validation |
|---|---|---|---|
| **High** | 45.327ms current startup; `core.lazy` 36.373ms elapsed | imported spec graph and stale variants | consolidate specs; 20× cold/warm startuptime |
| **High** | 100ms forever timer in `core/lib/telemetry.lua:21-30` | telemetry always starts UIEnter | command-scoped collector; prove zero timer after idle |
| **High** | large-file protection never loads | `require("lib.guard")` at `autocmds.lua:117` | use `core.lib.guard`; open 2-MiB fixture and inspect flags |
| **Medium** | parser install happens on interactive file opening | `treesitter.install(missing)` | explicit provisioning; measure first-open latency |
| **Medium** | save does two broad mutations | core trim plus Conform | retain one owner; trace BufWritePre/Post |
| **Medium** | dashboard cursor loop + workspace scan | legacy `ui-dash__` | retain one minimal dashboard; no CursorMoved controller |
| **Low** | UI animations | Snacks scroll/indent enabled | keep only after measured UX decision |

---

## S11. x0r_old MIGRATION RECOMMENDATIONS

### High Value — migrate

| Компонент | Источник в x0r_old | Target в новом конфиге | Status |
|---|---|---|---|
| `highlight-undo.nvim` | `extras/ui/highlight-undo.lua` | `coding.lua` (P6-01) | ❌ Отсутствует |
| `nvim-highlight-colors` | `extras/ui/highlight-colors.lua` | `ui-theme.lua` (P6-02) | ❌ Отсутствует |
| `rainbow-delimiters.nvim` | `extras/ui/rainbow-delimeters.lua` | `syntax.lua` (P6-03) | ❌ Отсутствует |
| Biome formatter | `extras/linting/biome.lua` | `coding.lua` Conform (P6-04) | ❌ Отсутствует |
| Selene linter | `extras/linting/selene.lua` | `quality.lua` nvim-lint (P6-05) | ❌ Отсутствует |
| Tab/S-Tab block nav | `config/keymaps.lua` | `core/keymaps.lua` (P6-06) | ❌ Отсутствует |
| `No information available` filter | noice config | `ui-messages.lua` (P6-07) | ❌ Отсутствует |

### Medium Value — evaluate

| Компонент | Ценность | Рекомендация |
|---|---|---|
| `kitty-scrollback.nvim` | Навигация scrollback Kitty через Neovim | **Evaluate** — ценно только для Kitty users |
| `mise.nvim` | Tool version management integration | **Evaluate** — если mise используется |
| `modicator.nvim` | Mode-aware line number colors | **Skip** — эстетическое, не функциональное |

### Skip — already covered or low value

| Компонент | Причина пропуска |
|---|---|
| IDE-style clipboard (`<C-a>`, `<C-c>`, `<C-v>`) | Конфликтует с Vim idioms; `unnamedplus` настроен |
| `<Leader>dl` line duplication | Тривиален, `yyp` native |
| Dashboard extended (ASCII art) | Snacks dashboard уже реализован |
| smart-splits.nvim | Уже есть в terminal.lua |
| yazi.nvim | Уже есть в explorer.lua |

---

## S12. PRINCIPAL ARCHITECTURE VERDICT

### Confirmed strengths

1. Native LSP model (`vim.lsp.config`/`vim.lsp.enable`) — эталонный для Neovim 0.12
2. Domain separation — чётко выраженные границы ответственности
3. Deterministic lockfile — 62 pinned commits, checker disabled
4. Buffer-local ftplugins — correct separation of concerns
5. Deferred clipboard/foldexpr — intelligent startup optimization
6. `vim.loader.enable()` as first instruction — correct
7. Provider suppression early — correct

### Confirmed weaknesses

1. **4 Snacks fragments with fragmented capability ownership** — highest structural risk
2. **Broken guard path** — large-file protection silently fails everywhere
3. **Phantom fzf-lua dependency** — runtime errors on worktree/TODO commands
4. **Permanent 100ms telemetry timer** — contradicts zero-overhead model
5. **Dual whitespace cleanup** — core trim + Conform, redundant mutation
6. **3 dashboard variants in import tree** — filename accident determines behavior
7. **`_G` pollution** — `core_wk_groups`, `_diff_*` — hidden cross-domain coupling
8. **Missing Kitty/Tmux audit** — half the workstation stack is unverified
9. **No CI verification harness** — no automated regression detection
10. **612-LOC statusline** — potential redraw overhead, unmeasured

### Target engineering characteristics (post-remediation)

```
Startup:            ≤ 20ms headless (cold), ≤ 15ms (warm)
Idle timers:        0
Background polling: 0
LSP model:          vim.lsp.config + vim.lsp.enable (native)
Picker:             Snacks.picker (single canonical)
Explorer:           Neo-tree (primary) + Oil (edit) + Yazi (TUI)
Dashboard:          One file, one spec, no CursorMoved loop
Telemetry:          Command-scoped, bounded, opt-in
Supply chain:       100% SHA-pinned, no auto-install in normal operation
Secrets:            0 plaintext, AI diff capped/redacted
Config permissions: 0700 dirs, 0600 sensitive files
Domain count:       23 files in plugins/ (all populated, all named per README)
```

---

## S13. UPSTREAM EVIDENCE CONSULTED

- [Neovim LSP documentation](https://neovim.io/doc/user/lsp.html): `vim.lsp.config()` and `vim.lsp.enable()` — current configuration/activation model
- [nvim-treesitter README](https://github.com/nvim-treesitter/nvim-treesitter/blob/main/README.md): current rewrite incompatible with old API, requires Neovim 0.12+, lazy-loading unsupported
- [lazy.nvim documentation](https://github.com/folke/lazy.nvim/blob/main/doc/lazy.nvim.txt): import/merge and trigger semantics; `opts` preferred over `config`
- [Snacks README](https://github.com/folke/snacks.nvim): modules are one plugin capability set; supports core/dashboard/notifier/picker
- [blink.cmp docs](https://github.com/Saghen/blink.cmp/blob/main/doc/blink-cmp.txt): Rust fuzzy matcher; release-tag binary provisioning; v2 is breaking
- [Conform recipes](https://github.com/stevearc/conform.nvim/blob/master/doc/recipes.md): async manual formatting; save-format lifecycle
- [CodeCompanion documentation](https://github.com/olimorris/codecompanion.nvim/blob/main/doc/codecompanion.txt): MCP servers start on first chat, not editor startup
- [Mason registry migration](https://github.com/mason-org/mason.nvim): `williamboman/mason.nvim` → `mason-org/mason.nvim`
