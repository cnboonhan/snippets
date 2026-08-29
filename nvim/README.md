# nvim

Minimal Neovim: core-only apart from four plugins. Python LSP, fuzzy pickers,
file explorer, git signs, terminal panels, OSC 52 clipboard.

## Requirements

| Need | Why |
| --- | --- |
| **Neovim 0.12+** | Ubuntu's apt ships 0.9 — use Homebrew |
| **Homebrew** | the only package manager used, macOS and Linux alike |
| **A C compiler** | treesitter parsers build from source |
| **A terminal with OSC 52** | Ghostty, Kitty, WezTerm, iTerm2. **Terminal.app has none** — yanks go nowhere |

## Setup

```sh
cd nvim && ./setup.sh
```

Idempotent, and the only installer: `:checkhealth prereq` reports what is
missing, `setup.sh` fixes it.

| It | What |
| --- | --- |
| Installs | Neovim, the external tools the config needs, the plugins, the treesitter parsers |
| Copies | the config into `~/.config/nvim`, backing up whatever was there |
| Configures | git `merge.tool` / `diff.tool` = `nvimdiff`, `zdiff3` conflict style; `~/.profile` on Linux |
| Stops | with instructions if there is no C compiler or no Homebrew, before changing anything |

Set by hand: `~/.config/ghostty/config` →
`shell-integration-features = cursor,no-sudo,title,ssh-env,ssh-terminfo,path`.

## Keys

Leader is `Space`. Everything below also works from inside a terminal.

| Key | Action |
| --- | --- |
| `<C-h/j/k/l>` | move between windows |
| `<C-n>` / `<C-p>` | next / previous — shell inside a terminal, otherwise tab |
| `<C-t>` | new — shell inside a terminal, otherwise tab |
| `<C-x>` | hide the window; on a tab's last window, close the tab |
| `<Esc>` / `<Esc><Esc>` | clear search highlight / terminal → normal mode |
| `<leader>f` `g` `b` `h` | fuzzy: files, live grep, buffers, help |
| `<leader>q` | toggle the file explorer |
| `<leader>e` / `<leader>E` | send line or selection to the **bottom** / side terminal |
| `<leader>r` / `<leader>R` | send a `path:line` reference to the **side** / bottom terminal |
| `<leader>y` / `<leader>Y` | pull highlighted text into the editor — dedented / verbatim |
| `<leader>]` / `<leader>[` | next / previous shell in a panel |
| `<leader>d` / `<leader>=` | diagnostics to loclist / format via LSP |
| `<leader>B` / `<leader>o` | git blame this line / toggle inline diff overlay |
| `<leader>1` `2` `3` `u` | mergetool: take LOCAL / BASE / REMOTE, refresh |

| Panels | Behaviour |
| --- | --- |
| At startup | both open, cursor stays in the editor; skipped in `nvim -d` |
| `<C-x>` | hides one |
| First press on a closed panel | opens it and sends nothing; press again to send (`gv` reselects) |
| Open-only key | none — the send keys are it |
| Scrolling | `<Esc><Esc>` then `<C-b>` / `<C-u>` / `gg` |

### Insert mode

| Key | Action |
| --- | --- |
| `<C-Space>` | ask for completion (`<C-x><C-o>` too) |
| `<Tab>` / `<S-Tab>` | snippet placeholders, otherwise a plain Tab |
| `<C-s>` | signature help |

### Commands

| Command | Action |
| --- | --- |
| `:Venv` / `:Venv <path>` | browse for a Python environment; `<CR>` enters a folder or selects it. A path is activated if it is one, otherwise browsed from |
| `:VenvShow` | report the active environment |
| `:Serve [port]` | serve the working directory on loopback. Bare: from 3588 (or `vim.g.serve_port`) upward to a free one. Explicit: exactly that, or an error |
| `:ServeStop` / `:Blame` | stop the server / blame this line |
| `:checkhealth prereq` | report missing external tools and why each is wanted |

### Already in nvim or the plugins

