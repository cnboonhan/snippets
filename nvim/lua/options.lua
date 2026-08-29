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

-- Clipboard. Sitting at this machine, use the real one: pbcopy/pbpaste and
-- their Linux equivalents talk to it directly, with no terminal in the middle
-- to honour an escape sequence, answer a query, or drop a large payload.
--
-- Over SSH there is no local clipboard to reach, so copying goes out as OSC 52
-- -- the terminal at the far end puts it on the real clipboard, needing nothing
-- installed anywhere. Pasting there deliberately does *not* use OSC 52: a read
-- means asking the terminal and waiting, which blocks for a second, prints
-- "Waiting for OSC 52 response ... Ctrl-C to interrupt", then waits nine more,
-- and Ghostty defaults to clipboard-read = ask. nvim's own register answers
-- instantly and cannot hang; Cmd/Ctrl-V still pastes text from other apps.
--
-- Must be set before 'clipboard', which initializes the provider.
-- First match wins. env is the variable the tool needs to have something to
-- talk to, so an X11 binary on a machine with no display is skipped.
local TOOLS = {
    { env = "", copy = { "pbcopy" }, paste = { "pbpaste" } },
    { env = "WAYLAND_DISPLAY", copy = { "wl-copy" }, paste = { "wl-paste", "--no-newline" } },
    { env = "DISPLAY", copy = { "xclip", "-i", "-selection", "clipboard" },
      paste = { "xclip", "-o", "-selection", "clipboard" } },
    { env = "DISPLAY", copy = { "xsel", "-i", "-b" }, paste = { "xsel", "-o", "-b" } },
}

local local_tool
if not vim.env.SSH_CONNECTION then
    for _, t in ipairs(TOOLS) do
        if (t.env == "" or vim.env[t.env]) and vim.fn.executable(t.copy[1]) == 1 then
            local_tool = t
            break
        end
    end
end

local osc52 = require("vim.ui.clipboard.osc52")
local copy = local_tool and local_tool.copy or osc52.copy("+")
local paste = local_tool and local_tool.paste or function()
    return vim.fn.getreg('"', 1, true)
end

vim.g.clipboard = {
    name = local_tool and local_tool.copy[1] or "osc52-copy",
    copy = { ["+"] = copy, ["*"] = copy },
    paste = { ["+"] = paste, ["*"] = paste },
}
o.clipboard = "unnamedplus"

-- Completion menu: show even for a single match, and preselect nothing, so
-- <CR> stays a newline instead of accepting whatever was highlighted.
o.completeopt = "menu,menuone,popup,noselect,fuzzy"

-- Use ripgrep for :grep. 'grepformat' already matches rg --vimgrep output.
o.grepprg = "rg --vimgrep --smart-case"
