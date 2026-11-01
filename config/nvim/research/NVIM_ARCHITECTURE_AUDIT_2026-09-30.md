# Neovim x0r — архитектурный аудит

**Дата:** 2026-09-30 (Asia/Ho_Chi_Minh)  
**Конфигурация:** `/Users/x0r/.config/nvim/x0r`  
**Рабочее дерево:** незакоммиченные изменения поверх `4a7452f` (`chore(audit): save state before remediation`)  
**Правило:** «zero overhead» означает ноль *необоснованной* runtime-нагрузки, а не ноль кода или плагинов.

## Методика и границы

Проверены реальный XDG-запуск, lockfile, lazy.nvim merged spec, filesystem, статические ссылки, локальные инструменты и upstream-документация. Конфигурация во время аудита не изменялась. Сравнение сделано с `4a7452f`, поскольку это последний коммит непосредственно перед текущим незакоммиченным рефакторингом. Он сам неработоспособен: `lua/plugins/language.lua:507` содержит синтаксическую ошибку (пропущен `end`), поэтому его показатели запуска — не валидная baseline-архитектура.

# 1. EXECUTIVE ARCHITECTURE SUMMARY

**Текущее состояние.** Конфиг перешёл от прежнего монолита (`ui.lua`, `lsp.lua`, `formatting.lua`, `dap.lua`) к понятным верхнеуровневым доменам `core/`, `plugins/`, `lsp/`, `after/ftplugin/`, `colors/`. Это верное направление. Однако refactor остановился в промежуточном состоянии: имеются параллельные владельцы `Snacks` и Neo-tree, неразрешённые ссылки на fzf-lua, пустой testing-domain, неработающий large-file guard и постоянный telemetry timer.

**Целевое состояние.** Один spec для `folke/snacks.nvim`; один spec Neo-tree; `Snacks.picker` — единственный picker; `core.lib.guard` — единый large-file policy; наблюдаемость запускается только по команде; toolchain содержит только подтверждённые потребители и их бинарники.

**Главные риски.**

- `folke/snacks.nvim` имеет 4 merged fragments; итоговый lazy cache содержит только dashboard opts. Core/notifier/picker-configuration не имеет детерминированного владельца.
- Оба файла `lua/plugins/navigation.lua` и `lua/plugins/explorer.lua` конфигурируют Neo-tree и одинаковый `<leader>e`.
- В `lua/core/autocmds.lua:117` требуется `lib.guard`, но модуль расположен по пути `core.lib.guard`; ошибка подавляется через `pcall`, поэтому защита больших файлов не работает.
- В конфигурации есть прямые `fzf-lua`/`TodoFzfLua` вызовы, но plugin spec и lock entry отсутствуют. В то же время `Snacks.picker` уже выбран в UI core, а Telescope установлен только как зависимость text-case.
- `testing.lua` формально заявляет neotest, но возвращает `{}`: тестовая архитектура отсутствует.

**Главные performance-риски.** Автоустановка парсеров при каждом первом Tree-sitter load; постоянный 100-мс libuv timer; formatting и глобальный whitespace substitution на каждом save; десятки plugin specs импортируются до определения жизненного цикла. Текущий валидный cold headless start — 45.327 ms.

**Главная модернизация.** Native LSP (`vim.lsp.config` / `vim.lsp.enable`) уже внедрён корректно. Tree-sitter code выглядит как новый API, но загружается лениво вопреки текущей upstream-рекомендации: новый rewrite прямо сообщает, что lazy-loading не поддерживается.

# 2. RUNTIME BASELINE

| Параметр | Факт |
|---|---|
| OS / CPU | macOS 27.2, Darwin arm64 (T6000) |
| Neovim | `NVIM v0.12.5`, Release |
| Lua | LuaJIT 2.1.1774638290 |
| Shell / терминал при аудите | fish / `TERM=dumb` |
| Реальный config root | `/Users/x0r/.config/nvim/x0r` только при `XDG_CONFIG_HOME=/Users/x0r/.config/nvim`, `NVIM_APPNAME=x0r` |
| Data root | `/Users/x0r/.local/share/nvim/x0r` |
| Plugin manager | lazy.nvim, 62 configured / 62 lock entries / 67 directories in data lazy root |
| Startup (current) | 45.327 ms, headless startuptime |
| Startup (baseline after temporary syntax repair) | 21.043 ms, **диагностический симулятор**, не исходный commit |
| Startup (literal `4a7452f`) | config partially starts, но `plugins.language` не парсится; сравнение недопустимо |
| Current after startup | 62 loaded Lua modules, 107 autocmds, 212 normal maps, 2 start plugins, 1 libuv handle |
| Baseline after temporary syntax repair | 59 modules, 103 autocmds, 205 normal maps, 59 lazy plugins, 3 Snacks fragments |
| LSP clients in empty headless buffer | 0, ожидаемо |

Главный синхронный блок current start — `require("core.lazy")`: 36.373 ms elapsed (из них 20.455 ms self) по `--startuptime`. Это не доказательство, что lazy.nvim «плох», но достаточный повод сначала устранить ошибочные и дублирующиеся spec fragments, а затем повторить cold/warm benchmark не менее 20 раз.

