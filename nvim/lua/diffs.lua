-- Diff colours and the mergetool keys.

local map = vim.keymap.set
local aug = vim.api.nvim_create_augroup("user.diffs", { clear = true })

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

-- Blame for the line under the cursor. mini.diff gives signs and hunks but no
-- blame, and this is the part people actually want day to day: who last
-- touched this line, when, and why. --porcelain is the stable machine format.
local function blame_line()
    if vim.bo.buftype ~= "" then
        return vim.notify("not a file buffer", vim.log.levels.WARN)
    end
    local file = vim.fn.expand("%:p")
    if file == "" then
        return vim.notify("buffer has no file", vim.log.levels.WARN)
    end

    local line = vim.api.nvim_win_get_cursor(0)[1]
    local res = vim.system({
        "git", "blame", "-L", ("%d,%d"):format(line, line), "--porcelain", "--", file,
    }, { cwd = vim.fn.fnamemodify(file, ":h"), text = true }):wait()

    if res.code ~= 0 then
        local err = (res.stderr or "git blame failed"):gsub("%s+$", "")
        return vim.notify(err, vim.log.levels.WARN)
    end

    local out = res.stdout or ""
    local sha = out:match("^(%x+)") or "?"
    local author = out:match("\nauthor ([^\n]*)") or "?"
    local when = tonumber(out:match("\nauthor%-time (%d+)"))
    local summary = out:match("\nsummary ([^\n]*)") or ""

    -- All-zero sha is git's way of saying the line is not committed yet.
    if sha:match("^0+$") then
        return vim.notify(("line %d: not committed yet"):format(line))
    end

    vim.notify(("%s  %s  %s\n%s"):format(
        sha:sub(1, 8),
        author,
        when and os.date("%Y-%m-%d", when) or "?",
        summary))
end

map("n", "<leader>B", blame_line, { desc = "Git blame for this line" })
vim.api.nvim_create_user_command("Blame", blame_line, { desc = "Git blame for this line" })
