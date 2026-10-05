-- ftplugin/rust.lua — Rust-specific overrides
-- rustaceanvim handles LSP | cargo integration

vim.opt_local.tabstop    = 4
vim.opt_local.shiftwidth = 4
vim.opt_local.expandtab  = true
vim.opt_local.textwidth  = 100  -- Rust style guide: 100 chars

-- Rustfmt compatibility
vim.opt_local.formatoptions:remove({ "c", "r", "o" })

-- Cargo run shortcut
vim.keymap.set("n", "<leader>cr", function()
  vim.system({ "cargo", "run" }, { cwd = vim.fn.getcwd(), text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        vim.notify(res.stderr or "cargo run failed", vim.log.levels.ERROR, { title = "cargo" })
      else
        vim.notify(res.stdout or "Done", vim.log.levels.INFO, { title = "cargo run" })
      end
    end)
  end)
end, { buffer = true, desc = "Cargo run" })

vim.keymap.set("n", "<leader>ct", function()
  vim.system({ "cargo", "test" }, { cwd = vim.fn.getcwd(), text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        vim.notify(res.stderr or "cargo test failed", vim.log.levels.ERROR, { title = "cargo" })
      end
    end)
  end)
end, { buffer = true, desc = "Cargo test" })

vim.keymap.set("n", "<leader>cb", function()
  vim.system({ "cargo", "build", "--release" }, { cwd = vim.fn.getcwd(), text = true }, function(res)
    vim.schedule(function()
      local level = res.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
      vim.notify(
        res.code == 0 and "Build successful" or (res.stderr or "Build failed"),
        level,
        { title = "cargo build" }
      )
    end)
  end)
end, { buffer = true, desc = "Cargo build --release" })