Запуск через `nvim -u /Users/x0r/.config/nvim/x0r/init.lua` **не** является корректным запуском данного репозитория: он не добавляет `x0r/lua` в Lua path. Он ошибочно сообщает `module 'core.perf' not found`. Это документировать в README/benchmark, а не принимать за проблему кода.

# 3. DOMAIN AUDIT

## 01 — Bootstrap / Entrypoint

- **Current owner:** `init.lua`, `lua/core/perf.lua`, `lua/core/lazy.lua`.
- **Current implementation:** порядок core → lazy → autocmds разумный; `vim.loader.enable()` ранний.
- **What is correct:** XDG app layout реально работает; provider suppression ранний; background updater выключен.
- **What is wrong:** bootstrap делает blocking `vim.system(...):wait()` и `getchar()` при отсутствии lazy; последующий `pcall(require, "lazy")` молча превращает отсутствие plugin manager в запуск без плагинов (`core/lazy.lua:10-32`).
- **Anti-patterns:** startup network/bootstrap path; silent dependency failure; `install.missing = true` допускает неявную установку при запуске.
- **Runtime cost / risk:** высокий только в recovery path, но это production boot failure.
- **Target / action:** сохранять fail-fast с явной ошибкой; запретить auto-install во время запуска после первичного provisioning; добавить документированную команду bootstrap.

## 02 — Core / Foundation

- **Current owner:** `core/options.lua`, `keymaps.lua`, `autocmds.lua`, `perf.lua`.
- **What is correct:** staged renames `opt/map/auto` → понятные полные имена и обновлённые imports; deterministic augroups.
- **What is wrong:** large-file hook запрашивает неверный module path; `pcall` скрывает это. `core.keymaps.lua` создаёт `_G.core_wk_groups`, а UI зависит от этой глобальной мутации. `BufWritePre` одновременно выполняет глобальный regex trim и Conform может выполнять formatter.
- **Runtime cost:** save-time `:%s/\\s\\+$//e` проходит весь модифицируемый файл на каждом save.
- **Target / action:** `require("core.lib.guard")`; передавать which-key groups через декларативный `wk.add()` в одном месте; выбрать один owner whitespace cleanup (Conform либо core, не оба).

## 03 — Plugin Management

- **Current owner:** `core/lazy.lua`, `lazy-lock.json`.
- **What is correct:** `{ import = "plugins" }`, lock commits, `checker.enabled=false`, `change_detection.enabled=false`.
- **What is wrong:** import загружает все top-level Lua specs, включая untracked `ui_dash.lua`, `ui-dash__.lua` и одновременно конфигурирующий старый dashboard. Четыре fragments по `snacks.nvim` имеют неочевидный merge/config order.
- **Risk:** high. lazy docs подтверждают, что `opts`, `dependencies`, triggers merge, но `config` — не безопасный механизм для нескольких владельцев; текущий lazy cache действительно сохранил лишь dashboard opts.
- **Target / action:** один Snacks spec; доменные files возвращают только pure `opts` fragments либо один central config, но не несколько `config()` calls. Удалить/переместить черновики из импортируемого дерева до следующего запуска.

## 04 — Language Intelligence

- **Current owner:** `plugins/language.lua`, `lsp/{lua_ls,jsonls,yamlls}.lua`, Rust — rustaceanvim.
- **What is correct:** native `vim.lsp.config("*", ...)` + `vim.lsp.enable({...})`; Rust не дублируется в native enable; server-specific overrides отделены в `lsp/`.
- **What is wrong:** literal baseline имеет parser error, исправленную только в working tree (`language.lua:506`). Комментарии ошибочно ссылаются на `after/lsp/*`, фактические files — `lsp/*`. `schemastore` требуем внутри `lsp/*.lua`, но declared dependency only on lspconfig — это допустимо, но ownership implicit.
- **Runtime cost:** LspAttach document highlight events оправданы capability check, но `CursorMoved` clear происходит на каждое движение в LSP buffer.
- **Target / action:** оставить native model; исправить paths в docs; удостовериться, что `b0o/schemastore.nvim` declared explicit dependency; оставить один LspAttach owner.

## 05 — Mason / Toolchain

- **Current owner:** `plugins/language.lua`.
- **What is correct:** Mason выступает единственным declarative installer registry; `PATH="prepend"`, auto-update disabled.
- **What is wrong:** `run_on_start=true` превращает normal editing startup в installer check. Установлены лишь 3 из 13 заявленных LSP servers на PATH (`lua-language-server`, `pyright`, `rust-analyzer`); `basedpyright`, gopls, ts LS, nil, terraform-ls, bash/yaml/docker LS, sqls, marksman отсутствуют. Debugger config требует debugpy/codelldb/js-debug, installer перечисляет только delve.
- **Target / action:** Mason installs only missing declared tools after explicit `:MasonToolsInstall`/dedicated command; согласовать each configured consumer с executable owner.

## 06 — Treesitter

- **Current owner:** `plugins/treesitter.lua`; native highlighting by Neovim.
- **What is correct:** нет legacy `nvim-treesitter.configs.setup`; large-file check существует.
- **What is wrong:** plugin loaded on `BufReadPost`/`BufNewFile`, хотя upstream rewritten nvim-treesitter говорит, что lazy-loading не supported and recommends start plugin plus `build = ':TSUpdate'`. Config scans all 46 parser names on first activation and запускает `treesitter.install(missing)`, то есть installation work попадает в interactive lifecycle.
- **Target / action:** сделать Tree-sitter start plugin only если upstream API требуется для all target buffers; parser provisioning перенести в explicit build/update task; retain native `vim.treesitter.start` FileType policy and use guard threshold consistently (1 MiB, not separate 100 MiB).

