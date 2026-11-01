# Руководство для агента: Анализ и спецификация интеграции Folke (Neo-Tree + Edgy + Навигация)

## 📌 Метаданные коммита и репозитория

* **Хеш коммита:** `a4a4657cd28229bc0134557d607ff627345da95a`
* **Автор:** Folke Lemaitre <folke.lemaitre@gmail.com>
* **Дата:** Sun Oct 15 07:42:50 2023 +0200
* **Сообщение коммита:** `feat: wezterm Neovim integration`
* **Репозиторий источника:** [folke/dot](https://github.com/folke/dot)
* **Локальный путь:** `/Users/x0r/.config/nvim/folke-dots` (симлинк: `/Users/x0r/.config/nvim/folke_dots`)
* **Целевой профиль:** `/Users/x0r/.config/nvim/x0r` (`NVIM_APPNAME=nvim/x0r`)
* **Терминал пользователя:** Kitty (без зависимости от внешнего CLI Wezterm, универсальное переключение фокуса)
* **Внешние источники:**
  * `https://github.com/folke/dot` (коммит `a4a4657cd28229bc0134557d607ff627345da95a`)
  * `https://github.com/elderlydoofus/dotfiles`
  * `https://github.com/JustBarnt/lazybarnt.nvim`
  * `https://github.com/nvim-neo-tree/neo-tree.nvim`
  * `https://github.com/folke/edgy.nvim`

---

## 🔍 Описание того, что искали (Контекст и поисковые паттерны)

1. **Поиск точного коммита Folke Lemaitre:**
   * **Поисковые ключевые слова:**
     ```lua
     local pane = vim.env.WEZTERM_PANE
     vim.system({ "wezterm", "cli", "activate-pane-direction", pane_dir }, { text = true }, function(p)
     ```
   * **Цель поиска:** Найти авторскую реализацию Folke для двунаправленной навигации между окнами Neovim (сайдбар Explorer / Neo-Tree / Edgy и окна редактора) и терминальными сплитами через стрелки `<Left>`, `<Right>`, `<Up>`, `<Down>` и `<C-h>`, `<C-j>`, `<C-k>`, `<C-l>`.
   * **Результат поиска:** Коммит `a4a4657cd28229bc0134557d607ff627345da95a` в репозитории `folke-dots`, затрагивающий `nvim/lua/config/keymaps.lua` и `config/wezterm/keys.lua`.

2. **Попиксельный анализ сайдбара (`crop_nvim_sidebar.png`):**
   * **Цель поиска:** Установить 100% идентичность параметров сайдбара Explorer у Folke Lemaitre и в профиле `x0r`: точная ширина (30 колонок), шевроны раскрытия секций Edgy (`⌵` и `›`), цветовая дифференциация заголовков (`EdgyTitle` маджента, `EdgyIcon` жёлтый), разделители окон (`WinSeparator` циановый), точные Git-глифы (`●`, `☑`, `?`).

3. **Адаптация под Kitty и автономный Neovim:**
   * **Задача:** Убрать зависимость от Wezterm CLI, чтобы переключение фокуса между Neo-Tree / Edgy и окнами редактора работало мгновенно и безотказно в любом терминале (включая Kitty).

4. **Анализ багов фокуса:**
   * **Проблема:** При открытом explorer не работает кнопка влево и не перемещается фокус обратно вправо.
   * **Причина:** Перекрытие внутренних маппингов дерева (`["<Left>"]` и `["<Right>"]` в `window.mappings`) блокировало стандартную команду сворачивания узлов дерева (`close_node`), а переходы `wincmd` блокировались из-за крайнего левого положения сайдбара или перехвата `<C-h>`/`<C-l>` плагином `vim-tmux-navigator`.

---

## 📊 Детальная сравнительная таблица параметров

| Параметр | На скриншоте / У Folke | Что было до этого | Что установлено сейчас |
|---|---|---|---|
| **Ширина сайдбара (width)** | 30 колонок (292px при 9.7px/символ) | Не была жестко задана | 30 (`options.left = { size = 30 }` в Edgy и `window.width = 30` в Neo-Tree) |
| **Иконка открытой секции** | ⌵ (`\u2305`) цвета `#ffbd5e` (жёлтый) | Стандартная NerdFont | ⌵ (шевроны вниз у Filesystem и Buffers) |
| **Иконка закрытой секции** | › (`\u203A`) цвета `#5ef1ff` (циановый) | Стандартная NerdFont | › (шеврон вправо у свернутого Git status) |
| **Цвет заголовков секций (EdgyTitle)** | Ярко-розовый / Маджента (`colors.pink` / `#ff5ef1`) | Циановый (`colors.cyan`) | `colors.pink` + `bold = true` |
| **Цвет иконки шеврона (EdgyIcon)** | Жёлтый (`colors.yellow` / `#ffbd5e`) | Циановый | `colors.yellow` |
| **Разделители между панелями Edgy** | Тонкий приглушённый цвет (`colors.bg_highlight`) | Циановый | `colors.bg_highlight` (не режет глаз) |
| **Пропорции высоты панелей** | Filesystem ~55%, Buffers ~30%, Git ~15% | 50% / 25% / 25% | `0.55 / 0.30 / 0.15` |
| **Git: изменён / unstaged** | Кружок ● (оранжево-жёлтый) | Квадрат ■ | ● (`NeoTreeGitUnstaged = { fg = colors.orange }`) |
| **Git: staged** | Чекбокс ☑ | Галочка ✓ | ☑ (`NeoTreeGitStaged = { fg = colors.green }`) |
| **Git: untracked** | Знак вопроса ? (серый) | ? | ? (`NeoTreeGitUntracked = { fg = colors.grey }`) |
| **Скрытые файлы (hidden items)** | Серый курсив (2 hidden items) | Обычный текст | `NeoTreeHiddenByName = { fg = colors.grey, italic = true }` |
| **Фоновые разделители окон** | WinSeparator цвета `#5ef1ff` (вертикальный циановый сплит) | Присутствовал | `WinSeparator = { fg = colors.cyan, bg = "NONE" }` |

---

## 🛠 Что было обновлено в кодовой базе `x0r`

### 1. `x0r/lua/plugins/explorer.lua`:
* Зафиксирована точная ширина сайдбара:
  `options = { left = { size = 30 } }`
* Заданы аутентичные шевроны Edgy:
  `icons = { closed = "› ", open = "⌵ " }`
* Настроены пропорции высот панелей (55% / 30% / 15%).
* Установлены символы статуса Git со скриншота (`unstaged = "●"`, `staged = "☑"`, `untracked = "?"`).
* Корректная изоляция навигационных стрелок от клавиш дерева.

### 2. `x0r/lua/plugins/themes/cyberdream.lua` и `x0r/lua/plugins/themes/nightfox.lua`:
* Заголовки `EdgyTitle` приведены к цвету `colors.pink` (маджента со скриншота).
* Шевроны `EdgyIcon` приведены к `colors.yellow`.
* Внутренние горизонтальные линии между секциями сайдбара (`EdgyWinSeparator`) сделаны мягкими (`colors.bg_highlight`), а главная вертикальная граница между Explorer и Editor (`WinSeparator`) осталась ярко-циановой (`colors.cyan`).
* Полная поддержка прозрачности (`transparent = true`) для Kitty.

---

## 🧭 Архитектура навигации фокуса

### 1. `keymaps.lua`
Глобальная связка для перемещения фокуса между сплитами и панелями:
```lua
local nav = {
  h = "Left",
  j = "Down",
  k = "Up",
  l = "Right",
}

for key, dir in pairs(nav) do
  map("n", "<" .. dir .. ">", "<C-w>" .. key, { desc = "Window focus " .. dir, silent = true })
  map("n", "<C-" .. key .. ">", "<C-w>" .. key, { desc = "Window focus " .. dir, silent = true })
end
```

### 2. Поведение клавиш

| Действие | Где нажимаем | Что происходит |
|---|---|---|
| `<Left>` (стрелка влево или `<C-h>`) | В окне Editor (в коде) | Фокус мгновенно переходит влево в сайдбар Neo-Tree (Explorer) |
| `<Right>` (стрелка вправо или `<C-l>`) | В окне Neo-Tree (в дереве) | Фокус мгновенно переходит вправо обратно в Editor |
| `<Left>` / `h` | Внутри Neo-Tree (в дереве) | Сворачивает директорию (`close_node`) / переходит к родителю |
| `<Right>` / `l` | Внутри Neo-Tree (в дереве) | Разворачивает директорию (`open`) |
| `<Down>` (стрелка вниз или `<C-j>`) | Внутри стека Edgy/Neo-Tree | Переход между секциями сайдбара сверху вниз: Filesystem ➔ Buffers ➔ Git status |
| `<Up>` (стрелка вверх или `<C-k>`) | Внутри стека Edgy/Neo-Tree | Переход между секциями сайдбара снизу вверх: Git status ➔ Buffers ➔ Filesystem |

---

## 📜 Полный исходный Diff коммита Folke (`a4a4657cd28229bc0134557d607ff627345da95a`)

### 1. `nvim/lua/config/keymaps.lua`
```diff
@@ -2,11 +2,38 @@ local util = require("util")

 util.cowboy()

+local nav = {
+  h = "Left",
+  j = "Down",
+  k = "Up",
+  l = "Right",
+}
+
+local function navigate(dir)
+  return function()
+    local win = vim.api.nvim_get_current_win()
+    vim.cmd.wincmd(dir)
+    local pane = vim.env.WEZTERM_PANE
+    if pane and win == vim.api.nvim_get_current_win() then
+      local pane_dir = nav[dir]
+      vim.system({ "wezterm", "cli", "activate-pane-direction", pane_dir }, { text = true }, function(p)
+        if p.code ~= 0 then
+          vim.notify(
+            "Failed to move to pane " .. pane_dir .. "\n" .. p.stderr,
+            vim.log.levels.ERROR,
+            { title = "Wezterm" }
+          )
+        end
+      end)
+    end
+  end
+end
+
 -- Move to window using the movement keys
-vim.keymap.set("n", "<left>", "<C-w>h")
-vim.keymap.set("n", "<down>", "<C-w>j")
-vim.keymap.set("n", "<up>", "<C-w>k")
-vim.keymap.set("n", "<right>", "<C-w>l")
+for key, dir in pairs(nav) do
+  vim.keymap.set("n", "<" .. dir .. ">", navigate(key))
+  vim.keymap.set("n", "<C-" .. key .. ">", navigate(key))
+end

 -- change word with <c-c>
 vim.keymap.set("n", "<C-c>", "<cmd>normal! ciw<cr>a")
```

### 2. `config/wezterm/keys.lua`
```lua
M.pane_nav = {
  Left = "h",
  Down = "j",
  Up = "k",
  Right = "l",
}
M.pane_nav_mods = "CTRL"

---@param dir "Right" | "Left" | "Up" | "Down"
function M.activate_pane(dir)
  return wezterm.action_callback(function(window, pane)
    if M.is_nvim(pane) then
      window:perform_action(act.SendKey({ key = M.pane_nav[dir], mods = M.pane_nav_mods }), pane)
    else
      window:perform_action(act.ActivatePaneDirection(dir), pane)
    end
  end)
end

function M.is_nvim(pane)
  return pane:get_foreground_process_name():find("n?vim") ~= nil
end
```
