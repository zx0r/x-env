---@type vim.lsp.Config
local M = {
  -- Restrict root detection strictly to Tailwind / PostCSS configurations.
  -- Eliminates false-positive LSP attachment in generic git repositories or markdown docs.
  root_dir = function(bufnr, on_dir)
    local ft = vim.bo[bufnr].filetype
    if ft == "markdown" or ft == "astro-markdown" or ft == "text" then
      return
    end

    local fname = vim.api.nvim_buf_get_name(bufnr)
    if fname == "" then
      return
    end

    local markers = {
      "tailwind.config.js",
      "tailwind.config.cjs",
      "tailwind.config.mjs",
      "tailwind.config.ts",
      "postcss.config.js",
      "postcss.config.cjs",
      "postcss.config.mjs",
      "postcss.config.ts",
    }

    local root = vim.fs.root(fname, markers)
    if root then
      on_dir(root)
      return
    end

    -- Support Tailwind v4 projects (explicit dependency in package.json)
    local pkg_file = vim.fs.find("package.json", { path = fname, upward = true })[1]
    if pkg_file then
      local ok, lines = pcall(vim.fn.readfile, pkg_file)
      if ok and lines then
        local content = table.concat(lines, "\n")
        if content:match('"tailwindcss"') then
          on_dir(vim.fs.dirname(pkg_file))
          return
        end
      end
    end
  end,

  -- Exclude markdown and astro-markdown from supported filetypes.
  filetypes = {
    "aspnetcorerazor",
    "astro",
    "blade",
    "clojure",
    "django-html",
    "htmldjango",
    "edge",
    "eelixir",
    "elixir",
    "ejs",
    "erb",
    "eruby",
    "gohtml",
    "gohtmltmpl",
    "haml",
    "handlebars",
    "hbs",
    "html",
    "htmlangular",
    "html-eex",
    "heex",
    "jade",
    "leaf",
    "liquid",
    "mdx",
    "mustache",
    "njk",
    "nunjucks",
    "php",
    "razor",
    "slim",
    "twig",
    "css",
    "less",
    "postcss",
    "sass",
    "scss",
    "stylus",
    "sugarss",
    "javascript",
    "javascriptreact",
    "reason",
    "rescript",
    "typescript",
    "typescriptreact",
    "vue",
    "svelte",
    "templ",
  },
}

-- Register in vim.lsp.config to override nvim-lspconfig's fallback to '.git'
vim.lsp.config("tailwindcss", M)

return M
