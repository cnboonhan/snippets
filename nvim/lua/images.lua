-- Viewing images without loading their bytes into a buffer.

local map = vim.keymap.set
local aug = vim.api.nvim_create_augroup("user.images", { clear = true })

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
