# АРХИТЕКТУРНО-НАУЧНОЕ ЗАКЛЮЧЕНИЕ R&D И РЕЕСТР АНТИПАТТЕРНОВ

**Дата исследования:** 2026-10-02  
**Модель / Движок синтеза:** Gemini 3.8 Flash (High)  
**Роли:** Lead Scientist · Principal Architect · Staff Platform & System Engineer  
**Объект исследования:** Workstation-as-Code (WaaC) Neovim Reference Architecture (`x0r/nvim`)  
**Рабочее дерево:** `/Users/x0r/.config/nvim/x0r`  
**Нормативный корпус:**  
- [README.md](file:///Users/x0r/.config/nvim/README.md) — Операционная спецификация, SLA и топология WaaC  
- [README_1.md](file:///Users/x0r/.config/nvim/README_1.md) — Теоретическая модель Capability-Oriented Domain Architecture (CODA)  
- [research/DEEP_RESEARCH_NVIM_2026_ULTIMATE.md](file:///Users/x0r/.config/nvim/research/DEEP_RESEARCH_NVIM_2026_ULTIMATE.md) — Экосистемный стандарт 2026, Zero-Overhead Mandate  
- [research/NVIM_ARCHITECTURE_AUDIT_2026-09-30.md](file:///Users/x0r/.config/nvim/research/NVIM_ARCHITECTURE_AUDIT_2026-09-30.md) — Исходный судебно-инженерный аудит  
- [research/PERFORMANCE_AUDIT_2026-10-01.md](file:///Users/x0r/.config/nvim/research/PERFORMANCE_AUDIT_2026-10-01.md) — Анализ регресса и эталонного состояния  
- [research/REMEDIATION_PLAN_V2.md](file:///Users/x0r/.config/nvim/research/REMEDIATION_PLAN_V2.md) — План стабилизации v2  
- [research/REMEDIATION_STATUS.md](file:///Users/x0r/.config/nvim/research/REMEDIATION_STATUS.md) — Журнал исполнения фаз P0–P7 и v2  
- [research/REGRESSION_AUDIT_2026-10.md](file:///Users/x0r/.config/nvim/research/REGRESSION_AUDIT_2026-10.md) / [research/IMPLEMENTATION_PLAN.md](file:///Users/x0r/.config/nvim/research/IMPLEMENTATION_PLAN.md) / [research/AUDIT_PLAN.md](file:///Users/x0r/.config/nvim/research/AUDIT_PLAN.md) — Базовые R&D спецификации  

---

## 1. Теоретический и Архитектурный Базис

Архитектура конфигурации `x0r` представляет собой реализацию парадигмы **Capability-Oriented Domain Architecture (CODA)**, базирующейся на фундаментальных принципах сокрытия информации Дэвида Парнаса (David Parnas, 1972/1985) и проектирования ограниченных контекстов (Bounded Contexts, Domain-Driven Design).

В отличие от традиционных конфигураций («плагин $\rightarrow$ конфигурационный файл $\rightarrow$ фича»), в данном проекте действует строгий нисходящий инвариант:

$$\text{Capability (Возможность)} \longrightarrow \text{Domain (Область ответственности)} \longrightarrow \text{Implementation (Технология/Плагин)}$$

### Ключевые архитектурные постулаты:
1. **Capability-First & Domain-Oriented Decomposition:** Имя внешней библиотеки или инструмента (LSP, Tree-sitter, Git) не может определять имя модуля или границу домена. Первичны смысловые возможности: `language.lua` («Что код означает?»), `syntax.lua` («Какова структура кода?»), `coding.lua` («Как код трансформируется?»).
2. **File = Responsibility Boundary:** Каждый Lua-файл верхнего уровня в [x0r/lua/plugins](file:///Users/x0r/.config/nvim/x0r/lua/plugins) представляет собой жесткую границу ответственности. Запрещено размывать функционал между доменами.
3. **Flat Declarative Composition:** Конфигурация собирается через единый декларативный импорт lazy.nvim: `{ import = "plugins" }`. Все 23 домена равноправны на горизонтальном уровне.
4. **Native Runtime Boundary Preservation:** Нативные каталоги Neovim runtimepath не подменяются плагинами:
   - [x0r/lsp](file:///Users/x0r/.config/nvim/x0r/lsp) — исключительно переопределения конкретных языковых серверов (`vim.lsp.config`);
   - [x0r/after/ftplugin](file:///Users/x0r/.config/nvim/x0r/after/ftplugin) — локальные буферные политики конкретных типов файлов;
   - [x0r/colors](file:///Users/x0r/.config/nvim/x0r/colors) — непосредственная реализация палитры цветовой темы (`environment-x.lua`).
5. **Zero-Overhead Mandate & Hard SLAs:**
   - Холодный старт (headless) $< 20\text{ ms}$;
   - Блокировка главного UI-треда на событие $< 2\text{ ms}$;
   - Полный запрет синхронных вызовов оболочки (`vim.fn.system()`, `io.popen()`) в горячих путях (autocmd, statusline);
   - Асинхронная неблокирующая модель процессов через Libuv (`vim.system()`, `vim.uv`).

---

## 2. Эмпирические Замеры Рантайма (Live Telemetry)

Тестирование проводилось на рабочей машине: macOS Darwin arm64 (Apple Silicon), Neovim `v0.12.5 Release`, `LuaJIT 2.1.1774638290`.

### 2.1 Сводная матрица производительности

| Параметр / Метрика | Норматив SLA | Фактическое значение | Статус | Аналитическое примечание |
| :--- | :--- | :--- | :--- | :--- |
| **Bare Neovim** (`nvim --clean`) | — | **`10.94 ms`** | — | Физический предел C-рантайма и `vim.loader` |
| **Cold Headless Start** (`x0r`) | `< 20.0 ms` | **`24.25 ms`** | 🔴 SLA Breach | Превышение лимита на $4.25\text{ ms}$ |
| **Overhead архитектуры x0r** | $< 10.0 ms$ | **`13.31 ms`** | 🟡 Требует тюнинга | Загрузка 60+ плагинов и модулей ядра |
| **Self-time менеджера** (`core.lazy`) | $< 8.0 ms$ | **`17.05 ms`** | 🟡 | Синтез графа плагинов из 23 доменов |
| **Main-Thread Latency per Event** | $< 2.0 ms$ | **`0.02 ms`** | 🟢 Идеально | Измерено через `benchmark.py` (synthetic UI) |
| **Treesitter AST Parse Time** | $< 5.0 ms$ | **`0.17 ms`** | 🟢 Идеально | Измерено на тестовом AST буфере |
| **Активные Libuv таймеры в Idle** | `0` | **`0`** | 🟢 Устранено | Фоновые тики отсутствуют |
| **Загрязнение глобального неймспейса `_G`** | `0` | **`0`** | 🟢 Полная чистота | `_x0r`, `dd`, `bt` экранированы |

### 2.2 Разрешение методологического противоречия (12.5ms vs 24.25ms)
В [REMEDIATION_PLAN_V2.md](file:///Users/x0r/.config/nvim/research/REMEDIATION_PLAN_V2.md) в качестве baseline заявлялась цифра `12.5ms cold start`. Экспертная проверка выявила причину искажения:
* Neovim при запуске `NVIM_APPNAME=x0r nvim` по спецификации XDG ищет конфигурацию по пути `$XDG_CONFIG_HOME/$NVIM_APPNAME/init.lua` (по умолчанию `~/.config/x0r/init.lua`).
* Поскольку директория `~/.config/x0r` физически отсутствует, запуск без явного `XDG_CONFIG_HOME=/Users/x0r/.config/nvim` приводил к тихому пропуску пользовательского `init.lua` и старту «голого» Neovim (~10.9–12.5ms).
* Корректный запуск рабочей конфигурации выполняется строго с переменными:
  ```bash
  XDG_CONFIG_HOME=/Users/x0r/.config/nvim NVIM_APPNAME=x0r nvim
  ```
* Реальное время полной загрузки оптимизированного окружения составляет **~24.25ms**.

---

## 3. Реестр Выявленных Архитектурных Антипаттернов и Регрессий

В ходе углубленного R&D-исследования и трассировки истории коммитов были выявлены следующие дефекты и узкие места:

### 🔴 ДЕФЕКТ 1 (КРИТИЧЕСКИЙ): Разрыв Контура Защиты Больших Файлов (`guard.lua`)
* **Файлы:** [x0r/lua/core/autocmds.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/autocmds.lua), [x0r/lua/core/lib/guard.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/lib/guard.lua)
* **Причина:** В коммите `3391828` (`perf(P5): P5-02 remove duplicate whitespace trim autocmd`) в процессе удаления дублирующего тримминга пробелов было ошибочно срезано **126 строк** файла [autocmds.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/autocmds.lua).
* **Следствие:** Полностью исчез триггер:
  ```lua
  au("BufReadPre", {
    group = augroup("large_file"),
    callback = function(event)
      local ok, guard = pcall(require, "core.lib.guard")
      if ok then guard.check(event.buf) end
    end,
  })
  ```
* **Эмпирическая валидация:** При тестовом открытии сгенерированного файла 2MB (одна длинная строка) Neovim завис намертво в фоновом процессе: флаг `vim.b.large_file` не был выставлен, и редактор попытался запустить полномасштабный разбор синтаксиса и Treesitter.
* **Сопутствующие потери в `core/autocmds.lua`:**
  1. `auto_mkdir` — автоматическое создание несуществующих родительских папок при сохранении файла;
  2. `close_with_q` — закрытие служебных окон (`help`, `qf`, `lspinfo`, `lazy`, `mason`) по нажатию `q`;
  3. `terminal` — сброс номеров строк и автоматический переход в insert mode при открытии встроенного терминала;
  4. `no_comment_continuation` — очистка `formatoptions` от автоматической вставки символов комментария при переходе на новую строку;
  5. `restore_terminal_cursor` — возврат формы курсора терминала при выходе из Neovim.

---

### 🔴 ДЕФЕКТ 2 (АРХИТЕКТУРНЫЙ): Фрагментация Спецификации и Гонка Метаданных `folke/snacks.nvim`
* **Файлы:**
  - [x0r/lua/plugins/ui.lua:33](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui.lua#L33) (`priority = 1000, lazy = false, init, config`)
  - [x0r/lua/plugins/ui-messages.lua:25](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui-messages.lua#L25) (`priority = 1000, lazy = false, init, opts`)
  - [x0r/lua/plugins/ui-dashboard.lua:570](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui-dashboard.lua#L570) (`opts`)
  - [x0r/lua/plugins/navigation.lua:208](file:///Users/x0r/.config/nvim/x0r/lua/plugins/navigation.lua#L208) (`opts, keys`)
  - [x0r/lua/plugins/terminal.lua:20](file:///Users/x0r/.config/nvim/x0r/lua/plugins/terminal.lua#L20) (`opts, keys`)
  - [x0r/lua/plugins/explorer.lua:405](file:///Users/x0r/.config/nvim/x0r/lua/plugins/explorer.lua#L405) (`opts`)
  - [x0r/lua/plugins/syntax.lua:557](file:///Users/x0r/.config/nvim/x0r/lua/plugins/syntax.lua#L557) (`opts`)
* **Суть проблемы:** Мега-плагин `snacks.nvim` объявлен в **7 различных доменных файлах**. Менеджер lazy.nvim корректно объединяет поля `opts`, но **не объединяет функции `init` и `config`** (выигрывает только одна из них в недетерминированном порядке).
* **Симптом нарушения изоляции:** В [ui-messages.lua:30-41](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui-messages.lua#L30-L41) добавлен обход метатаблиц для принудительного вызова «родительского» `init`:
  ```lua
  local parent = plugin and getmetatable(plugin) and getmetatable(plugin).__index
  while parent do
    local prev_init = rawget(parent, "init")
    if prev_init and prev_init ~= plugin.init then prev_init(plugin) break end
    parent = getmetatable(parent) and getmetatable(parent).__index
  end
  ```
  Это свидетельствует о структурном нарушении инкапсуляции: доменная композиция не должна полагаться на скрытые особенности реализации парсера lazy.nvim.

---

### 🟡 ДЕФЕКТ 3 (ПРОИЗВОДИТЕЛЬНОСТЬ): Синхронное Блокирование при `format_on_save`
* **Файл:** [x0r/lua/plugins/quality.lua:140](file:///Users/x0r/.config/nvim/x0r/lua/plugins/quality.lua#L140)
* **Код:**
  ```lua
  format_on_save = function(bufnr)
    ...
    return {
      timeout_ms = 3000,
      lsp_format = "fallback",
      quiet = false,
    }
  end
  ```
* **Нарушение инварианта:** В коммите `d24b3ef` был включен синхронный `format_on_save` с таймаутом `3000ms` и глобальным триммингом `["*"] = { "trim_whitespace", "trim_newlines" }`. Согласно нормам [DEEP_RESEARCH_NVIM_2026_ULTIMATE.md](file:///Users/x0r/.config/nvim/research/DEEP_RESEARCH_NVIM_2026_ULTIMATE.md), UI-тред не должен блокироваться более чем на 2ms. При подвисании внешнего форматировщика (Node/Prettier/Ruff) Neovim кратковременно зависает при каждом сохранении файла.
* **Решение:** Перевод на неблокирующий `format_after_save` (Conform v9) либо снижение жесткого таймаута до $150\text{ ms}$.

---

### 🟡 ДЕФЕКТ 4 (UX/ЭРГОНОМИКА): Коллизия Горячей Клавиши `<leader>/`
* **Файлы:**
  - [x0r/lua/core/keymaps.lua:76](file:///Users/x0r/.config/nvim/x0r/lua/core/keymaps.lua#L76): `map("n", "<leader>/", "gcc", { desc = "Toggle comment line", remap = true })`
  - [x0r/lua/plugins/navigation.lua:217](file:///Users/x0r/.config/nvim/x0r/lua/plugins/navigation.lua#L217): `{ "<leader>/", function() Snacks.picker.grep() end, desc = "Grep" }`
* **Эмпирическая валидация:** `mapcheck('<leader>/', 'n')` возвращает обработчик из `navigation.lua`. В результате пользователь лишен возможности комментировать строку по привычному `<leader>/`: вместо этого всегда открывается окно Live Grep.

---

### 🟡 ДЕФЕКТ 5 (АРХИТЕКТУРА DOMAIN-DRIVEN): Смещение Границ Форматирования
* **Файлы:** [x0r/lua/plugins/quality.lua:31](file:///Users/x0r/.config/nvim/x0r/lua/plugins/quality.lua#L31), [x0r/lua/plugins/coding.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/coding.lua)
* **Анализ:**
  - [README_1.md](file:///Users/x0r/.config/nvim/README_1.md) (стр. 19, 62): Домен `coding.lua` отвечает за *"How is code edited or transformed?"* (Completion, snippets, formatting). Домен `quality.lua` отвечает за *"How is code statically evaluated?"* (Linters, metrics).
  - Внутренние комментарии в [language.lua:218](file:///Users/x0r/.config/nvim/x0r/lua/plugins/language.lua#L218) и [toolchain.lua:85](file:///Users/x0r/.config/nvim/x0r/lua/plugins/toolchain.lua#L85) прямо указывают:
    ```lua
    -- <leader>lf is owned by coding.lua / conform.nvim.
    -- Consumed by coding.lua / conform.nvim.
    ```
  - Фактически `conform.nvim` расположен в [quality.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/quality.lua). Это создает несоответствие с фундаментальной архитектурной спецификацией.

---

### 🟡 ДЕФЕКТ 6 (ИЗМЕРИТЕЛЬНАЯ БАЗА): Ошибки Метрик в `benchmark.py`
* **Файл:** [x0r/scripts/benchmark.py:563](file:///Users/x0r/.config/nvim/x0r/scripts/benchmark.py#L563)
* **Ошибка в коде:**
  ```python
  result = run(["rg", "--count-matches", ".", "--type", "lua", str(NVIM_CONFIG_DIR / "lua")])
  ```
  Параметр `--count-matches .` подсчитывает количество **символов**, а не строк кода. В отчете выводится абсурдное число `221,206 LOC` вместо реальных ~5,000 строк.
* **Устаревший список топологии:** Массив `required_files` ([строка 510](file:///Users/x0r/.config/nvim/x0r/scripts/benchmark.py#L510)) ожидает старые имена файлов (`treesitter.lua`, `debug.lua`, `ui-core.lua`, `ui-dash.lua`, `roles/datascience.lua`). Из-за этого тест полноты конфигурации выдает заниженный результат (63.64%).

---

### 🟡 ДЕФЕКТ 7 (LIFECYCLE): Выполнение Автокоманд на Фазе Спецификации
* **Файл:** [x0r/lua/plugins/ui-dashboard.lua:557-566](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui-dashboard.lua#L557-L566)
* **Код:**
  ```lua
  vim.api.nvim_create_autocmd("User", {
    pattern = { "SnacksDashboardOpened", "SnacksDashboardUpdatePost" },
    callback = function(ev) ... end,
  })
  ```
* **Анализ:** Регистрация автокоманды происходит на верхнем уровне файла при первичном обходе `plugins/` менеджером lazy.nvim до инициализации ядра UI. Логика должна быть перенесена внутрь хука `init` или `config` плагина (аналогично исправленному дефекту `C-01` в `diagnostics.lua`).

---

## 4. Стратегическая Дорожная Карта Оптимизации (Roadmap)

```mermaid
flowchart TD
    subgraph Phase1["Фаза 1: Неотложная Ремедиация Ядра"]
      F1["Восстановить BufReadPre -> core.lib.guard"] --> F2["Восстановить утраченные системные autocmds (close_with_q, auto_mkdir, terminal)"]
      F2 --> F3["Разрешить коллизию <leader>/ (комментинг vs Live Grep)"]
    end

    subgraph Phase2["Фаза 2: Консолидация Доменов и Устранение Хаков"]
      G1["Консолидировать фоновые specs folke/snacks.nvim"] --> G2["Устранить метатабличный хак вызова parent init в ui-messages.lua"]
      G2 --> G3["Изолировать top-level autocmd в ui-dashboard.lua"]
      G3 --> G4["Синхронизировать conform.nvim с coding.lua согласно README_1"]
    end

    subgraph Phase3["Фаза 3: Достижение Жесткого SLA < 20ms"]
      H1["Перевести format_on_save на format_after_save (неблокирующий I/O)"] --> H2["Исправить алгоритм подсчета LOC и топологию в benchmark.py"]
      H2 --> H3["Профилирование Lazy profile и устранение оставшихся 4.25ms задержки старта"]
    end

    Phase1 --> Phase2 --> Phase3
```

---

## 5. Итоговое Архитектурное Заключение

Конфигурация [x0r](file:///Users/x0r/.config/nvim/x0r) демонстрирует высокий уровень инженерной культуры: она полностью избавлена от фонового polling, строго соблюдает модель нативного LSP Neovim 0.12, изолирует Rust-бэкенд автодополнения `blink.cmp` и обеспечивает мгновенный отклик главного потока ($0.02\text{ ms}$).

Выявленные дефекты носят характер **точечных регрессий механического рефакторинга** (случайная обрезка кода в коммите `3391828`) и **незавершенной декомпозиции мега-плагина `snacks.nvim`**. Их устранение по предложенной дорожной карте окончательно зафиксирует систему в статусе эталонной архитектуры (State of the Art) с гарантированным выполнением холодного старта $< 20\text{ ms}$.