## 07 — Completion / Coding

- **Current owner:** `plugins/coding.lua`.
- **What is correct:** один engine blink.cmp; event `InsertEnter`; buffer source filters normal buffers; Rust fuzzy preference корректна для macOS arm64.
- **What is wrong:** `version="*"` follows an unbounded version while lockfile is a commit; official Blink project now separates stable v1 and breaking v2. `main`/unbounded use can change ABI and binary provisioning. Docs popup is auto-enabled at 200 ms and completion max is 200 items: measure typing cost before keeping both.
- **Target / action:** pin `version="1.*"` (or explicit intentional v2 migration with `blink.lib` package dependency); retain only needed sources and test large buffers.

## 08 — Formatting

- **Current owner:** `plugins/coding.lua` / conform.nvim.
- **What is correct:** explicit `formatters_by_ft`, guard for special/large buffers, manual format async.
- **What is wrong:** save formatting uses synchronous `format_on_save` semantics with 3000-ms timeout, while core also strips whitespace on `BufWritePre`. `_` fallback trim applies everywhere and may duplicate core mutation.
- **Target / action:** make core trim disappear and let Conform own formatting; decide deliberately between synchronous format-before-save (data integrity) and `format_after_save` (interactive latency); keep manual mapping async.

## 09 — Linting / Quality

- **Current owner:** `coding.lua` / nvim-lint; `quality.lua` is only 25 lines and contributes no policy.
- **What is correct:** guarded linting, no permanent timer, large-file skip.
- **What is wrong:** lint executes on `BufReadPost`, each `BufWritePost`, and each `InsertLeave`; Python `ruff` can overlap LSP diagnostics and Conform's Ruff formatting. `quality.lua` is a fake domain.
- **Target / action:** decide whether Ruff diagnostics owner is basedpyright/ruff LSP or nvim-lint, not both; trigger nvim-lint on save only unless measured need; fold/remove `quality.lua`.

## 10 — Diagnostics

- **Current owner:** native `vim.diagnostic.config` in `language.lua`; lualine presents summary.
- **What is correct:** native signs/virtual text/floats have one intended owner, `update_in_insert=false`.
- **What is wrong:** diagnostic producers are not deduplicated (LSP + nvim-lint + Quarto/Otter); no clear source policy per filetype.
- **Target / action:** retain native presentation, define producer matrix and disable duplicate Ruff/embedded diagnostics where they overlap.

## 11 — Debugging

- **Current owner:** `plugins/debug.lua`.
- **What is correct:** DAP and UI are key-loaded; UI opens and closes on DAP lifecycle; no startup adapter cost.
- **What is wrong:** adapters depend on missing debugpy, codelldb and js-debug; JS adapter points to a hard-coded Mason package path without provisioning it. `dapui` mapping is a dependency of nvim-dap, fine.
- **Target / action:** either add matching Mason packages to tool registry or remove unsupported adapters; validate every adapter with an actual debug session.

## 12 — Testing

- **Current owner:** nominally `plugins/testing.lua`.
- **What is correct:** debugger is kept separate.
- **What is wrong:** file returns `{}`. `neotest` is absent from specs and lockfile; comments, which-key icon rules and `FileType` list are stale references.
- **Target / action:** either remove test-domain claims/references, or add one intentional neotest spec plus adapters in this file. Do not install it merely to satisfy documentation.

## 13 — Version Control

- **Current owner:** `plugins/vcs.lua`; Gitsigns and Diffview clear owners.
- **What is correct:** Gitsigns uses buffer-local mappings; blame disabled by default; Diffview command-loaded.
- **What is wrong:** git-worktree and todo comments require fzf-lua / `TodoFzfLua`, which is absent. Thus two advertised commands fail at runtime. `watch_index=true` in Diffview is justified only while a Diffview session lives.
- **Target / action:** migrate worktree/TODO actions to Snacks picker, or explicitly introduce fzf-lua as canonical picker (not recommended because Snacks already owns `vim.ui.select`).

## 14 — Navigation

- **Current owner:** `navigation.lua` should own Flash/Harpoon only.
- **What is correct:** Flash and Harpoon are capability-lazy.
- **What is wrong:** it also contains a full Neo-tree spec, while `explorer.lua` owns another Neo-tree spec. Global arrow key remaps in core alter normal editing and lazy-load smart-splits at an edge.
- **Target / action:** remove Neo-tree from `navigation.lua`; keep navigation to motions/pins; retain arrows only if user deliberately wants window navigation, otherwise use conventional `<C-hjkl>`.

## 15 — Explorer / Filesystem

- **Current owner:** should be `plugins/explorer.lua`.
- **What is correct:** Neo-tree, Oil and Yazi can be distinct workflows only if roles are documented; Neo-tree uses explicit dependencies.
- **What is wrong:** duplicate Neo-tree spec and mappings; watcher enabled with no scale policy; complex `_G._diff_Node`/`_G._diff_Name` state has no lifetime boundary.
- **Target / action:** Neo-tree canonical sidebar, Oil edit-directory tool, Yazi external TUI only; replace globals with buffer-local or module-local state; no third primary explorer.