| Key | From |
| --- | --- |
| `gcc` / `gc` | comment toggle — **built in** |
| `]q` `[q` `]l` `[l` `]b` `[b` `]a` `[a` | quickfix, loclist, buffer, arglist |
| `]d` `[d` `]D` `[D` | diagnostics: next / previous / first / last |
| `]<Space>` `[<Space>` | empty line below / above |
| `gx` / `<C-w>d` | open file or URL under cursor / diagnostics float |
| `]h` `[h` `]H` `[H` `gh` `gH` | git hunks: move, first/last, apply, reset (mini.diff) |
| `]n` `[n` `an` `in` | treesitter node selection |

### LSP and code navigation

| Key | Action |
| --- | --- |
| `<C-]>` / `g<C-]>` | definition / `:tjump` when several match |
| `<C-o>` | jump back — **not** `<C-t>`, which is remapped to "new shell/tab" |
| `<C-w>]` / `<C-w>}` | definition in a split / preview window |
| `grr` `gri` `grt` / `grn` `gra` | references, implementation, type / rename, code action |
| `gO` / `K` | document symbols / hover |

**Trap:** `gd` and `gD` are *not* LSP here — they fall back to vim's textual
search, so they often appear to work while only matching text.

### Diff and merge

`git mergetool` stacks LOCAL / BASE / REMOTE over MERGED; `<leader>1/2/3` take a
side, `:%diffget LOCAL` takes one for the whole file; `:wqa` writes and quits,
`:cq` aborts. git marks a file resolved from whatever you wrote — it never
checks for leftover `<<<<<<<`.

`git difftool` is two plain buffers, so `<leader>1/2/3` do **not** apply:

| Key | Action |
| --- | --- |
| `]c` / `[c` | next / previous change |
| `do` / `dp` | obtain the other side / put this side |
| `zo` `zc` / `zR` `zM` | open / close one fold, or all |
| `<leader>u` | recompute after an edit |
| `:qa` / `:cq` | next changed file / abort the run |

Only the right-hand buffer is real; edits to the left are discarded.
`--dir-diff` opens every changed file at once, `main...feature` diffs any ref.

## Layout

```
init.lua              leader, then the modules below
lua/options.lua       editor options
lua/keymaps.lua       general keys, windows, tabs
lua/autocmds.lua      yank highlight, whitespace trim, cursor restore
lua/reload.lua        instant reload when a file changes on disk
lua/treesitter.lua    highlighting
lua/lsp.lua           diagnostics, completion, per-buffer setup
lua/plugins.lua       vim.pack and the four plugins
lua/diffs.lua         diff colours, mergetool keys, blame
lua/serve.lua         the HTTP file server
lua/venv.lua          Python environment switching
lua/terminal.lua      terminal panels, shells, their keys
lua/prereq/           which tools are needed, and which are missing
lsp/*.lua             one table per language server
nvim-pack-lock.json   pinned plugin revisions
```

## Behaviour worth knowing

| Thing | Behaviour |
| --- | --- |
| Clipboard | Yank reaches the system clipboard, over SSH too, with nothing installed. **Paste does not** — it reads nvim's own register. For text from another app use the terminal's paste, ⌘/Ctrl-V. |
| Python env | `:Venv` switches the environment for the editor, the language server and the open shells, and is remembered per directory. A venv active in the launching shell wins. |
| Files in a browser | `:Serve` *renders* the working directory rather than offering downloads: markdown and source, PDFs inline, media in a player with seeking. Over SSH: `ssh -L 3588:localhost:3588 HOST`. |
| Reload | Buffers reload the instant a file changes on disk. Unsaved edits are kept, with a `W12` warning. |
| Completion | Built-in LSP completion, offered after two word characters. `<CR>` stays a newline. |
| Terminal scrollback | Claude Code and other full-screen TUIs run inline in a panel, so their history stays in the buffer and scrolls with the usual motions. |
| Updating | `:lua vim.pack.update()`, review the diff, `:w`. Parsers: `:lua require("nvim-treesitter").install({"go"})`. |
