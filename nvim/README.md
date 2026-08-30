# nvim

Minimal Neovim: core-only apart from four plugins, installed by the built-in
`vim.pack`. Python + Lua/shell LSP, fuzzy pickers, file explorer, git signs,
terminal panels, OSC 52 clipboard.

## Requirements

| Need | Why |
| --- | --- |
| **Neovim 0.12+** | `vim.pack`, `vim.lsp.enable`, `statuscolumn`, `winborder`. Ubuntu's apt ships 0.9 — use Homebrew. |
| **Homebrew** | The only package manager used, macOS and Linux alike. No npm, pip or cargo. |
| **A C compiler** | Treesitter parsers build from source. `xcode-select --install` / `build-essential`. |
| **A terminal with OSC 52** | Ghostty, Kitty, WezTerm, iTerm2. **Terminal.app has none** — yanks go nowhere. |

## Setup

```sh
cd nvim && ./setup.sh          # install everything missing
```

Takes no arguments: every concern is a check and a fix, and a check that
passes never touches the machine. The two SSH settings below are the exception
— they need a hostname or sudo, so apply them by hand.

Idempotent. It reads the tool list from `lua/prereq`, the same one behind
`:checkhealth prereq`, and installs only what is missing from `PATH`. Homebrew
itself is the one thing it will not install for you.

## Configuration outside nvim

| File | Machine | Setting | By |
| --- | --- | --- | --- |
| global git config | both | `merge.tool` `diff.tool` = `nvimdiff`, `mergetool.prompt=false`, `mergetool.keepBackup=false`, `merge.conflictstyle=zdiff3` | `setup.sh` |
| `~/.profile` | Linux | `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"` — `~/.bashrc` returns early for non-interactive shells | `setup.sh` |
| `~/.ssh/config` | client | `Host X` → `SetEnv COLORTERM=truecolor` — without it nvim's `DCS +q` probe prints as junk | by hand |
| `/etc/ssh/sshd_config.d/99-colorterm.conf` | server | `AcceptEnv COLORTERM`, then `sudo sshd -t && sudo systemctl reload ssh` | by hand |
| `~/.config/ghostty/config` | client | `shell-integration-features = cursor,no-sudo,title,ssh-env,ssh-terminfo,path` — or `infocmp -x xterm-ghostty \| ssh HOST -- tic -x -` | by hand |

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

A closed panel absorbs the first press: `<leader>e` and `<leader>r` open it and
send nothing; press again to send (`gv` reselects, since the split ends visual
mode). There is no open-only key, and `<C-x>` hides. To scroll a panel,
`<Esc><Esc>` then `<C-b>` / `<C-u>` / `gg`.

### Insert mode

| Key | Action |
| --- | --- |
| `<C-Space>` | ask for completion (`<C-x><C-o>` too) |
| `<Tab>` / `<S-Tab>` | snippet placeholders, otherwise a plain Tab |
| `<C-s>` | signature help — nvim's own |

### Commands

| Command | Action |
| --- | --- |
| `:Venv` / `:Venv <path>` | browse for a Python environment; `<CR>` enters a folder or selects it. A path is activated if it is one, otherwise browsed from |
| `:VenvShow` | report the active environment |
| `:Serve [port]` | serve the working directory on loopback. Bare: from 8000 (or `vim.g.serve_port`) upward to a free one. Explicit: exactly that, or an error |
| `:ServeStop` / `:Blame` / `:SessionRestore` | stop the server / blame this line / restore this directory's layout |
| `:checkhealth prereq` | report which external tools are missing — `./setup.sh` installs them |

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

Go-to-definition is the built-in tag jump: on attach nvim sets
`tagfunc=v:lua.vim.lsp.tagfunc`.

| Key | Action |
| --- | --- |
| `<C-]>` / `g<C-]>` | definition / `:tjump` when several match |
| `<C-o>` | jump back — **not** `<C-t>`, which is remapped to "new shell/tab" |
| `<C-w>]` / `<C-w>}` | definition in a split / preview window |
| `grr` `gri` `grt` / `grn` `gra` | references, implementation, type / rename, code action |
| `gO` / `K` | document symbols / hover |

**Trap:** `gd` and `gD` are *not* LSP here. Unmapped, they fall back to vim's
textual search, so they often appear to work while only matching text.

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

Only the right-hand buffer is real; the left is a temp copy under `/tmp`.
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
lua/session.lua       per-directory window/tab layout
lua/serve.lua         the HTTP file server
lua/venv.lua          Python environment switching
lua/terminal.lua      terminal panels, shells, their keys
lua/prereq/           external tool checks
lsp/*.lua             one table per language server
nvim-pack-lock.json   pinned plugin revisions
```

## Behaviour worth knowing

| Thing | Behaviour |
| --- | --- |
| Clipboard | Sitting at the machine, yank and put go straight to the real clipboard (`pbcopy`/`pbpaste`, `wl-copy`/`wl-paste`, `xclip`, `xsel` — first pair present, and only with a display), so no terminal has to honour an escape sequence. Over SSH, yank goes out as **OSC 52**, which needs nothing installed at either end. Paste never uses OSC 52 — a read waits on the terminal and hangs for 10s when it does not answer (Ghostty defaults to `clipboard-read = ask`) — so over SSH `p` uses nvim's own register, and ⌘/Ctrl-V pastes text from other apps. |
| Sessions | Window/tab layout per directory, plus undo ('undofile') and shada. Terminals come back with shells restarted and the venv re-sourced. Bare `nvim` restores; `nvim foo.py` does not. Headless never saves or restores. |
| Python env | `:Venv` sets `$VIRTUAL_ENV`/`$PATH`, restarts basedpyright, sources open shells (busy ones are skipped and reported), and is remembered per directory. A venv active in the launching shell wins. |
| Files in a browser | `:Serve` runs `copyparty`, which *renders* rather than downloads: markdown and source through its viewer, PDFs inline, media in a player, Range requests so video seeks. Over SSH: `ssh -L 8000:localhost:8000 HOST`. |
| Reload | Buffers reload the instant a file changes (2-11 ms), watching the file's *directory* — atomic writers replace the inode. Unsaved edits are kept, with a `W12` warning. |
| Completion | nvim's built-in LSP completion. `autotrigger` only fires on the server's trigger characters, so a `TextChangedI` autocommand asks after two word characters. `noselect` keeps `<CR>` a newline. |
| Terminal scrollback | A full-screen TUI on the alternate screen leaves nvim nothing to scroll. The env var in the table above keeps Claude Code on the primary screen; in Ghostty, ⌘+Fn+↑ and Shift+wheel scroll its own scrollback. |
| Working over SSH | `mosh HOST` instead of `ssh` — it echoes keystrokes locally and predicts the remote's response, so typing does not wait a round trip. Needs UDP 60000-61000 open to the server. It passes OSC 52 through, so remote yanks still reach the local clipboard; but it draws on the alternate screen, so the local terminal's scrollback does not hold the session. |
| Updating | `:lua vim.pack.update()`, review the diff, `:w`. Parsers: `:lua require("nvim-treesitter").install({"go"})`. |
