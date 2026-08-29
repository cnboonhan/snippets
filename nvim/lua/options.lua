-- Editor options. Only non-defaults: nvim already gives us
-- filetype/indent/syntax, incsearch, hlsearch, wildmenu, mouse, termguicolors.

local o = vim.o

o.number = true
o.relativenumber = true
-- With both 'number' and 'relativenumber', nvim left-aligns the absolute
-- number on the cursor line while every other line is right-aligned (see
-- :h number_relativenumber). Render the column ourselves so all of them
-- right-align: %s is the sign column, %= pushes the number to the right.
o.statuscolumn = "%s%=%{v:relnum ? v:relnum : v:lnum} "
o.signcolumn = "yes"     -- always reserve the gutter so text never shifts
o.cursorline = true
o.scrolloff = 8          -- keep context above/below the cursor
o.wrap = false
o.winborder = "rounded"  -- borders on hover/float windows

-- Indentation: 4 spaces. Language ftplugins override this per filetype.
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.softtabstop = 4

-- Searching
o.ignorecase = true
o.smartcase = true       -- ...unless the pattern contains a capital
o.inccommand = "split"   -- live preview for :substitute

-- Files & undo
o.undofile = true        -- persistent undo across restarts
o.confirm = true         -- prompt on unsaved changes instead of failing
o.swapfile = false       -- undofile covers recovery; swap files are noise

-- Splits open where you expect them
o.splitright = true
o.splitbelow = true

-- Always OSC 52 for copying: the clipboard behaves the same locally and over
-- SSH, on any client OS, with nothing installed anywhere. Requires a terminal
-- that implements it (Terminal.app does not). Must be set before 'clipboard',
-- which initializes the provider.
--
-- Pasting deliberately does not use OSC 52. Reading the clipboard means asking
-- the terminal for it and waiting: nvim blocks for a second, prints "Waiting
-- for OSC 52 response ... Ctrl-C to interrupt", then waits nine more. Ghostty
-- defaults to clipboard-read = ask, so every p sat behind a prompt, and a
-- terminal that ignores the query never answers at all. Answering from nvim's
-- own unnamed register is instant and cannot hang. Text copied in another
-- application still arrives via the terminal's own paste (Cmd/Ctrl-V), which
-- comes in as a bracketed paste and works in any mode.
local osc52 = require("vim.ui.clipboard.osc52")
local function unnamed()
    return vim.fn.getreg('"', 1, true)
end
vim.g.clipboard = {
    name = "osc52-copy",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = unnamed, ["*"] = unnamed },
}
o.clipboard = "unnamedplus"

-- Completion menu: show even for a single match, and preselect nothing, so
-- <CR> stays a newline instead of accepting whatever was highlighted.
o.completeopt = "menu,menuone,popup,noselect,fuzzy"

-- Use ripgrep for :grep. 'grepformat' already matches rg --vimgrep output.
o.grepprg = "rg --vimgrep --smart-case"
