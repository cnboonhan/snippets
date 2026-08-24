-- Python types, hover, go-to-definition.
return {
    cmd = { "basedpyright-langserver", "--stdio" },
    filetypes = { "python" },
    root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
    settings = {
        basedpyright = {
            analysis = {
                -- basedpyright defaults to "recommended", which is very loud on
                -- untyped code. "standard" matches upstream pyright.
                typeCheckingMode = "standard",
                inlayHints = { variableTypes = false, callArgumentNames = false },
                -- Ruff already reports these; don't show them twice.
                diagnosticSeverityOverrides = {
                    reportUnusedImport = "none",
                    reportUnusedVariable = "none",
                },
            },
        },
    },
}
