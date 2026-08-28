-- General keymaps. LSP keys are nvim's own defaults and are not redefined.

local map = vim.keymap.set

-- nvim 0.11+ already ships LSP keymaps: K (hover), grn (rename),
-- gra (code action), grr (references), gri (implementation),
-- gO (symbols), and ]d / [d to walk diagnostics. Don't redefine them.
local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Window navigation without the <C-w> prefix, in normal and terminal mode.
-- Ctrl+letter is a real control code (0x08 and friends), so unlike <C-,> these
-- actually reach nvim from inside a shell. They stop at the edges.
local function nav(dir)
    return function()
        if vim.bo.buftype == "terminal" then
            vim.cmd("stopinsert")
            vim.schedule(function() vim.cmd("wincmd " .. dir) end)
        else
            vim.cmd("wincmd " .. dir)
        end
    end
end

map({ "n", "t" }, "<C-h>", nav("h"), { desc = "Window left" })
map({ "n", "t" }, "<C-j>", nav("j"), { desc = "Window down" })
map({ "n", "t" }, "<C-k>", nav("k"), { desc = "Window up" })
map({ "n", "t" }, "<C-l>", nav("l"), { desc = "Window right" })

-- Hide the current window, keeping its buffer loaded -- and for the terminal,
-- its shell running. Escalates rather than refusing: when this is the tab's
-- last window there is nothing left to show, so close the tab instead. Stops
-- at the last window of the last tab so it can never quit nvim by surprise.
-- <C-q> would read better ("quit") but terminals can eat it as XOFF flow
-- control, which fails silently; <C-x> always arrives and costs only
-- decrement-number.
local function hide_window()
    if #vim.api.nvim_tabpage_list_wins(0) > 1 then
        vim.cmd("hide")
    elseif #vim.api.nvim_list_tabpages() > 1 then
        vim.cmd("tabclose")
    else
        vim.notify("last window of the last tab", vim.log.levels.INFO)
    end
end

map("n", "<C-x>", hide_window, { desc = "Hide current window" })
map("t", "<C-x>", function()
    vim.cmd("stopinsert")
    vim.schedule(hide_window)
end, { desc = "Hide current window (from terminal mode)" })

-- Get out of a :terminal buffer
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Terminal: normal mode" })

-- File explorer. mini.files navigates in columns and does file operations by
-- editing the buffer text, then `=` to apply -- which is the part netrw made
-- painful. Opens at the current file so you land next to what you are editing.
map("n", "<leader>q", function()
    local files = require("mini.files")
    -- close() returns nil when nothing is open, which is the toggle.
    if not files.close() then
        local name = vim.api.nvim_buf_get_name(0)
        files.open(name ~= "" and name or vim.fn.getcwd(), true)
    end
end, { desc = "Toggle file explorer" })
map("n", "<leader>d", vim.diagnostic.setloclist, { desc = "Diagnostics to loclist" })



-- Tabs. Switching is already built in and not redefined: gt / gT step through
-- them and {count}gt jumps straight to one (2gt = second tab). <leader>1..3
-- would be the obvious jump keys but they are the mergetool diffget keys.
-- 'showtabline' is 1 by default, so the tabline appears once a second tab does.
-- next / previous / new, at whatever level you are in: shells inside a terminal
-- panel, tabpages anywhere else. All three are real control codes, so they
-- arrive from inside a shell -- unlike <C-,> or <C-S-p>, which need the kitty
-- keyboard protocol and never showed up.
local function at_level(shell_fn, tab_cmd)
    return function()
        if vim.bo.buftype == "terminal" then
            vim.cmd("stopinsert")
            vim.schedule(function()
                shell_fn(require("terminal"))
                vim.cmd("startinsert") -- ready to type in whatever we landed on
            end)
        else
            pcall(vim.cmd, tab_cmd)
        end
    end
end

map({ "n", "t" }, "<C-n>", at_level(function(t) t.cycle(1) end, "tabnext"),
    { desc = "Next shell (in a terminal) or next tab" })
map({ "n", "t" }, "<C-p>", at_level(function(t) t.cycle(-1) end, "tabprevious"),
    { desc = "Previous shell (in a terminal) or previous tab" })
-- <C-t> rather than <C-a> for "new": inside a shell <C-a> is beginning-of-line,
-- which you would miss constantly, while <C-t> is only transpose-chars. In
-- normal mode it costs the tag-stack jump back -- use <C-o>, the jumplist.
map({ "n", "t" }, "<C-t>", at_level(function(t) t.new() end, "tabnew"),
    { desc = "New shell (in a terminal) or new tab" })
-- No close-tab key: <C-x> already closes the tab once it is the last window.
-- <leader>f / g / b / h are fuzzy pickers, set up in the Plugins section.
