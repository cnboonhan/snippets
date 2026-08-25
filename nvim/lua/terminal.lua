-- Terminals, arranged as two panels per tabpage: one down the side, one along
-- the bottom. Each panel holds any number of shells that you cycle through,
-- like tabs within the panel. Built on :terminal and chansend().
local M = {}

local HEIGHT = 15
local WIDTH = 80

-- Per tabpage, so a tab is a self-contained workspace.
local per_tab = {}

local function panels()
    local tab = vim.api.nvim_get_current_tabpage()
    per_tab[tab] = per_tab[tab] or {
        right = { vertical = true, bufs = {}, cur = 1 },
        bottom = { vertical = false, bufs = {}, cur = 1 },
    }
    return per_tab[tab]
end

local function panel(name)
    local p = panels()
    return p[name] or p.right
end

-- Which panel the cursor is in, so "new" and "cycle" act on the terminal you
-- are looking at. Falls back to the side panel.
local function panel_here()
    local buf = vim.api.nvim_get_current_buf()
    for name, p in pairs(panels()) do
        for _, b in ipairs(p.bufs) do
            if b == buf then
                return name
            end
        end
    end
    return "right"
end

-- Drop shells whose process has exited. A terminal buffer keeps its job in
-- 'channel', which drops to 0 when the shell dies.
local function prune(p)
    local kept = {}
    for _, b in ipairs(p.bufs) do
        if vim.api.nvim_buf_is_valid(b) and vim.bo[b].channel ~= 0 then
            kept[#kept + 1] = b
        end
    end
    p.bufs = kept
    p.cur = math.max(1, math.min(p.cur, #kept))
end

-- Visible in this tab. The tabpage check is belt and braces now that state is
-- per tab, but a stale window id from a closed tab would otherwise look valid.
local function visible(p)
    return p.win
        and vim.api.nvim_win_is_valid(p.win)
        and vim.api.nvim_win_get_tabpage(p.win) == vim.api.nvim_get_current_tabpage()
end

-- Park the cursor on the last line: terminal buffers only follow new output
-- while the cursor sits at the bottom.
local function follow(p)
    local buf = p.bufs[p.cur]
    if visible(p) and buf then
        pcall(vim.api.nvim_win_set_cursor, p.win, { vim.api.nvim_buf_line_count(buf), 0 })
    end
end

-- A row of shell numbers along the top of the panel, current one highlighted.
-- Only worth a line of screen once there is more than one.
local function set_winbar(p)
    if not visible(p) then
        return
    end
    if #p.bufs < 2 then
        vim.wo[p.win].winbar = ""
        return
    end
    local out = {}
    for i = 1, #p.bufs do
        local label = i == p.cur and ("%#TabLineSel# " .. i .. " %#TabLine#") or (" " .. i .. " ")
        -- %<minwid>@Func@text%T makes the item clickable; the shell's index
        -- rides in minwid, which the handler reads back.
        out[#out + 1] = ("%%%d@v:lua.NvimTerminalClick@%s%%T"):format(i, label)
    end
    vim.wo[p.win].winbar = "%#TabLine#" .. table.concat(out) .. "%*"
end

-- The project's Python venv, if there is one, searching upward from the file
-- you were looking at. Sourcing the real activate script rather than poking
-- PATH keeps the prompt and `deactivate` working normally.
local function venv_activate(from_buf)
    local name = vim.api.nvim_buf_get_name(from_buf)
    local from = name ~= "" and vim.fn.fnamemodify(name, ":p:h") or vim.fn.getcwd()
    if vim.fn.isdirectory(from) == 0 then
        from = vim.fn.getcwd()
    end
    local dir = vim.fs.find({ ".venv", "venv" },
        { upward = true, type = "directory", path = from })[1]
    if not dir then
        return nil
    end
    local script = dir .. "/bin/activate"
    return vim.fn.filereadable(script) == 1 and script or nil
end

-- Move out of a terminal window, if we are in one, so a new split lands beside
-- the code rather than nested inside another terminal.
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

-- Show the panel's current shell, spawning one if that slot is empty.
-- With keep_focus, the cursor stays in the window you came from.
local function open(p, keep_focus)
    local prev = vim.api.nvim_get_current_win()
    -- Work this out now: once :terminal runs, the current buffer is term://...
    local activate = venv_activate(vim.api.nvim_get_current_buf())

    if p.vertical then
        -- botright: full height down the right edge. Never wider than half the
        -- screen, however wide WIDTH is.
        vim.cmd(("botright %dvsplit"):format(math.min(WIDTH, math.floor(vim.o.columns / 2))))
    else
        -- belowright, not botright: this splits the *current* window's space,
        -- so a side terminal keeps its full height instead of being squashed
        -- by a bottom split spanning the whole screen.
        focus_editor()
        vim.cmd(("belowright %dsplit"):format(HEIGHT))
    end
    p.win = vim.api.nvim_get_current_win()

    local buf = p.bufs[p.cur]
    if buf and vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_win_set_buf(p.win, buf)
    else
        vim.cmd("terminal")
        buf = vim.api.nvim_get_current_buf()
        vim.bo[buf].buflisted = false
        p.bufs[p.cur] = buf

        -- gt / gT select shells within this panel, mirroring how they move
        -- between tabpages elsewhere. Buffer-local, so real tab switching is
        -- untouched outside terminals. 2gt jumps straight to shell 2.
        vim.keymap.set("n", "gt", function()
            local n = vim.v.count
            if n > 0 then M.select(n) else M.cycle(1) end
        end, { buffer = buf, desc = "Next / Nth shell in this panel" })
        vim.keymap.set("n", "gT", function() M.cycle(-1) end,
            { buffer = buf, desc = "Previous shell in this panel" })
        -- Every new shell gets the same project environment, so all of them
        -- agree despite being separate processes.
        if activate then
            vim.fn.chansend(vim.bo[buf].channel,
                ("source %s\n"):format(vim.fn.shellescape(activate)))
        end
    end

    vim.wo[p.win].number = false
    vim.wo[p.win].relativenumber = false
    vim.wo[p.win].signcolumn = "no"
    set_winbar(p)
    follow(p)

    if keep_focus then
        vim.api.nvim_set_current_win(prev)
    else
        -- Land ready to type: a terminal buffer opens in Normal mode, where
        -- keystrokes are motions rather than shell input.
        vim.cmd("startinsert")
    end
end

-- Show a specific shell by its winbar number.
function M.select(n, name)
    local p = panel(name or panel_here())
    prune(p)
    if n < 1 or n > #p.bufs then
        return
    end
    p.cur = n
    if visible(p) then
        vim.api.nvim_win_set_buf(p.win, p.bufs[p.cur])
        set_winbar(p)
        follow(p)
    else
        open(p, false)
    end
end

-- Clicking a number in the winbar selects that shell. The window under the
-- mouse tells us which panel was clicked, since both can be open at once.
function _G.NvimTerminalClick(index)
    local win = vim.fn.getmousepos().winid
    for name, p in pairs(panels()) do
        if p.win == win then
            return M.select(index, name)
        end
    end
    M.select(index)
end

-- Each panel toggles independently of the other.
function M.toggle(name)
    local p = panel(name)
    prune(p)
    if visible(p) then
        vim.api.nvim_win_close(p.win, false) -- hide; the shells keep running
        p.win = nil
        return
    end
    open(p, false)
end

-- Add another shell to a panel and switch to it.
function M.new(name)
    local p = panel(name or panel_here())
    prune(p)
    p.cur = #p.bufs + 1 -- nothing at this index yet, so open() spawns one
    if p.win and vim.api.nvim_win_is_valid(p.win) then
        pcall(vim.api.nvim_win_close, p.win, false)
        p.win = nil
    end
    open(p, false)
end

-- Step through a panel's shells.
function M.cycle(delta, name)
    local p = panel(name or panel_here())
    prune(p)
    if #p.bufs < 2 then
        return vim.notify("only one shell in this panel", vim.log.levels.INFO)
    end
    p.cur = ((p.cur - 1 + delta) % #p.bufs) + 1
    if visible(p) then
        vim.api.nvim_win_set_buf(p.win, p.bufs[p.cur])
        set_winbar(p)
        follow(p)
    else
        open(p, false)
    end
end

-- A closed tab's shells would otherwise linger as hidden buffers with live
-- processes, so reap them along with the tab.
local function reap_closed_tabs()
    for tab, pair in pairs(per_tab) do
        if not vim.api.nvim_tabpage_is_valid(tab) then
            for _, p in pairs(pair) do
                for _, b in ipairs(p.bufs or {}) do
                    if vim.api.nvim_buf_is_valid(b) then
                        pcall(vim.api.nvim_buf_delete, b, { force = true })
                    end
                end
            end
            per_tab[tab] = nil
        end
    end
end

-- Bring the named panel up if needed, then hand its current shell raw bytes.
local function deliver(name, text)
    local p = panel(name)
    prune(p)
    if not visible(p) then
        open(p, true)
    end
    local buf = p.bufs[p.cur]
    if not (buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].channel ~= 0) then
        vim.notify("terminal shell is not running", vim.log.levels.WARN)
        return
    end
    vim.fn.chansend(vim.bo[buf].channel, text)
    vim.schedule(function() follow(p) end)
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

    deliver(name, ref .. " ")
end

-- Keymaps and autocommands for the above. Called from init.lua so that this
-- file owns its own bindings rather than scattering them.
function M.setup()
    local map = vim.keymap.set
    local aug = vim.api.nvim_create_augroup("user.terminal", { clear = true })

    map("n", "<leader>t", function() M.toggle("right") end, { desc = "Toggle side terminal" })
    map("n", "<leader>T", function() M.toggle("bottom") end, { desc = "Toggle bottom terminal" })

    -- These act on the panel the cursor is in, or the side panel otherwise.
    -- <leader>n also makes a new shell when you are in one; see keymaps.lua.
    map("n", "<leader>]", function() M.cycle(1) end, { desc = "Next shell in this panel" })
    map("n", "<leader>[", function() M.cycle(-1) end, { desc = "Previous shell in this panel" })

    -- Lower case targets the side panel, upper case the bottom one, the same
    -- shift convention as <leader>t / <leader>T.
    map({ "n", "x" }, "<leader>e", function() M.send("right") end,
        { desc = "Send line/selection to side terminal" })
    map({ "n", "x" }, "<leader>E", function() M.send("bottom") end,
        { desc = "Send line/selection to bottom terminal" })
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

    -- To hide either panel from inside it, use <C-x> like any other window.
end

return M
