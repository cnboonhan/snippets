-- Two independent terminals: one down the side, one along the bottom. Each
-- keeps its own shell, so a REPL can sit in one while you run commands in the
-- other. Built on :terminal and chansend(); nothing else needed.
local M = {}

local HEIGHT = 15
local WIDTH = 80

-- Each tabpage gets its own pair, so a tab is a self-contained workspace with
-- its own two shells rather than sharing them with every other tab.
local per_tab = {}

local function slot(name)
    local tab = vim.api.nvim_get_current_tabpage()
    per_tab[tab] = per_tab[tab] or {
        right = { vertical = true },
        bottom = { vertical = false },
    }
    return per_tab[tab][name] or per_tab[tab].right
end

-- A closed tab's shells would otherwise linger as hidden buffers with live
-- processes, so reap them along with the tab.
local function reap_closed_tabs()
    for tab, pair in pairs(per_tab) do
        if not vim.api.nvim_tabpage_is_valid(tab) then
            for _, one in pairs(pair) do
                if one.buf and vim.api.nvim_buf_is_valid(one.buf) then
                    pcall(vim.api.nvim_buf_delete, one.buf, { force = true })
                end
            end
            per_tab[tab] = nil
        end
    end
end

-- A terminal buffer keeps its job channel in 'channel'; it drops to 0 once the
-- shell exits, which is how we tell a dead terminal from a live one.
local function alive(s)
    return s.buf and vim.api.nvim_buf_is_valid(s.buf) and vim.bo[s.buf].channel ~= 0
end

-- Visible in this tab. The tabpage check is belt and braces now that state is
-- per tab, but a stale window id from a closed tab would otherwise look valid.
local function visible(s)
    return s.win
        and vim.api.nvim_win_is_valid(s.win)
        and vim.api.nvim_win_get_tabpage(s.win) == vim.api.nvim_get_current_tabpage()
        and vim.api.nvim_win_get_buf(s.win) == s.buf
end

-- Park the cursor on the last line: terminal buffers only follow new output
-- while the cursor sits at the bottom.
local function follow(s)
    if visible(s) then
        pcall(vim.api.nvim_win_set_cursor, s.win, { vim.api.nvim_buf_line_count(s.buf), 0 })
    end
end

-- Move out of a terminal window, if we are in one, so a new split lands
-- beside the code rather than nested inside another terminal.
local function focus_editor()
    if vim.bo.buftype ~= "terminal" then
        return
    end
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.bo[vim.api.nvim_win_get_buf(w)].buftype ~= "terminal" then
            vim.api.nvim_set_current_win(w)
            return
        end
    end
end

-- Show this slot, creating its shell on first use or after the old one exited.
-- With keep_focus, the cursor stays in the window you came from.
local function open(s, keep_focus)
    local prev = vim.api.nvim_get_current_win()

    if s.vertical then
        -- botright: full height down the right edge. Never wider than half the
        -- screen, however wide WIDTH is.
        vim.cmd(("botright %dvsplit"):format(math.min(WIDTH, math.floor(vim.o.columns / 2))))
    else
        -- belowright, not botright: this splits the *current* window's space,
        -- so a side terminal keeps its full height instead of being squashed
        -- by a bottom split spanning the whole screen. Start from an editor
        -- window so the terminal lands under the code, not inside a terminal.
        focus_editor()
        vim.cmd(("belowright %dsplit"):format(HEIGHT))
    end
    s.win = vim.api.nvim_get_current_win()

    if alive(s) then
        vim.api.nvim_win_set_buf(s.win, s.buf)
    else
        vim.cmd("terminal")
        s.buf = vim.api.nvim_get_current_buf()
        vim.bo[s.buf].buflisted = false
    end

    vim.wo[s.win].number = false
    vim.wo[s.win].relativenumber = false
    vim.wo[s.win].signcolumn = "no"
    follow(s)

    if keep_focus then
        vim.api.nvim_set_current_win(prev)
    else
        -- Land ready to type: a terminal buffer opens in Normal mode, where
        -- keystrokes are motions rather than shell input.
        vim.cmd("startinsert")
    end
end

