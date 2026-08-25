-- Treesitter highlighting for the parsers that are installed.

local aug = vim.api.nvim_create_augroup("user.treesitter", { clear = true })

-- nvim 0.12 bundles parsers for c, lua, markdown, vim, vimdoc and query,
-- and auto-starts only Markdown. Turn on the rest. Python's parser is not
-- bundled; it was built by nvim-treesitter into stdpath("data")/site/parser,
-- which is on the runtimepath, so highlighting works without the plugin.
vim.api.nvim_create_autocmd("FileType", {
    group = aug,
    pattern = { "c", "lua", "vim", "query", "python" },
    desc = "Treesitter highlighting for bundled parsers",
    callback = function() pcall(vim.treesitter.start) end,
})
