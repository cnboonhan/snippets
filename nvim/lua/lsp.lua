-- Language servers. One table per server in lsp/<name>.lua.

local aug = vim.api.nvim_create_augroup("user.lsp", { clear = true })

-- Each server is a table in ~/.config/nvim/lsp/<name>.lua
vim.lsp.enable({ "basedpyright", "ruff", "lua_ls", "bashls" })

vim.diagnostic.config({
    virtual_text = { prefix = "●" },
    severity_sort = true,
    float = { source = true },
})

vim.api.nvim_create_autocmd("LspAttach", {
    group = aug,
    desc = "Per-buffer LSP setup",
    callback = function(ev)
        -- Built-in completion. autotrigger only fires on the server's
        -- triggerCharacters -- for basedpyright those are . [ " ' -- so it
        -- covers `foo.` but never a bare identifier. The autocommand below
        -- fills that gap.
        vim.lsp.completion.enable(true, ev.data.client_id, ev.buf, { autotrigger = true })

        vim.keymap.set("i", "<C-Space>", vim.lsp.completion.get,
            { buffer = ev.buf, desc = "Trigger completion" })

        vim.keymap.set("n", "<leader>=", function()
            vim.lsp.buf.format({ async = true })
        end, { buffer = ev.buf, desc = "Format buffer" })
    end,
})

-- Ask for completion while typing a word, which no trigger character covers.
-- Guarded so it neither fights an open menu nor fires in buffers without a
-- server that can answer.
vim.api.nvim_create_autocmd("TextChangedI", {
    group = aug,
    desc = "Trigger LSP completion while typing an identifier",
    callback = function()
        if vim.fn.pumvisible() == 1 then
            return
        end
        local clients = vim.lsp.get_clients({ bufnr = 0, method = "textDocument/completion" })
        if not next(clients) then
            return
        end
        -- Two word characters immediately before the cursor: enough to be
        -- worth asking, few enough to still feel immediate.
        local col = vim.api.nvim_win_get_cursor(0)[2]
        if vim.api.nvim_get_current_line():sub(1, col):match("[%w_][%w_]$") then
            vim.lsp.completion.get()
        end
    end,
})
