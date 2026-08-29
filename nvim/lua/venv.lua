-- Switch the Python environment without restarting nvim. Three things have to
-- move together, which is why this is a command and not a setting:
--   * $VIRTUAL_ENV and $PATH, so anything nvim spawns uses it
--   * basedpyright's interpreter, which it reads once at startup
--   * new terminal shells, which source the venv on creation
local M = {}

-- Remember the choice per working directory: :Venv only changes this nvim
-- process, so without this a restart loses an environment that lives outside
-- the project, where the upward search cannot find it.
local STORE = vim.fn.stdpath("state") .. "/venvs"

-- What makes a directory an environment, asked in five places below.
local function is_venv(dir)
    return vim.fn.filereadable(dir .. "/bin/python") == 1
end

-- Absolute, ~ and $VAR expanded, no trailing slash.
local function abs(path)
    return (vim.fn.fnamemodify(vim.fn.expand(path), ":p"):gsub("/$", ""))
end

local function store_path()
    return ("%s/%s"):format(STORE, (vim.fn.getcwd():gsub("/", "%%")))
end

local function remember(dir)
    vim.fn.mkdir(STORE, "p")
    pcall(vim.fn.writefile, { dir }, store_path())
end

local function recall()
    local f = store_path()
    if vim.fn.filereadable(f) == 0 then
        return nil
    end
    local dir = (vim.fn.readfile(f)[1] or ""):gsub("%s+$", "")
    if dir ~= "" and is_venv(dir) then
        return dir
    end
    -- Gone or moved: forget it rather than failing on every startup.
    pcall(vim.fn.delete, f)
end

-- The nearest environment at or above you, used only to choose where browsing
-- starts so you are usually one keystroke from the obvious answer.
local function nearest_venv()
    local from = vim.fn.expand("%:p:h")
    if from == "" or vim.fn.isdirectory(from) == 0 then
        from = vim.fn.getcwd()
    end
    for _, d in ipairs(vim.fs.find({ ".venv", "venv", ".virtualenv" },
        { upward = true, type = "directory", path = from, limit = math.huge })) do
        if is_venv(d) then
            return d
        end
    end
end

