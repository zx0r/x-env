-- ftplugin/go.lua — Go-specific overrides
-- gopls LSP | gofumpt | go test integration

if vim.b.did_ftplugin then return end
vim.b.did_ftplugin = 1

-- Go mandates tabs (not spaces)
vim.opt_local.expandtab   = false
vim.opt_local.tabstop     = 4
vim.opt_local.shiftwidth  = 4
vim.opt_local.softtabstop = 4

-- Go-specific text width (gofmt default)
vim.opt_local.textwidth = 0

local function truncate_output(str, limit)
  limit = limit or 1024
  if not str or str == "" then return "" end
  if #str > limit then
    return str:sub(1, limit) .. "\n... [truncated]"
  end
  return str
end

local function get_go_root()
  return vim.fs.root(0, { "go.mod", ".git" }) or vim.fn.getcwd()
end

-- Go commands (async via vim.system)
local function go_cmd(args, title)
  vim.system(
    vim.list_extend({ "go" }, args),
    { cwd = get_go_root(), text = true },
    function(res)
      vim.schedule(function()
        local level = res.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
        local msg   = res.code == 0
          and (res.stdout ~= "" and truncate_output(res.stdout) or "Done")
          or  (truncate_output(res.stderr) or "Failed")
        vim.notify(msg, level, { title = "go " .. title })
      end)
    end
  )
end

vim.keymap.set("n", "<leader>gr", function() go_cmd({ "run", "." }, "run") end,         { buffer = true, desc = "Go run" })
vim.keymap.set("n", "<leader>gt", function() go_cmd({ "test", "./..." }, "test") end,     { buffer = true, desc = "Go test" })
vim.keymap.set("n", "<leader>gb", function() go_cmd({ "build", "./..." }, "build") end,   { buffer = true, desc = "Go build" })
vim.keymap.set("n", "<leader>gv", function() go_cmd({ "vet", "./..." }, "vet") end,       { buffer = true, desc = "Go vet" })

local undo = "setlocal expandtab< tabstop< shiftwidth< softtabstop< textwidth<"
  .. " | sil! nunmap <buffer> <leader>gr"
  .. " | sil! nunmap <buffer> <leader>gt"
  .. " | sil! nunmap <buffer> <leader>gb"
  .. " | sil! nunmap <buffer> <leader>gv"
vim.b.undo_ftplugin = (vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. " | ") or "") .. undo
