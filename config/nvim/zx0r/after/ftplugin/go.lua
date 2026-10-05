-- ftplugin/go.lua — Go-specific overrides
-- gopls LSP | gofumpt | go test integration

-- Go mandates tabs (not spaces)
vim.opt_local.expandtab  = false
vim.opt_local.tabstop    = 4
vim.opt_local.shiftwidth = 4
vim.opt_local.softtabstop = 4

-- Go-specific text width (gofmt default)
vim.opt_local.textwidth = 0

-- Go commands (async via vim.system)
local function go_cmd(args, title)
  vim.system(
    vim.list_extend({ "go" }, args),
    { cwd = vim.fn.getcwd(), text = true },
    function(res)
      vim.schedule(function()
        local level = res.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
        local msg   = res.code == 0
          and (res.stdout ~= "" and res.stdout or "Done")
          or  (res.stderr or "Failed")
        vim.notify(msg, level, { title = "go " .. title })
      end)
    end
  )
end

vim.keymap.set("n", "<leader>gr", function() go_cmd({ "run", "." }, "run") end,   { buffer = true, desc = "Go run" })
vim.keymap.set("n", "<leader>gt", function() go_cmd({ "test", "./..." }, "test") end, { buffer = true, desc = "Go test" })
vim.keymap.set("n", "<leader>gb", function() go_cmd({ "build", "./..." }, "build") end, { buffer = true, desc = "Go build" })
vim.keymap.set("n", "<leader>gv", function() go_cmd({ "vet", "./..." }, "vet") end,  { buffer = true, desc = "Go vet" })
