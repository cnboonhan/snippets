-- Remember the window and tab layout, per directory. nvim already persists
-- undo ('undofile') and marks/registers/history (shada); this adds the part it
-- does not: which buffers were open and how they were arranged.
local M = {}

local aug = vim.api.nvim_create_augroup("user.session", { clear = true })

local dir = vim.fn.stdpath("state") .. "/sessions"

-- One session per working directory, named after it the way nvim names undo
-- files, so unrelated projects never share a layout.
local function session_file()
    return ("%s/%s.vim"):format(dir, (vim.fn.getcwd():gsub("/", "%%")))
end

-- Only worth saving if a real file was opened; otherwise a stray `nvim` in a
-- directory would overwrite a good layout with an empty one.
local function has_file_buffer()
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[b].buflisted and vim.bo[b].buftype == ""
            and vim.api.nvim_buf_get_name(b) ~= "" then
            return true
        end
    end
    return false
end

function M.save()
    if not has_file_buffer() then
        return false
    end
    vim.fn.mkdir(dir, "p")
    vim.cmd("mksession! " .. vim.fn.fnameescape(session_file()))
    return true
end

function M.restore()
    local f = session_file()
    if vim.fn.filereadable(f) == 0 then
        return false
    end
    vim.cmd("silent source " .. vim.fn.fnameescape(f))
    -- 'terminal' is in the default sessionoptions, so nvim brings terminal
    -- windows back and restarts their shells. Hand them to the terminal module
    -- so the panel keys manage them rather than ignoring them.
    pcall(require("terminal").adopt)
    return true
end

-- Headless runs (scripts, setup.sh's bootstrap) must neither save nor restore:
-- they would clobber the layout of a real session.
local function interactive()
    return #vim.api.nvim_list_uis() > 0
end

vim.api.nvim_create_autocmd("VimLeavePre", {
    group = aug,
    desc = "Save this directory's session",
    callback = function()
        if interactive() then
            pcall(M.save)
        end
    end,
})

vim.api.nvim_create_autocmd("VimEnter", {
    group = aug,
    desc = "Restore this directory's session when started bare",
    -- nested so sourcing the session fires BufRead and friends, which is what
    -- gets LSP and treesitter attached to the restored buffers.
    nested = true,
    callback = function()
        -- `nvim foo.py` should open foo.py, not a remembered layout.
        if interactive() and vim.fn.argc() == 0 then
            pcall(M.restore)
        end
    end,
})

vim.api.nvim_create_user_command("SessionRestore", function()
    if not M.restore() then
        vim.notify("no saved session for " .. vim.fn.getcwd(), vim.log.levels.WARN)
    end
end, { desc = "Restore this directory's saved session" })

return M
