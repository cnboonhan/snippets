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

-- Toggle. Leaving is the fiddly half: :Rexplore ("return to the file I came
-- from") throws when nvim was started on a directory, and can also succeed
-- while landing on another directory buffer -- which is just netrw again. So
-- check that we actually left, and keep falling back until we have.
local function in_explorer()
    local name = vim.api.nvim_buf_get_name(0)
    return vim.bo.filetype == "netrw" or (name ~= "" and vim.fn.isdirectory(name) == 1)
end

map("n", "<leader>q", function()
    if not in_explorer() then
        vim.cmd("Explore")
        return
    end

    pcall(vim.cmd, "Rexplore")
    if not in_explorer() then
        return
    end

    -- A candidate has to be a real file: not netrw, not a directory buffer,
    -- and actually named.
    local function is_file(b)
        local name = vim.api.nvim_buf_get_name(b)
        return vim.api.nvim_buf_is_valid(b)
            and vim.bo[b].filetype ~= "netrw"
            and name ~= ""
            and vim.fn.isdirectory(name) == 0
    end

    local alt = vim.fn.bufnr("#")
    if alt > 0 and is_file(alt) then
        vim.api.nvim_set_current_buf(alt)
        return
    end
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[b].buflisted and is_file(b) then
            vim.api.nvim_set_current_buf(b)
            return
        end
    end

    -- Nothing to go back to, but leaving is what was asked for.
    vim.cmd("enew")
end, { desc = "Toggle file explorer (netrw)" })
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
map({ "n", "x" }, "<leader>e", term.send, { desc = "Send line/selection to terminal" })

-- Same gesture, but sends a `path:line` reference rather than the code, so an
-- agent in the terminal can look at what you are looking at.
map({ "n", "x" }, "<leader>r", term.send_ref, { desc = "Send path:line reference to terminal" })

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

-- To hide the terminal: <C-k> out of it, then <leader>t.

-- ── Plugins ───────────────────────────────────────────────────────────
-- Managed by vim.pack, built into nvim 0.12 -- no third-party manager.
--   :lua vim.pack.update()   review the diff, :w to apply, :q to discard
--   :lua vim.pack.del({ "name" })                     to remove one
vim.pack.add({
    -- Fuzzy pickers. No dependencies and no external binary.
    { src = "https://github.com/echasnovski/mini.pick" },

    -- Git gutter signs and hunk staging. Same author, same lack of deps.
    { src = "https://github.com/echasnovski/mini.diff" },

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

-- Gutter signs against the git index: + added, ~ changed, - deleted.
require("mini.diff").setup({
    view = { style = "sign", signs = { add = "+", change = "~", delete = "-" } },
})

local pick = function(name)
    return function() require("mini.pick").builtin[name]() end
end

map("n", "<leader>f", pick("files"),     { desc = "Fuzzy: files" })
map("n", "<leader>g", pick("grep_live"), { desc = "Fuzzy: live grep" })
map("n", "<leader>b", pick("buffers"),   { desc = "Fuzzy: buffers" })
map("n", "<leader>h", pick("help"),      { desc = "Fuzzy: help tags" })

-- Git hunks: [h / ]h jump, gh is the hunk text object (ghgh, dgh, ...).
map("n", "<leader>o", function() require("mini.diff").toggle_overlay(0) end,
    { desc = "Git: toggle inline diff overlay" })

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
-- nvim's defaults paint a changed line grey and the changed text teal, which
-- says "something differs" without saying what. Repaint them so the meaning
-- is obvious at a glance: green added, red removed, amber changed. Leaving
-- fg unset on the line-level groups lets syntax highlighting show through.
local function diff_colors()
    local hl = vim.api.nvim_set_hl
    hl(0, "DiffAdd",    { bg = "#1f3b28" })                   -- whole line added
    hl(0, "DiffDelete", { bg = "#3b1f24", fg = "#8f5a63" })   -- removed / filler
    hl(0, "DiffChange", { bg = "#33301f" })                   -- line holding a change
    hl(0, "DiffText",   { bg = "#6b5411", fg = "#ffe9a3", bold = true }) -- the change
end

diff_colors()
vim.api.nvim_create_autocmd("ColorScheme", {
    group = aug,
    desc = "Keep the diff colours across a colorscheme change",
    callback = diff_colors,
})

-- `git mergetool` stacks LOCAL / BASE / REMOTE above the MERGED buffer you
-- edit. ]c and [c already jump between hunks, so only "take this side" is
-- missing. Defined unconditionally: git launches nvim without -d (it calls
-- :diffthis from its own -c instead), so a load-time `if vim.o.diff` guard
-- is false exactly when you need these. Outside a diff they simply error.
map("n", "<leader>1", "<cmd>diffget LOCAL<CR>",  { desc = "Merge: take hunk from LOCAL (ours)" })
map("n", "<leader>2", "<cmd>diffget BASE<CR>",   { desc = "Merge: take hunk from BASE" })
map("n", "<leader>3", "<cmd>diffget REMOTE<CR>", { desc = "Merge: take hunk from REMOTE (theirs)" })
map("n", "<leader>u", "<cmd>diffupdate<CR>",     { desc = "Merge: refresh the diff" })

-- ── Images ────────────────────────────────────────────────────────────
-- Two ways to look at an image, chosen by what the machine can actually do:
--   * a real desktop     -> hand it to the OS viewer, which gives zoom and pan
--   * headless over SSH  -> draw it in the terminal with timg, whose kitty
--                           escapes travel back down the connection (no zoom)
-- Either way the bytes never enter a buffer, which is what produces the wall
-- of binary garbage.

local function os_opener()
    if vim.fn.has("mac") == 1 then
        return "open"
    end
    -- Linux needs a display to open into; a headless box over SSH has none.
    if (vim.env.DISPLAY or vim.env.WAYLAND_DISPLAY) and vim.fn.executable("xdg-open") == 1 then
        return "xdg-open"
    end
end

-- :terminal swallows the kitty graphics protocol, and :! hands the child a
-- pipe so nvim re-renders the escapes as literal "^[_G" text. The way through
-- is to write the bytes straight at the terminal, bypassing nvim's renderer.
local function render_in_terminal(path)
    if vim.fn.executable("timg") == 0 then
        return vim.notify("timg not found: brew install timg", vim.log.levels.WARN)
    end
    -- timg gets a pipe, so it can detect neither the terminal size nor the
    -- protocol; both must be passed. -ph draws half-blocks if pixels fail.
    local geom = ("%dx%d"):format(vim.o.columns, math.max(vim.o.lines - 2, 1))
    local res = vim.system({ "timg", "-pk", "-g", geom, path }, { text = false }):wait()
    if res.code ~= 0 or not res.stdout or #res.stdout == 0 then
        return vim.notify("timg failed: " .. (res.stderr or "no output"), vim.log.levels.WARN)
    end
    local out = function(data) vim.api.nvim_chan_send(vim.v.stderr, data) end
    out("\27[2J\27[H")   -- clear and home: we own the screen for a moment
    out(res.stdout)
    vim.fn.getcharstr()  -- any key dismisses
    out("\27_Ga=d\27\\") -- delete the kitty image we placed
    vim.cmd("redraw!")   -- hand the screen back to nvim
end

-- Returns true when the image was handed off externally, meaning there is
-- nothing for nvim to keep on screen.
local function view_image(path)
    local opener = os_opener()
    if opener then
        vim.system({ opener, path }, { detach = true })
        return true
    end
    render_in_terminal(path)
    return false
end

map("n", "<leader>i", function() view_image(vim.fn.expand("%:p")) end,
    { desc = "View this file as an image" })

vim.api.nvim_create_autocmd("BufReadCmd", {
    group = aug,
    pattern = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.bmp", "*.avif", "*.ico" },
    desc = "View image files instead of loading binary into the buffer",
    callback = function(ev)
        local buf, path = ev.buf, ev.match

        -- BufReadCmd means we own loading this file. Keep the buffer empty and
        -- unwritable so a stray :w can never truncate the image.
        vim.bo[buf].buftype = "nofile"
        vim.bo[buf].swapfile = false
        local kb = math.max(vim.fn.getfsize(path), 0) / 1024
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            ("%s  --  %.1f KB"):format(vim.fn.fnamemodify(path, ":t"), kb),
            "",
            "<leader>i to view again",
        })
        vim.bo[buf].modifiable = false
        vim.bo[buf].modified = false

        vim.schedule(function()
            if view_image(path) then
                -- Opened externally: go back where we came from (netrw, or
                -- whatever was current) and drop the placeholder.
                local alt = vim.fn.bufnr("#")
                if alt > 0 and vim.api.nvim_buf_is_valid(alt) and alt ~= buf then
                    vim.api.nvim_set_current_buf(alt)
                    pcall(vim.api.nvim_buf_delete, buf, { force = true })
                end
            end
        end)
    end,
})
