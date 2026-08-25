-- Pick up changes made to a file on disk by something else.

local aug = vim.api.nvim_create_augroup("user.reload", { clear = true })

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