## 16 — Picker

- **Current owner:** intended `Snacks.picker` in `ui-core.lua`.
- **What is correct:** `vim.ui.select`/`vim.ui.input` intended to route through Snacks.
- **What is wrong:** old fzf-lua calls remain; Telescope is pulled only for text-case; dashboard variants disagree on picker. No explicit picker-domain contract.
- **Target / action:** canonicalize Snacks picker, migrate fzf Lua calls, and keep Telescope only as `text-case.nvim` dependency if that plugin needs its extension API.

## 17 — Terminal

- **Current owner:** `core/keymaps.lua` creates native terminals; `terminal.lua` owns smart-splits.
- **What is correct:** no terminal starts at startup.
- **What is wrong:** documentation says terminal domain owns terminal UI, but it contains only smart-splits; Snacks terminal is configured in ui-core and native terminal mappings remain in core.
- **Target / action:** declare native terminal canonical and move only terminal-local maps there, or declare Snacks terminal canonical and remove native split mappings. Do not keep ambiguous owners.

## 18 — Data / Database / Notebooks

- **Current owner:** `data.lua`.
- **What is correct:** Molten, image rendering and Dadbod are demand-loaded; terminal capability is checked before image provider.
- **What is wrong:** Molten loads for generic Markdown, overlapping Quarto/Render-Markdown; remote-plugin build has external side effects and needs reproducible documented prerequisites.
- **Target / action:** keep Molten to explicit commands or notebook-relevant fts; preserve Dadbod split; document Python/Jupyter and image backend prerequisites.

## 19 — Markdown / R&D

- **Current owner:** untracked `plugins/markdown.lua`.
- **What is correct:** Quarto, Otter and Render-Markdown have coherent intended responsibilities and lock entries were added.
- **What is wrong:** untracked file already enters automatic import; Quarto activates for every Markdown buffer and can overlap Molten/Otter diagnostics. No `after/ftplugin/markdown.lua` for strictly buffer-local policy.
- **Target / action:** decide whether ordinary Markdown needs Quarto; use `after/ftplugin/markdown.lua` for wrap/spell/render opt-in; retain Quarto only for `quarto`/Rmd workflow or explicit activation.

## 20 — AI / MCP

- **Current owner:** `ai.lua`.
- **What is correct:** no secrets in source; env variable names only; command/key lazy policy; current CodeCompanion supports MCP and can start servers on first chat, not startup.
- **What is wrong:** commit-message prompt calls `vim.system(...):wait()` in an interactive action. This is acceptable only with bounded diff size/timeout; current code captures arbitrary staged diff into a remote LLM prompt.
- **Target / action:** confirm user intent before sending diffs; cap/redact large or secret-like staged content; keep MCP only explicit-chat activated.

## 21 — Infrastructure

- **Current owner:** `infra.lua` is effectively empty (26 lines).
- **What is correct:** Terraform tooling currently sits in language/coding where execution ownership is clear.
- **What is wrong:** fake domain increases map surface without capability.
- **Target / action:** delete `infra.lua` until it owns a real, separate workflow, or place only infrastructure-specific commands there.

## 22 — UI Core

- **Current owner:** `ui-core.lua` should own generic Snacks primitives.
- **What is correct:** statuscolumn/bigfile/input/zen/picker classification is sensible.
- **What is wrong:** it is one of four eager Snacks specs; enables scroll/indent animations by default, counter to zero-unjustified-overhead until visual value is measured.
- **Target / action:** merge as data into sole Snacks owner; disable continuous scroll animation unless explicitly desired.

## 23 — UI Dashboard

- **Current owner:** ambiguous among deleted tracked `ui-dash.lua`, untracked `ui_dash.lua` and untracked `ui-dash__.lua`.
- **What is correct:** new `ui_dash.lua` moves calls toward `Snacks.picker` and uses scoped augroup.
- **What is wrong:** all variants are in import directory; old variant contains `_G._x0r_dashboards`, CursorMoved cursor-lock logic, fzf-lua actions and heavy workspace scanning. Runtime cache selects dashboard options from one fragment, not an intentional contract.
- **Target / action:** choose exactly one file named `ui-dashboard.lua` (or retain `ui-dash.lua`), delete/archive other variants outside `lua/plugins/`; scan workspace only when dashboard opens; no global state or CursorMoved snap loop.

## 24 — UI Notifications

- **Current owner:** intended `ui-notify.lua`/Snacks notifier.
- **What is correct:** one intended backend, stable LSP progress id.
- **What is wrong:** separate eager Snacks config means its notifier opts are not reliably part of final config; `vim.notify` override runs at startup and LSP spinner recomputes on each progress event.
- **Target / action:** incorporate notifier opts in canonical Snacks spec; retain a single `vim.notify` override after `Snacks.setup`.

## 25 — UI Status

- **Current owner:** `ui-status.lua` / lualine.
- **What is correct:** uses native diagnostics and lualine components, no shell calls.
- **What is wrong:** status theme is 612 LOC and duplicates palette semantics present in colorscheme; search, LSP status and Git diff recompute on redraw.
- **Target / action:** keep lualine as sole statusline, source palette from colorscheme and measure redraw hot paths before adding features.

