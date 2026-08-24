-- One reusable bottom-split terminal, plus send-line/selection-to-it.
-- Uses only built-in APIs: :terminal, chansend(), getregion().
local M = {}

local HEIGHT = 15
local state = { buf = nil, win = nil }

-- A terminal buffer keeps its job channel in 'channel'; it drops to 0 once
-- the shell exits, which is how we tell a dead terminal from a live one.
local function alive()
    return state.buf
        and vim.api.nvim_buf_is_valid(state.buf)
        and vim.bo[state.buf].channel ~= 0
end

local function visible()
    return state.win
        and vim.api.nvim_win_is_valid(state.win)
        and vim.api.nvim_win_get_buf(state.win) == state.buf
end

-- Park the cursor on the last line: terminal buffers only follow new output
-- while the cursor sits at the bottom.
local function follow()
    if visible() then
        local last = vim.api.nvim_buf_line_count(state.buf)
        pcall(vim.api.nvim_win_set_cursor, state.win, { last, 0 })
    end
end

-- Show the terminal, creating it on first use or after the shell exited.
-- With keep_focus, the cursor stays in the window you came from.
local function open(keep_focus)
    local prev = vim.api.nvim_get_current_win()

    vim.cmd("botright " .. HEIGHT .. "split")
    state.win = vim.api.nvim_get_current_win()

    if alive() then
        vim.api.nvim_win_set_buf(state.win, state.buf)
    else
        vim.cmd("terminal")
        state.buf = vim.api.nvim_get_current_buf()
        vim.bo[state.buf].buflisted = false
    end

    vim.wo[state.win].number = false
    vim.wo[state.win].relativenumber = false
    vim.wo[state.win].signcolumn = "no"
    follow()

    if keep_focus then
        vim.api.nvim_set_current_win(prev)
    else
        -- Land ready to type: a terminal buffer opens in Normal mode, where
        -- keystrokes are motions rather than shell input.
        vim.cmd("startinsert")
    end
end

function M.toggle()
    if visible() then
        vim.api.nvim_win_close(state.win, false) -- hide; the shell keeps running
        state.win = nil
    else
        open(false)
    end
end

-- The visual selection, or the current line when not in visual mode.
-- Must run before any window juggling, which would drop visual mode.
local function payload()
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" or mode == "\22" then
        local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
        vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
        return lines
    end
    return { vim.api.nvim_get_current_line() }
end

-- Bring the terminal up if needed, then hand it raw bytes.
local function deliver(text)
    if not visible() then
        open(true)
    end
    if not alive() then
        vim.notify("terminal shell is not running", vim.log.levels.WARN)
        return
    end
    vim.fn.chansend(vim.bo[state.buf].channel, text)
    vim.schedule(follow) -- output arrives async
end

function M.send()
    -- The trailing newline is what makes the shell execute the last line.
    deliver(table.concat(payload(), "\n") .. "\n")
end

-- The same gesture, but sending a `path:line` reference instead of the code,
-- so an agent running in the terminal can look at exactly what you are
-- looking at. Deliberately no trailing newline: the reference lands in the
-- prompt for you to type around instead of being submitted on its own.
function M.send_ref()
    if vim.bo.buftype ~= "" then
        return vim.notify("not a file buffer", vim.log.levels.WARN)
    end
    local path = vim.fn.expand("%:.") -- relative to cwd, which agents prefer
    if path == "" then
        return vim.notify("buffer has no file name", vim.log.levels.WARN)
    end

    local mode = vim.fn.mode()
    local ref
    if mode == "v" or mode == "V" or mode == "\22" then
        local first, last = vim.fn.getpos("v")[2], vim.fn.getpos(".")[2]
        if first > last then
            first, last = last, first
        end
        vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
        ref = first == last and ("%s:%d"):format(path, first)
            or ("%s:%d-%d"):format(path, first, last)
    else
        ref = ("%s:%d"):format(path, vim.api.nvim_win_get_cursor(0)[1])
    end

    deliver(ref .. " ")
end

return M
