-- The three plugins, installed by the built-in vim.pack.

local map = vim.keymap.set

-- Managed by vim.pack, built into nvim 0.12 -- no third-party manager.
--   :lua vim.pack.update()   review the diff, :w to apply, :q to discard
--   :lua vim.pack.del({ "name" })                     to remove one
vim.pack.add({
    -- Fuzzy pickers. No dependencies and no external binary.
    { src = "https://github.com/echasnovski/mini.pick" },

    -- Git gutter signs and hunk staging. Same author, same lack of deps.
    { src = "https://github.com/echasnovski/mini.diff" },

    -- File explorer: navigate in columns, and do file operations by editing
    -- the buffer text and confirming. Replaces netrw for browsing.
    { src = "https://github.com/echasnovski/mini.files" },

    -- Build tool for treesitter parsers, not a runtime dependency: it
    -- compiles into site/parser, which nvim finds on its own.
    --   :lua require("nvim-treesitter").install({ "go" })
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
}, {
    -- Install without prompting: revisions are pinned in nvim-pack-lock.json
    -- and setup.sh bootstraps headlessly, where a prompt would just hang.
    confirm = false,
})

require("mini.pick").setup()

-- Gutter signs against the git index: + added, ~ changed, - deleted.
require("mini.files").setup()

require("mini.diff").setup({
    view = { style = "sign", signs = { add = "+", change = "~", delete = "-" } },
})

local pick = function(name)
    return function() require("mini.pick").builtin[name]() end
end

map("n", "<leader>f", pick("files"),     { desc = "Fuzzy: files" })
map("n", "<leader>g", pick("grep_live"), { desc = "Fuzzy: live grep" })
map("n", "<leader>b", pick("buffers"),   { desc = "Fuzzy: buffers" })
map("n", "<leader>h", pick("help"),      { desc = "Fuzzy: help tags" })

-- Git hunks: [h / ]h jump, gh is the hunk text object (ghgh, dgh, ...).
map("n", "<leader>o", function() require("mini.diff").toggle_overlay(0) end,
    { desc = "Git: toggle inline diff overlay" })
