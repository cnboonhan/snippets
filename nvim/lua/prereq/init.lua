-- External tools this config depends on. This module only *reports* -- what is
-- missing, and why it is wanted. Installing is setup.sh's job alone, so there
-- is one installer to keep correct instead of two that drift apart. The `pkg`
-- field is the Homebrew formula setup.sh reads; nothing here shells out.
local M = {}

local is_linux = vim.uv.os_uname().sysname == "Linux"

-- bin:    executable that must be on $PATH
-- pkg:    Homebrew formula setup.sh installs; nil means brew cannot provide it
-- manual: what to run by hand when pkg is nil
M.requirements = {
    { bin = "git",  pkg = "git",     why = "vim.pack installs and updates" },
    { bin = "curl", pkg = "curl",    why = "nvim-treesitter downloads parser sources" },
    { bin = "rg",   pkg = "ripgrep", why = ":grep and the live-grep picker" },
    { bin = "tree-sitter", pkg = "tree-sitter-cli", why = "building treesitter parsers (needs 0.26.1+)" },
    { bin = "basedpyright-langserver", pkg = "basedpyright", why = "Python types" },
    { bin = "ruff", pkg = "ruff",    why = "Python lint and format" },
    -- Optional in the sense that the file server falls back to python3's
    -- http.server, but that only offers files for download and has no Range
    -- support: video cannot seek and some browsers refuse to play it at all.
    { bin = "copyparty", pkg = "copyparty", why = "serving the working directory (renders files, video seeking)" },

    -- Homebrew deliberately does not ship a system C compiler: on macOS it
    -- comes from Apple's CLT, and on Linux brew itself requires one already.
    {
        bin = "cc", pkg = nil, why = "compiling treesitter parsers",
        manual = is_linux
            and "install your distro's build tools (build-essential / base-devel / gcc)"
            or "xcode-select --install",
    },

    -- No clipboard tool listed: the config always uses OSC 52, which needs
    -- nothing installed on either end.
}

function M.missing()
    return vim.tbl_filter(function(r)
        return vim.fn.executable(r.bin) == 0
    end, M.requirements)
end

-- The startup warning. No install command: see the note at the top.
function M.setup()
    local aug = vim.api.nvim_create_augroup("user.prereq", { clear = true })

    -- Say something once at startup if a tool is missing. :checkhealth prereq
    -- has the detail; setup.sh is what fixes it.
    vim.api.nvim_create_autocmd("VimEnter", {
        group = aug,
        desc = "Warn about missing external tools",
        once = true,
        callback = function()
            local miss = M.missing()
            if #miss > 0 then
                local names = vim.tbl_map(function(r) return r.bin end, miss)
                vim.notify(
                    ("missing %d tool(s): %s\n:checkhealth prereq for detail, ./setup.sh to install")
                        :format(#miss, table.concat(names, ", ")),
                    vim.log.levels.WARN
                )
            end
        end,
    })
end

return M