## 26 — UI View

- **Current owner:** split across Edgy, Neo-tree, DAP UI, Snacks picker/dashboard.
- **What is correct:** components are lazy by feature.
- **What is wrong:** Edgy is optional through `pcall` in explorer; layout behavior changes depending on load order. No declared layout owner.
- **Target / action:** decide whether Edgy is required integration or remove its branch; make all sidebar placement flow through the selected layout owner.

## 27 — UI Which-Key

- **Current owner:** `ui-whichkey.lua`.
- **What is correct:** plugin presents maps rather than defines most maps; UIEnter load is reasonable.
- **What is wrong:** `_G.core_wk_groups` coupling; icons refer to fzf-lua/neotest not configured.
- **Target / action:** local module export / static `wk.add`; remove stale plugin rules.

## 28 — UX

- **Current owner:** `ui-ux.lua`.
- **What is correct:** visual plugins are event/key triggered.
- **What is wrong:** several enhancements overlap native/Tree-sitter presentation and no capability budget exists.
- **Target / action:** retain only features used weekly; benchmark rainbow/context/highlight plugins on large buffers.

## 29 — Theme / Styling

- **Current owner:** `colors/environment-x.lua`, `ui-styler.lua`, `ui-theme.lua`.
- **What is correct:** `colors/` is source of actual schemes; styler is isolated.
- **What is wrong:** `environment-x.lua` contains `package.preload["lualine.themes.environment_x"]`; `nightfox.lua` mutates `package.preload` and `package.loaded`. These are hidden runtime coupling/monkey patches. 23 colorscheme files are present, but no explicit active colorscheme declaration was proven.
- **Target / action:** define lualine theme as regular module or use lualine's documented theme hook; delete package monkey patches; choose one active scheme in one start spec.

## 30 — Filetype / after/ftplugin

- **Current owner:** `after/ftplugin/{go,python,rust}.lua`.
- **What is correct:** language indentation and commands are buffer-local; external commands async.
- **What is wrong:** Python venv scans four paths on every Python buffer; Rust/Go test/build maps overlap a future testing domain; markdown filetype policy is global and lacks ftplugin.
- **Target / action:** keep true local settings here; move test runner workflow to testing; add markdown ftplugin only if needed.

## 31 — Security

- **Current owner:** `options.lua`, `ai.lua`, `core/lib/secops.lua`.
- **What is correct:** `exrc=false`, `modelineexpr=false`, no observed source secret.
- **What is wrong:** `modeline=true` is a conscious remaining project-input surface; AI staged diff action has data egress risk; automatic plugin installation is supply-chain mutation at editor startup.
- **Target / action:** set `modeline=false` unless required; cap/redact AI diff context; explicit package update/install workflow only.

## 32 — Performance / Startup

- **Current owner:** `perf.lua`, lazy settings, benchmark script.
- **What is correct:** 2 start plugins at headless startup (lazy + Snacks); no LSP client; update checker off.
- **What is wrong:** 45.327 ms exceeds project 20-ms SLA; `core.lazy` is primary phase. `benchmark.py` still asserts old renamed/deleted modules and reports impossible metrics (e.g. 224492 Lua LOC), so it cannot be the quality gate.
- **Target / action:** fix benchmark paths/count algorithm before performance claims; baseline 20 cold + 20 warm runs; list plugin load times using `:Lazy profile`.

## 33 — Observability

- **Current owner:** `core/lib/{bench,telemetry,health}.lua`.
- **What is correct:** health/bench are explicit modules; no permanent verbose log proven.
- **What is wrong:** telemetry starts a permanent 100-ms timer after every UIEnter and retains unbounded metric arrays. This directly violates stated zero-overhead model. Health references obsolete `lib.guard`, roles removed from repo, fzf-lua and black.
- **Target / action:** make telemetry command-scoped with stop/close and bounded ring buffers; repair health paths and delete role checks; update benchmark only after architecture stabilizes.

## 34 — Reproducibility

- **Current owner:** `lazy-lock.json`, Mason registry, external PATH.
- **What is correct:** lockfile has 62 pinned commit entries; checker off.
- **What is wrong:** 4 untracked plugin files are executable specs but not captured by committed design; tree-sitter parsers, Mason tools, Blink fuzzy binary and build tools are not lock-pinned; `version="*"` creates drift.
- **Target / action:** commit one coherent spec tree and lockfile; document generated/built dependencies; pin Blink v1 or execute tested v2 migration.

## 35 — Architectural Coherence

- **Current graph:** `init → core → lazy import plugins → domain specs → lazy handlers → runtime services`.
- **Strength:** native LSP and `lsp/` boundary follow the intended direction.
- **Broken edges:** `core.autocmds → lib.guard` (nonexistent); `vcs/ui-dash__ → fzf-lua` (no spec); `navigation ↔ explorer` duplicate Neo-tree; 4 UI domains mutate one Snacks plugin; `ui-whichkey ← _G.core_wk_groups`; `explorer ← _G._diff_*`.
- **Target / action:** eliminate globals and resolve each edge through an explicit plugin dependency or native API.

# 4. DOMAIN OWNERSHIP MATRIX

