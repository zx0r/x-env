---
schema: "mdd-node-v1"
id: "CONFD_ARCHITECTURE_AUDIT.md"
title: "Semantic & Ontological Architecture Audit: conf.d Subsystem"
layer: "Documentation / Architecture"
responsibility: "Records findings, ontological contradictions, and refinement roadmap for conf.d modular topology"
dependencies: ["conf.d/*"]
backlinks: ["README.md", "config.fish"]
created_at: "2026-10-04"
updated_at: "2026-10-04"
tags: ["architecture", "audit", "conf.d", "ontology", "semantics", "refinement"]
---

# Архитектурно-Онтологический Аудит `conf.d/`

**Роль:** Principal Architect & Senior UX/UI Engineer  
**Объект аудита:** Модульный конвейер инициализации `~/.config/fish/conf.d/` (`00-xdg` → `50-fzf`)  
**Дата аудита:** 2026-10-04  
**Текущий SLA старта:** $10.9\text{ ms} \pm 0.8\text{ ms}$ (Apple Silicon, Zero-Fork)

---

## 1. Резюме аудита

Текущая декадная архитектура (`00–59`) функционально доказала свою экстремальную эффективность (холодный старт интерактивной оболочки стабильно $<11\text{ ms}$ при нулевом количестве форков внешних процессов на критическом пути). 

Однако в текущей реализации прототипа присутствуют **5 критических онтологических и семантических противоречий**:
1. Раздвоение состояния и переменных инструмента FZF (Split Domain State).
2. Платформенная инверсия зависимостей OpenSSL относительно Homebrew.
3. Жесткий литеральный хардкод путей Homebrew в векторизованном PATH.
4. Категориальное загрязнение домена `50-fzf.fish` сторонним генератором Tree-sitter.
5. Разрыв презентационного слоя (цвета пейджера `LESS_TERMCAP_*` в базовых переменных).

---

## 2. Онтологическая карта слоев и топология исполнения

Fish Shell 4.x оценивает конфигурационные файлы в каталоге `~/.config/fish/conf.d/` в строгом лексикографическом (ASCII) порядке перед выполнением главного файла `config.fish`.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       BOOT SEQUENCE & DOMAIN TOPOLOGY                       │
└─────────────────────────────────────────────────────────────────────────────┘
  00–09  FOUNDATION (Субстрат окружения и ОС)
         ├── 00-xdg.fish            [XDG спецификация, ~/x таксономия, Vendor Guard]
         ├── 01-variables.fish      [Системный Substrate, Core Env, Locales, Git]
         ├── 02-brew.fish           [Статическая изоляция Homebrew, TLS, CA-store]
         └── 03-path.fish           [Векторизованная санация PATH, Mise shims, AOT]
  ───────────────────────────────────────────────────────────────────────────
  10–19  INFRASTRUCTURE & SECURITY (Среды выполнения и идентификация)
         ├── 10-runtimes.fish       [JIT/SWR кэш-фронтенд: Starship, Zoxide, Atuin]
         └── 11-identity-agent.fish [Tier 1 Cryptographic Identity: Secretive SEP]
  ───────────────────────────────────────────────────────────────────────────
  20–29  COMMANDS & ERGONOMICS (Синтаксический сахар)
         └── 20-abbr.fish           [Реестр аббревиатур через ленивый промпт-хук]
  ───────────────────────────────────────────────────────────────────────────
  30–39  PRESENTATION & UI (Визуальный слой терминала)
         └── 30-ux.fish             [Палитра ZX0R, синтаксис, Vi-курсоры, цвета]
  ───────────────────────────────────────────────────────────────────────────
  40–49  INPUT & INTERACTION (Ввод и биндинги)
         └── 40-keymaps.fish        [Vi-режим, буфер обмена, привязка CLI-виджетов]
  ───────────────────────────────────────────────────────────────────────────
  50–59  TOOLING & INTEGRATIONS (Инструментарий и расширения)
         └── 50-fzf.fish            [Конфигурация Fuzzy Finder подсистемы]
