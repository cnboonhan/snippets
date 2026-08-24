-- ~/.config/nvim/init.lua
-- Minimal Neovim. Core-only except two plugins, installed by the built-in
-- vim.pack: a fuzzy picker, and a build tool for treesitter parsers.

-- Leader must be set before any keymap that uses <leader>.
vim.g.mapleader = " "

-- ── Options ───────────────────────────────────────────────────────────
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

-- ── Keymaps ───────────────────────────────────────────────────────────
-- nvim 0.11+ already ships LSP keymaps: K (hover), grn (rename),
-- gra (code action), grr (references), gri (implementation),
-- gO (symbols), and ]d / [d to walk diagnostics. Don't redefine them.
local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Window navigation without the <C-w> prefix
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- Get out of a :terminal buffer
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Terminal: normal mode" })

map("n", "<leader>e", "<cmd>Explore<CR>",        { desc = "File explorer (netrw)" })
map("n", "<leader>d", vim.diagnostic.setloclist, { desc = "Diagnostics to loclist" })
-- <leader>f / g / b / h are fuzzy pickers, set up in the Plugins section.

-- ── Autocommands ──────────────────────────────────────────────────────
local aug = vim.api.nvim_create_augroup("user", { clear = true })

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

-- ── Reload on disk change ─────────────────────────────────────────────
-- Fallback for when the OS watcher below cannot attach (inotify limits, NFS,
-- odd filesystems). 'autoread' is already on; nvim just needs nudging, since
-- it only re-checks the file on a few events of its own.
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
    group = aug,
    desc = "Check whether the file changed on disk",
    command = "checktime",
})

-- Instant, rather than waiting for one of the events above: ask the OS to
-- tell us (inotify on Linux, FSEvents on macOS). Watch the *directory*, not
-- the file: tools that write atomically -- temp file, then rename -- replace
-- the inode, and a watch on the file itself then points at a dead one and
-- never fires again. The directory's inode is stable, so filter its events
-- by filename instead.
local watchers = {}

local function unwatch(buf)
    local w = watchers[buf]
    if w then
        w:stop()
        w:close()
        watchers[buf] = nil
    end
end

local function watch(buf)
    unwatch(buf)
    local path = vim.api.nvim_buf_get_name(buf)
    if path == "" or vim.bo[buf].buftype ~= "" or vim.fn.filereadable(path) == 0 then
        return
    end
    local w = vim.uv.new_fs_event()
    if not w then
        return
    end
    watchers[buf] = w
    local dir = vim.fn.fnamemodify(path, ":h")
    local name = vim.fn.fnamemodify(path, ":t")
    w:start(dir, {}, function(err, changed)
        if err or (changed and changed ~= name) then
            return
        end
        vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(buf) then
                return unwatch(buf)
            end
            vim.cmd("checktime " .. buf)
        end)
    end)
end

vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
    group = aug,
    desc = "Watch this file's directory for external changes",
    callback = function(ev) watch(ev.buf) end,
})

vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = aug,
    desc = "Stop watching a closed buffer",
    callback = function(ev) unwatch(ev.buf) end,
})

vim.api.nvim_create_autocmd("FileChangedShellPost", {
    group = aug,
    desc = "Say so when a buffer is replaced from disk",
    callback = function()
        vim.notify("reloaded from disk: " .. vim.fn.expand("<afile>:t"), vim.log.levels.WARN)
    end,
})

-- ── Treesitter ────────────────────────────────────────────────────────
-- nvim 0.12 bundles parsers for c, lua, markdown, vim, vimdoc and query,
-- and auto-starts only Markdown. Turn on the rest. Python's parser is not
-- bundled; it was built by nvim-treesitter into stdpath("data")/site/parser,
-- which is on the runtimepath, so highlighting works without the plugin.
vim.api.nvim_create_autocmd("FileType", {
    group = aug,
    pattern = { "c", "lua", "vim", "query", "python" },
    desc = "Treesitter highlighting for bundled parsers",
    callback = function() pcall(vim.treesitter.start) end,
})

