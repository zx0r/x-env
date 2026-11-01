-- ftplugin/rust.lua — Rust-specific overrides
-- rustaceanvim handles LSP | cargo integration

if vim.b.did_ftplugin then return end
vim.b.did_ftplugin = 1

vim.opt_local.tabstop    = 4
vim.opt_local.shiftwidth = 4
vim.opt_local.expandtab  = true
vim.opt_local.textwidth  = 100  -- Rust style guide: 100 chars

-- Rustfmt compatibility
vim.opt_local.formatoptions:remove({ "c", "r", "o" })

local function truncate_output(str, limit)
  limit = limit or 1024
  if not str or str == "" then return "" end
  if #str > limit then
    return str:sub(1, limit) .. "\n... [truncated]"
  end
  return str
end

local function get_rust_root()
  return vim.fs.root(0, { "Cargo.toml", ".git" }) or vim.fn.getcwd()
end

-- Cargo run shortcut
vim.keymap.set("n", "<leader>cr", function()
  vim.system({ "cargo", "run" }, { cwd = get_rust_root(), text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        vim.notify(truncate_output(res.stderr or "cargo run failed"), vim.log.levels.ERROR, { title = "cargo" })
      else
        vim.notify(truncate_output(res.stdout or "Done"), vim.log.levels.INFO, { title = "cargo run" })
      end
    end)
  end)
end, { buffer = true, desc = "Cargo run" })

vim.keymap.set("n", "<leader>ct", function()
  vim.system({ "cargo", "test" }, { cwd = get_rust_root(), text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        vim.notify(truncate_output(res.stderr or "cargo test failed"), vim.log.levels.ERROR, { title = "cargo" })
      else
        vim.notify("Cargo test passed", vim.log.levels.INFO, { title = "cargo test" })
      end
    end)
  end)
end, { buffer = true, desc = "Cargo test" })

vim.keymap.set("n", "<leader>cb", function()
  vim.system({ "cargo", "build", "--release" }, { cwd = get_rust_root(), text = true }, function(res)
    vim.schedule(function()
      local level = res.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
      local msg = res.code == 0 and "Build successful" or truncate_output(res.stderr or "Build failed")
      vim.notify(msg, level, { title = "cargo build" })
    end)
  end)
end, { buffer = true, desc = "Cargo build --release" })

local undo = "setlocal tabstop< shiftwidth< expandtab< textwidth< formatoptions<"
  .. " | sil! nunmap <buffer> <leader>cr"
  .. " | sil! nunmap <buffer> <leader>ct"
  .. " | sil! nunmap <buffer> <leader>cb"
vim.b.undo_ftplugin = (vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. " | ") or "") .. undo
