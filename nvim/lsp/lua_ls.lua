-- Lua, configured to understand the Neovim API so editing this config works.
return {
    cmd = { "lua-language-server" },
    filetypes = { "lua" },
    root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
    settings = {
        Lua = {
            runtime = { version = "LuaJIT" },
            workspace = {
                -- Just the runtime, not every rtp dir: keeps startup fast.
                library = { vim.env.VIMRUNTIME .. "/lua" },
                checkThirdParty = false,
            },
            diagnostics = { globals = { "vim" } },
            telemetry = { enable = false },
        },
    },
}