-- ── LSP ───────────────────────────────────────────────────────────────
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

-- ── Terminal ──────────────────────────────────────────────────────────
local term = require("terminal")

map("n", "<leader>t", term.toggle, { desc = "Toggle bottom terminal" })

-- Send the current line, or the visual selection, and run it.
-- <C-e>'s only built-in job is scrolling down one line.
map({ "n", "x" }, "<C-e>", term.send, { desc = "Send line/selection to terminal" })

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

-- Deliberately no <C-e> in terminal mode: the shell binds it to end-of-line.
-- To hide the terminal: <C-k> out of it, then <leader>t.

-- ── Plugins ───────────────────────────────────────────────────────────
-- Managed by vim.pack, built into nvim 0.12 -- no third-party manager.
--   :lua vim.pack.update()   review the diff, :w to apply, :q to discard
--   :lua vim.pack.del({ "name" })                     to remove one
vim.pack.add({
    -- Fuzzy pickers. No dependencies and no external binary.
    { src = "https://github.com/echasnovski/mini.pick" },

    -- Build tool for treesitter parsers, not a runtime dependency: it
    -- compiles into site/parser, which nvim finds on its own.
    --   :lua require("nvim-treesitter").install({ "go" })
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
}, {
    -- Install without prompting: revisions are pinned in nvim-pack-lock.json
    -- and setup.sh bootstraps headlessly, where a prompt would just hang.
    confirm = false,
})

require("mini.pick").setup()

local pick = function(name)
    return function() require("mini.pick").builtin[name]() end
end

map("n", "<leader>f", pick("files"),     { desc = "Fuzzy: files" })
map("n", "<leader>g", pick("grep_live"), { desc = "Fuzzy: live grep" })
map("n", "<leader>b", pick("buffers"),   { desc = "Fuzzy: buffers" })
map("n", "<leader>h", pick("help"),      { desc = "Fuzzy: help tags" })

-- ── Prerequisites ─────────────────────────────────────────────────────
-- :checkhealth prereq   what is missing and why
-- :PrereqInstall        brew install the missing formulae
vim.api.nvim_create_user_command("PrereqInstall", function()
    require("prereq").install()
end, { desc = "brew install missing external tools" })

-- Say something once at startup if a tool is missing, but never install
-- without being asked: brew hits the network and changes the system.
vim.api.nvim_create_autocmd("VimEnter", {
    group = aug,
    desc = "Warn about missing external tools",
    once = true,
    callback = function()
        local miss = require("prereq").missing()
        if #miss > 0 then
            local names = vim.tbl_map(function(r) return r.bin end, miss)
            vim.notify(
                ("missing %d tool(s): %s\n:checkhealth prereq for detail, :PrereqInstall to fix")
                    :format(#miss, table.concat(names, ", ")),
                vim.log.levels.WARN
            )
        end
    end,
})

-- ── Diff / merge ──────────────────────────────────────────────────────
-- `git mergetool` stacks LOCAL / BASE / REMOTE above the MERGED buffer you
-- edit. ]c and [c already jump between hunks, so only "take this side" is
-- missing. Defined unconditionally: git launches nvim without -d (it calls
-- :diffthis from its own -c instead), so a load-time `if vim.o.diff` guard
-- is false exactly when you need these. Outside a diff they simply error.
map("n", "<leader>1", "<cmd>diffget LOCAL<CR>",  { desc = "Merge: take hunk from LOCAL (ours)" })
map("n", "<leader>2", "<cmd>diffget BASE<CR>",   { desc = "Merge: take hunk from BASE" })
map("n", "<leader>3", "<cmd>diffget REMOTE<CR>", { desc = "Merge: take hunk from REMOTE (theirs)" })
map("n", "<leader>u", "<cmd>diffupdate<CR>",     { desc = "Merge: refresh the diff" })
