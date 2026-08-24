-- Shell diagnostics. Install shellcheck for the useful ones.
return {
    cmd = { "bash-language-server", "start" },
    filetypes = { "sh", "bash" },
    root_markers = { ".git" },
}
