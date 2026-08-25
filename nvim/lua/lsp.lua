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
        -- Built-in completion, triggered as you type. No plugin needed.
        vim.lsp.completion.enable(true, ev.data.client_id, ev.buf, { autotrigger = true })

        vim.keymap.set("n", "<leader>=", function()
            vim.lsp.buf.format({ async = true })
        end, { buffer = ev.buf, desc = "Format buffer" })
    end,
})
