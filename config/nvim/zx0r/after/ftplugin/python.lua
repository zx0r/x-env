-- ftplugin/python.lua — Python-specific overrides
-- basedpyright + ruff | venv auto-detection | DVC integration

-- Indentation (PEP 8)
vim.opt_local.tabstop    = 4
vim.opt_local.shiftwidth = 4
vim.opt_local.expandtab  = true

-- Virtual environment auto-detection (never spawns shell synchronously)
local _venv_cache = {}
local function detect_venv()
  local root = vim.fs.root(0, { "pyproject.toml", ".git" }) or vim.fn.getcwd()
  if _venv_cache[root] ~= nil then
    return _venv_cache[root]
  end

  local candidates = {
    root .. "/.venv/bin/python",
    root .. "/venv/bin/python",
    root .. "/.env/bin/python",
    os.getenv("VIRTUAL_ENV") and (os.getenv("VIRTUAL_ENV") .. "/bin/python"),
    os.getenv("CONDA_PREFIX") and (os.getenv("CONDA_PREFIX") .. "/bin/python"),
  }
  for _, path in ipairs(candidates) do
    if path and vim.uv.fs_stat(path) then
      _venv_cache[root] = path
      return path
    end
  end
  local fallback = vim.fn.exepath("python3") or "python"
  _venv_cache[root] = fallback
  return fallback
end

vim.b.python_path = detect_venv()

-- Removed dead DVC logic (now in ftdetect/dvc.lua)

-- Folding for Python classes/functions
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr   = "v:lua.vim.treesitter.foldexpr()"
vim.opt_local.foldlevel  = 2  -- Show top-level + classes, fold methods