```

---

## 3. Детальный разбор выявленных противоречий

### Противоречие 1: Раздвоение домена FZF (Split Domain State)
* **Локация:** `conf.d/01-variables.fish` (строки 243–246) vs `conf.d/50-fzf.fish` (строки 20–89).
* **Суть дефекта:**
  Команды интеграции с утилитой `fd`:
  ```fish
  set -gx FZF_CD_COMMAND "fd -t d"
  set -gx FZF_OPEN_COMMAND "fd -H -t f"
  set -gx FZF_FIND_FILE_COMMAND "fd -t f"
  set -gx FZF_CD_WITH_HIDDEN_COMMAND "fd -H -t d"
  ```
  объявлены в `01-variables.fish` внутри отложенного обработчика `__x_init_interactive_vars --on-event fish_prompt`.
  В то же время основной блок конфигурации FZF (`FZF_DEFAULT_OPTS`, `FZF_PREVIEW_OPTS`, `FZF_SEARCH_MODE`, `FZF_GENERAL_OPTS`, `FZF_COLOR_OPTS`) вычисляется синхронно при чтении `50-fzf.fish`.
* **Архитектурный конфликт:**
  - Нарушение Single Responsibility Principle (SRP): конфигурация инструмента разорвана между Foundation Layer (01) и Tooling Layer (50).
  - Временной рассинхрон жизненного цикла: при запуске интерактивного виджета до первого вызова `fish_prompt` или в нестандартных субоболочках переменные `FZF_*_COMMAND` окажутся неэкспортированными.
* **Решение:** Консолидировать 100% переменных FZF внутри `conf.d/50-fzf.fish`.

---

### Противоречие 2: Платформенная инверсия зависимостей OpenSSL
* **Локация:** `conf.d/01-variables.fish` (строки 83–90) vs `conf.d/02-brew.fish`.
* **Суть дефекта:**
  В `01-variables.fish` присутствуют флаги компилятора и линковщика:
  ```fish
  set -gx OPENSSL_PREFIX /opt/homebrew/opt/openssl@3
  set -gx OPENSSL_INCDIR "$OPENSSL_PREFIX/include"
  set -gx OPENSSL_LIBDIR "$OPENSSL_PREFIX/lib"
  set -gx OPENSSL_DIR "$OPENSSL_PREFIX"
  set -gx LDFLAGS "-L$OPENSSL_LIBDIR"
  set -gx CPPFLAGS "-I$OPENSSL_INCDIR"
  set -gx PKG_CONFIG_PATH "$OPENSSL_LIBDIR/pkgconfig"
  ```
  При этом `01-variables.fish` исполняется **до** `02-brew.fish`. В комментариях `01-variables.fish` (строки 79–80) зафиксировано:
  > *Note: Homebrew-specific network and TLS hardening (Brewed Curl, CA Certificates) is isolated in conf.d/02-brew.fish to guarantee correct prefix resolution order.*
* **Архитектурный конфликт:**
  Пакет `openssl@3` — это сторонняя зависимость Homebrew, а не встроенный компонент macOS. `01-variables.fish` вынужден жестко зашивать путь `/opt/homebrew`. При запуске на архитектуре x86_64 (`/usr/local`) или нестандартном префиксе переменные сломаются.
* **Решение:** Перенести блок OpenSSL в `conf.d/02-brew.fish`, где уже вычислен динамический `$HOMEBREW_PREFIX` и сконфигурированы `ca-certificates` и `curl`.

---

### Противоречие 3: Жесткий хардкод префикса в `conf.d/03-path.fish`
* **Локация:** `conf.d/03-path.fish` (строка 34 и строка 40).
* **Суть дефекта:**
  ```fish
  set -l prepend_paths "$mise_shims_dir" "$XDG_BIN_HOME" "$CURL_BIN" "$docker_bin_dir" "$BOB_HOME" "$antigravity_bin" /opt/homebrew/bin /opt/homebrew/sbin
  set -l deprecated_system_paths "$HOME/.cargo/bin" "$HOME/.gem/ruby/4.0.0/bin" /opt/homebrew/opt/ruby/bin
  ```
* **Архитектурный конфликт:**
  Файл `03-path.fish` в своем front-matter явно декларирует зависимость: `dependencies: [..., "conf.d/02-brew.fish"]`. Файл `02-brew.fish` уже экспортирует проверенную переменную `$HOMEBREW_PREFIX`. Использование жестких литералов `/opt/homebrew/bin` и `/opt/homebrew/sbin` вместо `"$HOMEBREW_PREFIX/bin"` и `"$HOMEBREW_PREFIX/sbin"` нарушает контракты DRY и переносимости платформы.
* **Решение:** Заменить литералы на интерполяцию `$HOMEBREW_PREFIX`.

---

### Противоречие 4: Категориальное загрязнение `conf.d/50-fzf.fish` (Атавизм Tree-sitter)
* **Локация:** `conf.d/50-fzf.fish` (строки 95–103).
* **Суть дефекта:**
  Внутри файла с именем `50-fzf.fish` находится фоновая генерация комплишенов сторонней утилиты `tree-sitter`:
  ```fish
  if not test -f "$XDG_CONFIG_HOME/fish/completions/tree-sitter.fish"
      if type -q tree-sitter; and test -n "$XDG_CONFIG_HOME"
          command mkdir -p "$XDG_CONFIG_HOME/fish/completions"
          tree-sitter complete --shell fish >"$XDG_CONFIG_HOME/fish/completions/tree-sitter.fish" 2>/dev/null &
      end
  end
  ```
* **Архитектурный конфликт:**
  - Файл `/Users/x0r/.config/fish/completions/tree-sitter.fish` уже статически присутствует в репозитории на диске (20 894 байта).
  - В Fish Shell автодополнения загружаются лениво по первому обращению к команде из каталога `completions/`. Никакие другие утилиты (`git`, `docker`, `mise`, `bun`) не запускают проверок в `conf.d/`.
  - Присутствие логики Tree-sitter в `50-fzf.fish` — нередуцированный артефакт старого файла `50-utils.fish`.
* **Решение:** Полностью удалить этот блок из `conf.d/50-fzf.fish`, оставив файл чистой спецификацией подсистемы FZF.

---

### Противоречие 5: Разрыв презентационного слоя (Цвета в `conf.d/01-variables.fish`)
* **Локация:** `conf.d/01-variables.fish` (строки 220–234) vs `conf.d/30-ux.fish`.
* **Суть дефекта:**
  Escape-последовательности оформления страниц руководств через утилиту `less`:
  ```fish
  set -gx LESS_TERMCAP_mb \e"[1;32m"
  set -gx LESS_TERMCAP_md \e"[1;36m"
  set -gx LESS_TERMCAP_so \e"[1;33m"
  ...
  ```
  находятся в `01-variables.fish`.
  В то же время системная палитра терминала ZX0R, подсветка синтаксиса командной строки Fish, цвета пейджера автодополнений, цвета `LS_COLORS` и `EZA_COLORS` определены в `conf.d/30-ux.fish`.
* **Архитектурный конфликт:**
  Цветовые схемы пейджеров и терминального вывода онтологически относятся к слою Presentation & UX (30–39), а не к базовому субстрату переменных ОС (01).
* **Решение:** Перенести блок `LESS_TERMCAP_*` в `conf.d/30-ux.fish` в раздел Pager & Text Display Presentation.

---

## 4. Семантика наименований файлов: конвенции

| Текущее имя | Анализ семантики | Архитектурная оценка | Решение |
| :--- | :--- | :--- | :--- |
| `00-xdg.fish` | Канонический акроним стандарта XDG | Идеальная точность | **Сохранить** |
| `01-variables.fish` | Множественное число, абстрактное имя | В Unix канонично `01-env.fish`. Однако имя `01-variables.fish` глубоко зафиксировано в 30+ исследовательских ADR и тестах. | **Сохранить имя**, очистив внутреннюю онтологию |
| `02-brew.fish` | Имя CLI-подсистемы | Кратко, точно, соответствует бинарнику `brew` | **Сохранить** |
| `03-path.fish` | Единственное число подсистемы | Канонично, соответствует стандарту | **Сохранить** |
| `10-runtimes.fish` | Домен SWR/JIT сред | Инфраструктурный слой кэширования сред | **Сохранить** |
| `11-identity-agent.fish` | Точное имя Tier 1 Hardware Identity | Отражает Secure Enclave аутентификацию | **Сохранить** |
| `20-abbr.fish` | Сокращение команды fish `abbr` | Эргономично, канонично | **Сохранить** |
| `30-ux.fish` | Общепринятый акроним UX/UI | Презентационный слой терминала | **Сохранить** |
| `40-keymaps.fish` | Термин из редакторов (в Fish — `bindings`) | Общепринятый термин для инженеров | **Сохранить** |
| `50-fzf.fish` | Имя конкретного инструмента | После удаления Tree-sitter становится 100% модулем подсистемы FZF | **Сохранить** |

---

## 5. Пошаговый план полировки (Refinement Plan)

1. **`conf.d/02-brew.fish`:**
   - Инкапсулировать блок OpenSSL (`OPENSSL_PREFIX`, `OPENSSL_INCDIR`, `OPENSSL_LIBDIR`, `OPENSSL_DIR`, `LDFLAGS`, `CPPFLAGS`, `PKG_CONFIG_PATH`).
   - Привязать пути к `$HOMEBREW_PREFIX`.
2. **`conf.d/03-path.fish`:**
   - Заменить литералы `/opt/homebrew/bin`, `/opt/homebrew/sbin`, `/opt/homebrew/opt/ruby/bin` на интерполяцию `$HOMEBREW_PREFIX`.
3. **`conf.d/50-fzf.fish`:**
   - Перенести `FZF_CD_COMMAND`, `FZF_OPEN_COMMAND`, `FZF_FIND_FILE_COMMAND`, `FZF_CD_WITH_HIDDEN_COMMAND` из `01-variables.fish`.
   - Удалить проверку и фоновую генерацию `tree-sitter`.
   - Обновить front-matter: `title: "Fzf Fuzzy Finder Subsystem"`.
4. **`conf.d/30-ux.fish`:**
   - Перенести блок `LESS_TERMCAP_*` из `01-variables.fish`.
5. **`conf.d/01-variables.fish`:**
   - Удалить блоки OpenSSL, FZF и `LESS_TERMCAP_*`.
   - Обновить front-matter (`updated_at`, `dependencies`).
6. **Верификация и бенчмаркинг:**
   - `fish -n` по всем файлам `conf.d/`.
   - `hyperfine --warmup 5 'fish -i -c exit'` (гарантия сохранения SLA $<12\text{ ms}$).
   - Фиксация в `.meta/log/changelog.md`.
