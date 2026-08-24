-- Python linting + formatting. Pairs with basedpyright, which does types.
return {
    cmd = { "ruff", "server" },
    filetypes = { "python" },
    root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },
    on_attach = function(client)
        -- Let basedpyright own hover; ruff's is thinner and they collide.
        client.server_capabilities.hoverProvider = false
    end,
}