-- Each placement toggles its own shell, independently of the other.
function M.toggle(name)
    local s = slot(name)
    if visible(s) then
        vim.api.nvim_win_close(s.win, false) -- hide; the shell keeps running
        s.win = nil
        return
    end
    open(s, false)
end

-- Bring the named shell up if needed, then hand it raw bytes.
local function deliver(name, text)
    local s = slot(name)
    if not visible(s) then
        open(s, true)
    end
    if not alive(s) then
        vim.notify("terminal shell is not running", vim.log.levels.WARN)
        return
    end
    vim.fn.chansend(vim.bo[s.buf].channel, text)
    vim.schedule(function() follow(s) end)
end

-- The visual selection, or the current line when not in visual mode. Must run
-- before any window juggling, which would drop visual mode.
local function payload()
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" or mode == "\22" then
        local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
        vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
        return lines
    end
    return { vim.api.nvim_get_current_line() }
end

function M.send(name)
    -- The trailing newline is what makes the shell execute the last line.
    deliver(name, table.concat(payload(), "\n") .. "\n")
end

-- The same gesture, but sending a `path:line` reference instead of the code,
-- so an agent running in the terminal can look at exactly what you are looking
-- at. Deliberately no trailing newline: the reference lands in the prompt for
-- you to type around instead of being submitted on its own.
function M.send_ref(name)
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
        local first, last_line = vim.fn.getpos("v")[2], vim.fn.getpos(".")[2]
        if first > last_line then
            first, last_line = last_line, first
        end
        vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
        ref = first == last_line and ("%s:%d"):format(path, first)
            or ("%s:%d-%d"):format(path, first, last_line)
    else
        ref = ("%s:%d"):format(path, vim.api.nvim_win_get_cursor(0)[1])
    end

    deliver(name, ref .. " ")
end

-- Keymaps and autocommands for the above. Called from init.lua so that this
-- file owns its own bindings rather than scattering them.
function M.setup()
    local map = vim.keymap.set
    local aug = vim.api.nvim_create_augroup("user.terminal", { clear = true })

    map("n", "<leader>t", function() M.toggle("right") end,  { desc = "Toggle side terminal" })
    map("n", "<leader>T", function() M.toggle("bottom") end, { desc = "Toggle bottom terminal" })

    -- Lower case targets the side terminal, upper case the bottom one, the
    -- same shift convention as <leader>t / <leader>T.
    map({ "n", "x" }, "<leader>e", function() M.send("right") end,
        { desc = "Send line/selection to side terminal" })
    map({ "n", "x" }, "<leader>E", function() M.send("bottom") end,
        { desc = "Send line/selection to bottom terminal" })

    -- Same gesture, but sending a `path:line` reference rather than the code,
    -- so an agent in the terminal can look at what you are looking at.
    map({ "n", "x" }, "<leader>r", function() M.send_ref("right") end,
        { desc = "Send path:line reference to side terminal" })
    map({ "n", "x" }, "<leader>R", function() M.send_ref("bottom") end,
        { desc = "Send path:line reference to bottom terminal" })

    -- Window navigation straight out of terminal mode, so leaving the terminal
    -- never needs <Esc><Esc> first. This shadows four readline keys *inside the
    -- terminal only*: C-h backward-delete-char, C-j accept-line, C-k kill-line,
    -- C-l clear-screen. Drop a line here to hand any of them back to the shell.
    for _, dir in ipairs({ "h", "j", "k", "l" }) do
        map("t", "<C-" .. dir .. ">", "<C-\\><C-n><C-w>" .. dir,
            { desc = "Window " .. dir .. " (from terminal)" })
    end

    -- Entering a terminal window puts you straight into the shell, so jumping
    -- back in is symmetric with jumping out. <Esc><Esc> still gives you Normal
    -- mode for scrolling and copying output.
    vim.api.nvim_create_autocmd({ "TermOpen", "WinEnter" }, {
        group = aug,
        desc = "Enter insert mode when moving into a terminal window",
        callback = function()
            if vim.bo.buftype == "terminal" then
                vim.cmd("startinsert")
            end
        end,
    })

    vim.api.nvim_create_autocmd("TabClosed", {
        group = aug,
        desc = "Kill the terminals belonging to a closed tab",
        callback = reap_closed_tabs,
    })

    -- To hide either terminal from inside it, use <C-x> like any other window.
end

return M
