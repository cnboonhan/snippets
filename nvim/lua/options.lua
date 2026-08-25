-- Editor options. Only non-defaults: nvim already gives us
-- filetype/indent/syntax, incsearch, hlsearch, wildmenu, mouse, termguicolors.

local o = vim.o

-- Only non-defaults. nvim already gives us filetype/indent/syntax,
-- incsearch, hlsearch, wildmenu, mouse and termguicolors.
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

-- Always OSC 52: the clipboard behaves the same locally and over SSH, on any
-- client OS, with nothing installed anywhere. Requires a terminal that
-- implements it (Terminal.app does not). Must be set before 'clipboard',
-- which initializes the provider.
vim.g.clipboard = "osc52"
o.clipboard = "unnamedplus"

-- Completion menu: show even for a single match, never auto-insert.
o.completeopt = "menu,menuone,popup,noinsert,fuzzy"

-- Use ripgrep for :grep
o.grepprg = "rg --vimgrep --smart-case"
o.grepformat = "%f:%l:%c:%m"