| Responsibility | Current owner | Desired owner | Duplicate / missing | Action |
|---|---|---|---|---|
| bootstrap/options/maps/autocmds | core | core | guard path broken | repair module path |
| plugin manager | lazy | lazy | auto-install side effect | explicit provisioning |
| LSP/server overrides | language + lsp | language + lsp | docs path drift | retain/fix docs |
| Mason/toolchain | language | language | DAP tools absent | align registry |
| Treesitter | treesitter | treesitter | install-on-open | provision separately |
| completion/format/lint | coding | coding | Ruff overlap | producer policy |
| diagnostics | language/native | native | multiple producers | source matrix |
| debugging | debug | debug | adapters absent | install or remove configs |
| testing | testing | testing | empty/no neotest | delete or implement |
| explorer | navigation + explorer | explorer | two Neo-tree specs | remove from navigation |
| picker | Snacks + Telescope + stale fzf | Snacks | fzf unavailable | migrate calls |
| terminal | core + Snacks + smart-splits | explicit native or Snacks | unclear | choose one UI owner |
| markdown/notebooks | data + markdown | separate, opt-in | generic markdown overlap | narrow ft triggers |
| Snacks UI | four files | one spec + data fragments | config order | consolidate |
| dashboard | 3 variants | one file | imports all | retain one |
| notifications | ui-notify | canonical Snacks spec | opts dropped | merge |
| status/theme | lualine/colors | lualine + colors | package patches | remove hacks |
| observability | core.lib | command-scoped | permanent timer | opt-in only |

# 5. PLUGIN INVENTORY

62 lock entries are present. Full commit inventory is `lazy-lock.json`; the architecture-relevant inventory is below.

| Plugin / capability | Domain | Trigger | Status / action |
|---|---|---|---|
| lazy.nvim | core | start | keep; disable implicit install after bootstrap |
| Snacks | UI core/dashboard/notify | **4 start fragments** | consolidate to exactly one spec |
| nvim-lspconfig | language | BufReadPre/NewFile | keep native API model |
| rustaceanvim | language | rust ft | keep canonical Rust owner |
| Mason + tool installer | toolchain | module/default | remove `run_on_start`; reconcile tools |
| nvim-treesitter + textobjects/context | Treesitter | buffer events | follow rewrite’s non-lazy guidance |
| blink.cmp + friendly snippets | coding | InsertEnter | pin stable v1 or perform v2 migration |
| conform + nvim-lint | coding | save/read/insert leave | keep with de-duplicated producer policy |
| nvim-dap + dap-ui + nio | debug | keys | keep; provision declared adapters |
| Neo-tree + Oil + Yazi | explorer | cmd/keys | retain roles, remove duplicate Neo-tree spec |
| Telescope | text-case dependency | key | retain only for required extension, not picker policy |
| fzf-lua | **absent** | referenced | migrate to Snacks; do not add by default |
| Quarto/Otter/Render-Markdown | markdown | markdown/quarto ft | commit intentionally; constrain generic Markdown load |
| Molten/image/Dadbod | data | ft/cmd | keep demand-loaded |
| CodeCompanion/MCPHub | AI | cmd/keys | keep explicit-use; cap staged diff |
| lualine/which-key/styler | UI | UIEnter/events | keep one owner each |
| neotest/adapters | **absent** | none | add only if tests are a real workflow |

## Отсутствующие или необеспеченные плагины / компоненты

| Missing item | Evidence | Canonical file for remediation | Recommendation |
|---|---|---|---|
| `ibhagwan/fzf-lua` | `vcs.lua:345,392`, `ui-dash__.lua:200,1124,1138,1145`, health and which-key mention it; no spec/lock entry | `lua/plugins/vcs.lua`, selected dashboard file | **Не добавлять по умолчанию.** Заменить на `Snacks.picker` and remove stale `TodoFzfLua`. If fzf-lua is explicitly desired, create one spec in a dedicated `lua/plugins/picker.lua` and stop claiming Snacks is canonical. |
| `nvim-neotest/neotest` and adapters | `lua/plugins/testing.lua` returns `{}`; stale references in UI/core | `lua/plugins/testing.lua` | Add only if test orchestration is required; otherwise remove stale claims and UI rules. |
| debugpy / codelldb / js-debug adapter packages | `debug.lua` configures them; only delve is in Mason install list; binaries absent | `lua/plugins/language.lua` (tool registry) + `lua/plugins/debug.lua` (consumer) | Add required Mason packages or delete unsupported adapter blocks. These are external tools, not Neovim plugins. |
| basedpyright/gopls/ts/nil/terraform/bash/yaml/docker/sqls/marksman binaries | enabled/configured but absent from PATH | `lua/plugins/language.lua` | Provision only language servers actually used, then verify with `:checkhealth vim.lsp`. |
| Quarto executable | Quarto plugin configured, `quarto` binary absent | `lua/plugins/markdown.lua` | Document external executable; disable preview/action until installed. |

# 6. API MODERNIZATION MATRIX

