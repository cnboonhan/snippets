-- A static file server rooted at the working directory, so you can browse the
-- project in a real browser -- which is the only comfortable way to look at
-- images and video, especially over SSH where the terminal cannot draw them.
local M = {}

-- Default port; override per-session with vim.g.serve_port, or per-invocation
-- with :Serve <port>.
local DEFAULT_PORT = 3588
local proc, url

-- Bound to loopback only: this serves every file under the working directory,
-- which has no business being reachable from the network.
local HOST = "127.0.0.1"

-- bind() alone is not enough: it succeeds on a port another process is already
-- listening on, so the check has to listen() too or every port looks free.
local function port_free(port)
    local sock = vim.uv.new_tcp()
    if not sock then
        return false
    end
    local ok = pcall(function()
        assert(sock:bind(HOST, port))
        assert(sock:listen(1, function() end))
    end)
    sock:close()
    return ok
end

-- Scan upward from the default so several nvim instances do not collide.
local function free_port(from)
    for p = from, from + 20 do
        if port_free(p) then
            return p
        end
    end
end

-- copyparty *renders* what it serves rather than handing it to the browser to
-- guess at: source files and markdown through its own viewer, PDFs inline,
-- images and video in a player, all with Range requests so seeking works. A
-- plain static server can only send a MIME type, and the browser downloads
-- anything it has no viewer for: .md, .lua, .yaml, and often PDFs, which some
-- servers additionally mark as an attachment.
local function command_for(root, port, writable)
    if vim.fn.executable("copyparty") == 1 then
        return {
            "copyparty", "-i", HOST, "-p", tostring(port),
            -- One volume at the root: read-only by default, "rw" with :Serve!,
            -- which turns the same page into a drop target for uploads.
            "-v", root .. (writable and "::rw" or "::r"),
            -- Thumbnails and its index would otherwise land in a .hist folder
            -- inside whatever project is being served.
            "--hist", vim.fn.stdpath("cache") .. "/copyparty",
            "--no-crt", -- no TLS here: loopback only
            "-q",
        }, "copyparty" .. (writable and ", read-write" or "")
    end
    return {
        "python3", "-m", "http.server", tostring(port),
        "--bind", HOST, "--directory", root,
    }, "python3 (downloads instead of rendering, no video seeking: brew install copyparty)"
end

-- With no argument, take vim.g.serve_port (or the default) and scan upward for
-- a free one. With an explicit port, use exactly that and say so if it is
-- taken, rather than quietly serving somewhere the caller did not ask for.
function M.start(port, writable)
    if proc then
        return vim.notify("already serving " .. url, vim.log.levels.INFO)
    end
    if port then
        if not port_free(port) then
            return vim.notify(("port %d is in use"):format(port), vim.log.levels.WARN)
        end
    else
        local from = tonumber(vim.g.serve_port) or DEFAULT_PORT
        port = free_port(from)
        if not port then
            return vim.notify("no free port near " .. from, vim.log.levels.WARN)
        end
    end

    local root = vim.fn.getcwd()
    local cmd, which = command_for(root, port, writable)
    proc = vim.system(cmd, { text = true }, function(res)
        local was = url
        proc, url = nil, nil
        -- Say so rather than leaving a dead server looking alive.
        if res.code ~= 0 and was then
            vim.schedule(function()
                vim.notify(("file server exited (%d): %s"):format(res.code,
                    (res.stderr or ""):gsub("%s+$", "")), vim.log.levels.WARN)
            end)
        end
    end)
    url = ("http://%s:%d"):format(HOST, port)

    local msg = ("serving %s at %s  [%s]"):format(vim.fn.fnamemodify(root, ":~"), url, which)
    if vim.env.SSH_CONNECTION then
        -- Loopback on the server is not reachable from your laptop without a
        -- tunnel, so say how.
        msg = msg .. ("\nfrom your machine: ssh -L %d:localhost:%d %s")
            :format(port, port, vim.fn.hostname())
    end
    vim.notify(msg)
end

function M.stop()
    if not proc then
        return vim.notify("not serving", vim.log.levels.INFO)
    end
    proc:kill("sigterm")
    proc, url = nil, nil
end

function M.setup()
    local aug = vim.api.nvim_create_augroup("user.serve", { clear = true })

    -- Read-only unless asked: everything under the working directory is exposed
    -- either way, and a writable server means anything that can reach the port
    -- can also put files there. Loopback-bound, so that is you and anyone you
    -- have given a tunnel to.
    vim.api.nvim_create_user_command("Serve", function(opts)
        M.start(tonumber(opts.args), opts.bang)
    end, {
        nargs = "?",
        bang = true,
        desc = "Serve the working directory over HTTP [port]; ! allows uploads",
    })
    vim.api.nvim_create_user_command("ServeStop", M.stop, { desc = "Stop the file server" })

    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = aug,
        desc = "Stop the file server",
        callback = function()
            if proc then
                proc:kill("sigterm")
            end
        end,
    })
end

return M
