-- ~/.config/nvim/init.lua
-- Minimal Neovim. Core-only except three plugins, installed by the built-in
-- vim.pack. Each require below is one self-contained concern.

-- Leader must be set before any keymap that uses <leader>.
vim.g.mapleader = " "

require("options")
require("plugins") -- vim.pack.add first: later modules may use a plugin
require("keymaps")
require("autocmds")
require("reload")
require("treesitter")
require("lsp")
require("diffs")
require("session")
require("serve").setup()
require("venv").setup()
require("terminal").setup()
require("prereq").setup()
