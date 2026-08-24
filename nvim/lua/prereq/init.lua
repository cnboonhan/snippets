-- External tools this config depends on. Homebrew everywhere: it is the one
-- manager carrying every tool below on both macOS and Linux, which no distro
-- repo does. Nothing here installs anything on its own; see M.install().
local M = {}

local is_linux = vim.uv.os_uname().sysname == "Linux"

-- brew is often absent from a GUI-launched nvim's $PATH, so look in the
-- standard prefixes too: Apple Silicon, Intel mac, then Linuxbrew.
local BREW_PATHS = {
    "/opt/homebrew/bin/brew",
    "/usr/local/bin/brew",
    "/home/linuxbrew/.linuxbrew/bin/brew",
}

function M.brew()
    if vim.fn.executable("brew") == 1 then
        return "brew"
    end
    for _, p in ipairs(BREW_PATHS) do
        if vim.fn.executable(p) == 1 then
            return p
        end
    end
end

M.brew_install_hint = {
    'install: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"',
    'then on Linux add to your shell rc: eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"',
}

-- bin:    executable that must be on $PATH
-- pkg:    Homebrew formula; nil means brew cannot provide it
-- manual: what to run instead when pkg is nil
M.requirements = {
    { bin = "git",  pkg = "git",     why = "vim.pack installs and updates" },
    { bin = "curl", pkg = "curl",    why = "nvim-treesitter downloads parser sources" },
    { bin = "rg",   pkg = "ripgrep", why = ":grep and the live-grep picker" },
    { bin = "tree-sitter", pkg = "tree-sitter-cli", why = "building treesitter parsers (needs 0.26.1+)" },
    { bin = "basedpyright-langserver", pkg = "basedpyright", why = "Python types" },
    { bin = "ruff", pkg = "ruff",    why = "Python lint and format" },
    { bin = "lua-language-server",  pkg = "lua-language-server",  why = "Lua LSP" },
    { bin = "bash-language-server", pkg = "bash-language-server", why = "shell LSP" },
    { bin = "shellcheck", pkg = "shellcheck", why = "shell diagnostics for bash-language-server" },

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

-- Install in a :terminal split rather than vim.system, so you can watch the
-- output and answer anything brew asks.
function M.install()
    local brew = M.brew()
    if not brew then
        return vim.notify("prereq: brew not found\n" .. table.concat(M.brew_install_hint, "\n"),
            vim.log.levels.ERROR)
    end

    local pkgs, manual = {}, {}
    for _, r in ipairs(M.missing()) do
        if r.pkg then
            table.insert(pkgs, r.pkg)
        else
            table.insert(manual, ("  %s -- %s"):format(r.bin, r.manual))
        end
    end

    if #manual > 0 then
        vim.notify("prereq: brew cannot provide these:\n" .. table.concat(manual, "\n"),
            vim.log.levels.WARN)
    end
    if #pkgs == 0 then
        return
    end

    vim.cmd(("botright 15split | terminal %s install %s"):format(brew, table.concat(pkgs, " ")))
end

return M