| Current API | Assessment | Modern API / action |
|---|---|---|
| `vim.lsp.config`, `vim.lsp.enable` | current and correct for Neovim 0.12 | retain; official Neovim docs endorse this model |
| `lsp/*.lua` runtimepath configs | current and correct | retain; correct comments from `after/lsp` to `lsp` |
| `require("nvim-treesitter").setup` + `install` | new rewrite API, but lifecycle mismatch | use current rewrite docs; no lazy load; explicit parser update |
| blink `version="*"` | unbounded release selection | stable `version="1.*"`; v2 needs `blink.lib` package dependency |
| multiple Snacks `config()` | merge-order hazard | one config call and one complete opts tree |
| `package.preload/loaded` theme hooks | hidden legacy coupling | documented lualine theme module / explicit colorscheme integration |
| `vim.system(...):wait()` at bootstrap/AI | synchronous by design | allow only explicitly bounded bootstrap/action; no silent fallback |

# 7. ANTI-PATTERN INVENTORY

| Group | Confirmed findings |
|---|---|
| Architecture | duplicate Neo-tree; duplicate dashboard; 4 Snacks owners; fake testing/infra/quality domains; globals `_G.core_wk_groups`, `_G._diff_*` |
| Startup | implicit plugin installation; bootstrap network wait; 4 eager Snacks fragments |
| Runtime | permanent 100-ms telemetry timer; CursorMoved dashboard controller; repeated LSP reference clearing; save-wide substitution |
| LSP | no old lspconfig setup found; docs path mismatch; silent large-file guard failure |
| Treesitter | install-on-open; inconsistent large-file thresholds; lazy load contrary to rewrite documentation |
| UI / theme | package preload/loaded monkey patches; config-order dependent notifier/core/dashboard |
| Picker | missing fzf-lua; Snacks/Telescope/fzf references disagree |
| Toolchain | enabled tools missing; DAP adapter configs lack installers; auto installer check at startup |
| Security | staged diff may go to remote AI; modeline enabled; auto-install mutates supply chain |
| Reproducibility | untracked imported specs; external parsers/binaries not versioned; Blink `*` |

# 8. PERFORMANCE FINDINGS

| Priority | Finding / evidence | Root cause | Fix / validation |
|---|---|---|---|
| High | 45.327-ms current startup; `core.lazy` 36.373-ms elapsed | imported spec graph and stale variants | consolidate specs; 20× cold/warm startuptime |
| High | 100-ms forever timer in `core/lib/telemetry.lua:21-30` | telemetry always starts UIEnter | command-scoped collector; prove zero timer after idle |
| High | large-file protection never loads | `require("lib.guard")` at `autocmds.lua:117` | use `core.lib.guard`; open 2-MiB fixture and inspect flags |
| Medium | parser install happens on interactive file opening | `treesitter.install(missing)` | explicit provisioning; measure first-open latency |
| Medium | save does two broad mutations | core trim plus Conform | retain one owner; trace BufWritePre/Post |
| Medium | dashboard cursor loop + workspace scan | legacy `ui-dash__` | retain one minimal dashboard; no CursorMoved controller |
| Low | UI animations | Snacks scroll/indent enabled | keep only after measured UX decision |

# 9. ZERO-OVERHEAD TARGET ARCHITECTURE

```text
init.lua
  ├─ core/perf.lua, options.lua, keymaps.lua, autocmds.lua
  └─ core/lazy.lua
       └─ import plugins
            ├─ language.lua → native LSP, Mason registry, Rust
            ├─ coding.lua → Blink, Conform, nvim-lint
            ├─ treesitter.lua → parsers/query support only
            ├─ explorer.lua → Neo-tree; Oil/Yazi explicit alternatives
            ├─ navigation.lua → Flash, Harpoon only
            ├─ ui-snacks.lua → one complete Snacks spec
            ├─ ui-status.lua / ui-whichkey.lua / ui-styler.lua / ui-ux.lua
            ├─ markdown.lua / data.lua / ai.lua / debug.lua (feature lazy)
            └─ testing.lua (only if a real test workflow exists)

lsp/*.lua                 → genuine server overrides only
after/ftplugin/*.lua      → buffer-local language behavior only
colors/*.lua              → colorschemes only
core/lib/*                → command-scoped diagnostics/benchmark helpers
```

No background telemetry. No unnamed dashboard copies inside the import directory. No fzf-lua call unless its plugin is deliberately introduced as the one canonical picker.

# 10. OPTIMIZATION PLAN

