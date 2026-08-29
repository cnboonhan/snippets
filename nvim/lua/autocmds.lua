-- Small editing conveniences.

local aug = vim.api.nvim_create_augroup("user.autocmds", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
    group = aug,
    desc = "Briefly highlight yanked text",
    callback = function() vim.hl.on_yank() end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
    group = aug,
    desc = "Trim trailing whitespace on save",
    callback = function()
        local pos = vim.api.nvim_win_get_cursor(0)
        vim.cmd([[silent! keeppatterns %s/\s\+$//e]])
        vim.api.nvim_win_set_cursor(0, pos)
    end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
    group = aug,
    desc = "Reopen files at the last cursor position",
    callback = function()
        local mark = vim.api.nvim_buf_get_mark(0, '"')
        if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(0) then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
})