-- basedpyright resolves its interpreter at startup, so changing the setting is
-- not enough: the client has to come back. Stopping it and re-firing FileType
-- lets vim.lsp.enable attach a fresh one.
local function restart_lsp()
    local restarted = {}
    for _, client in ipairs(vim.lsp.get_clients({ name = "basedpyright" })) do
        restarted[#restarted + 1] = client.id
        client:stop(true)
    end
    vim.defer_fn(function()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "python" then
                vim.api.nvim_exec_autocmds("FileType", { buffer = buf })
            end
        end
    end, 150)
    return restarted
end

-- The environment half: variables and the LSP setting, no restarts. Startup
-- needs exactly this and nothing more, since no client has attached yet.
local function apply(dir)
    local python = dir .. "/bin/python"
    local old = vim.env.VIRTUAL_ENV
    local path = vim.env.PATH
    if old then
        path = path:gsub(vim.pesc(old .. "/bin") .. ":?", "")
    end
    vim.env.VIRTUAL_ENV = dir
    vim.env.PATH = dir .. "/bin:" .. path
    vim.lsp.config("basedpyright", {
        settings = { python = { pythonPath = python } },
    })
end

function M.use(dir)
    dir = abs(dir)
    if not is_venv(dir) then
        return vim.notify("no interpreter at " .. dir .. "/bin/python", vim.log.levels.WARN)
    end

    apply(dir)
    remember(dir)
    local stopped = restart_lsp()

    -- Shells that are already open would otherwise keep the old interpreter.
    local sourced, busy = require("terminal").activate_in_open_shells(dir .. "/bin/activate")

    local msg = ("venv: %s\nbasedpyright restarted (%d client%s), %d open shell%s updated")
        :format(vim.fn.fnamemodify(dir, ":~"), #stopped, #stopped == 1 and "" or "s",
            sourced, sourced == 1 and "" or "s")
    if busy > 0 then
        msg = msg .. ("\n%d shell%s busy, left alone: activate by hand there")
            :format(busy, busy == 1 and "" or "s")
    end
    vim.notify(msg)
end

-- Browsing is the interface, because an environment may live anywhere: a
-- shared venv in ~/envs, a conda directory, a sibling checkout. Starts at the
-- nearest venv's parent when there is one, so the common case is one keystroke.
local picking = false

function M.browse(start)
    local from = start and vim.fn.expand(start)
    if not from or vim.fn.isdirectory(from) == 0 then
        local near = nearest_venv()
        from = near and vim.fn.fnamemodify(near, ":h") or vim.fn.getcwd()
    end
    picking = true
    require("mini.files").open(from, false)
    vim.notify("<CR> enters a folder, or selects it when it holds bin/python")
end

-- <CR> does the obvious thing for whatever is under the cursor: an environment
-- gets selected, any other directory gets entered. Binding it to "select only"
-- made plain folders unenterable, which is the wrong way round -- you have to
-- walk through folders to reach an environment.
local function choose_or_enter()
    local files = require("mini.files")
    local entry = files.get_fs_entry()
    if not entry then
        return
    end

    if entry.fs_type ~= "directory" then
        return vim.notify("pick a directory containing bin/python", vim.log.levels.WARN)
    end

    if is_venv(entry.path) then
        files.close()
        return vim.schedule(function() M.use(entry.path) end)
    end

    -- Not an environment, so treat <CR> as "go in", same as l.
    files.go_in()
end

-- Reapply the remembered environment for this directory. Never overrides one
-- the launching shell already activated: that is a deliberate choice too.
function M.restore()
    if vim.env.VIRTUAL_ENV then
        return false
    end
    local dir = recall()
    if not dir then
        return false
    end
    apply(dir)
    return true
end

function M.setup()
    -- Before any client attaches, so basedpyright starts on the right one.
    M.restore()

    vim.api.nvim_create_user_command("Venv", function(opts)
        if opts.args == "" then
            return M.browse()
        end
        -- One argument, two meanings, decided by what is actually there: an
        -- environment gets activated, any other directory becomes the place to
        -- start browsing. Saves walking up from a nested project with h.
        local path = abs(opts.args)
        if is_venv(path) then
            return M.use(path)
        end
        if vim.fn.isdirectory(path) == 1 then
            return M.browse(path)
        end
        vim.notify("no such directory: " .. path, vim.log.levels.WARN)
    end, {
        nargs = "?",
        complete = "dir",
        desc = "Browse for a Python environment and restart basedpyright",
    })

    local aug = vim.api.nvim_create_augroup("user.venv", { clear = true })

    -- <CR> is mini.pick's own "choose" key, so selecting works the same way
    -- across both. Bound only while :Venv is browsing: in ordinary <leader>q
    -- browsing <CR> should not activate an environment. (= is out: mini.files
    -- uses it for synchronize, which writes file changes to disk.)
    vim.api.nvim_create_autocmd("User", {
        group = aug,
        pattern = "MiniFilesBufferCreate",
        desc = "<CR> selects an environment, or enters an ordinary directory",
        callback = function(args)
            if not picking then
                return
            end
            vim.keymap.set("n", "<CR>", choose_or_enter,
                { buffer = args.data.buf_id, desc = "Use as Python environment" })
        end,
    })

    vim.api.nvim_create_autocmd("User", {
        group = aug,
        pattern = "MiniFilesExplorerClose",
        desc = "End the venv-picking session",
        callback = function() picking = false end,
    })

    vim.api.nvim_create_user_command("VenvShow", function()
        vim.notify("venv: " .. (vim.env.VIRTUAL_ENV or "none (project default)"))
    end, { desc = "Show the active Python environment" })
end

return M