| ID | Phase / domain | File | Change | Why / validation |
|---|---|---|---|---|
| P0-01 | Stabilization | `language.lua` | commit parser `end` fix | `nvim --headless` must parse all specs |
| P0-02 | Stabilization | `autocmds.lua`, health | `core.lib.guard` path | 2-MiB fixture sets `b.large_file` |
| P0-03 | Stabilization | plugin dir | choose one dashboard, remove/archive other 2 outside import | `:Lazy` shows one Snacks fragment |
| P0-04 | Stabilization | `navigation.lua` | remove Neo-tree block | `:verbose nmap <leader>e` has one owner |
| P1-01 | Ownership | Snacks files | one `ui-snacks.lua` with complete `opts` and one config | notifier/picker/dashboard all active predictably |
| P1-02 | Ownership | `vcs.lua`, dashboard | migrate fzf-lua actions to Snacks picker | all worktree/TODO/dashboard commands resolve |
| P1-03 | Ownership | `testing.lua`, which-key | implement neotest or delete stale references | no phantom test capability |
| P2-01 | APIs | `treesitter.lua` | align lifecycle with rewrite docs | parser install not on file open |
| P2-02 | APIs | `coding.lua` | Blink stable v1 pin or v2 migration | completion tests on macOS arm64 |
| P3-01 | Lazy | `language.lua` | `run_on_start=false`; explicit tool install command | startup does no installer work |
| P3-02 | Lazy | `markdown.lua`, `data.lua` | narrow Markdown/Quarto/Molten activation | plain Markdown has no notebook cost |
| P4-01 | Runtime | telemetry | explicit start/stop, close timer, bounded storage | `uv.walk` after idle has no collector timer |
| P4-02 | Runtime | `autocmds.lua`, Conform | one whitespace/format owner | one write mutation per save |
| P5-01 | UI | theme files | delete preload/loaded patches | colorscheme/lualine renders without monkey patches |
| P6-01 | Toolchain | language/debug | reconcile servers and DAP adapters | tool availability table is 100% for enabled features |
| P7-01 | Validation | scripts/benchmark.py | update renamed paths and metrics | audited report agrees with runtime |

# 11. TARGET FILESYSTEM

```text
x0r/
├── init.lua
├── lazy-lock.json
├── colors/
│   └── environment-x.lua
├── lua/
│   ├── core/
│   │   ├── perf.lua options.lua keymaps.lua autocmds.lua lazy.lua
│   │   └── lib/{bench,guard,health,secops,telemetry}.lua
│   └── plugins/
│       ├── ai.lua coding.lua data.lua debug.lua explorer.lua
│       ├── language.lua markdown.lua navigation.lua testing.lua treesitter.lua
│       ├── ui-snacks.lua ui-status.lua ui-styler.lua ui-theme.lua ui-ux.lua ui-whichkey.lua
│       └── vcs.lua
├── lsp/{jsonls,lua_ls,yamlls}.lua
├── after/ftplugin/{go,python,rust}.lua
└── scripts/benchmark.py
```

No `ui_dash.lua`, `ui-dash__.lua`, or alternate dashboard copy remains under `lua/plugins/`. Do not create a framework or a new hierarchy merely for aesthetics.

# 12. VALIDATION MATRIX

| Change | Verification |
|---|---|
| syntax/import graph | `XDG_CONFIG_HOME=/Users/x0r/.config/nvim NVIM_APPNAME=x0r nvim --headless '+qa'` |
| one owner / map collisions | `:Lazy`, `:verbose nmap <leader>e`, `:verbose nmap <leader>gw` |
| LSP | `:checkhealth vim.lsp`; open Lua/Python/Rust and inspect `:LspInfo` |
| Tree-sitter | `:checkhealth nvim-treesitter`; `:TSUpdate`; large-file fixture |
| toolchain | `:MasonToolsInstall`, then `exepath()` matrix |
| picker migration | invoke dashboard, worktree and TODO searches with no fzf-lua error |
| formatting | save each supported filetype, inspect ConformInfo and one BufWrite trace |
| timers/processes | `vim.uv.walk`, process list while idle and after explicit feature activation |
| startup | 20 cold + 20 warm `--startuptime` runs; `:Lazy profile` |
| reproducibility | clean data/state XDG sandbox plus lockfile install |

# 13. PRINCIPAL ARCHITECTURE VERDICT

The refactor has a strong architectural direction: clear domain naming, native-first LSP, lazy feature boundaries, a lockfile, buffer-local ftplugins, and deliberate separation of LSP/formatting/linting/debugging. The present working tree is not yet an intentional production configuration because it allows editor-critical behavior to depend on filename accidents and lazy merge order. The priority is stabilization and ownership consolidation, not adding more plugins.

After one dashboard, one Snacks spec, one Neo-tree spec, repaired guard path, a chosen picker, and opt-in telemetry/tool provisioning, the configuration can credibly meet the stated engineering target: deterministic startup, explicit dependencies, capability-driven activation, and zero *unjustified* overhead.

## Upstream evidence consulted

- [Neovim LSP documentation](https://neovim.io/doc/user/lsp.html): `vim.lsp.config()` and `vim.lsp.enable()` are the current configuration/activation model.
- [nvim-treesitter README](https://github.com/nvim-treesitter/nvim-treesitter/blob/main/README.md): current rewrite is incompatible with old API, requires Neovim 0.12+, and states lazy-loading is unsupported.
- [lazy.nvim documentation](https://github.com/folke/lazy.nvim/blob/main/doc/lazy.nvim.txt): import/merge and trigger semantics; `opts` is preferred over `config`.
- [Snacks README](https://github.com/folke/snacks.nvim): its modules are one plugin capability set and supports core/dashboard/notifier/picker explicitly.
- [blink.cmp docs](https://github.com/Saghen/blink.cmp/blob/main/doc/blink-cmp.txt): Rust fuzzy matcher behavior and release-tag binary provisioning; project README identifies v2 as breaking.
- [Conform recipes](https://github.com/stevearc/conform.nvim/blob/master/doc/recipes.md): async manual formatting and save-format lifecycle.
- [CodeCompanion documentation](https://github.com/olimorris/codecompanion.nvim/blob/main/doc/codecompanion.txt): MCP servers start on first chat rather than editor startup.
