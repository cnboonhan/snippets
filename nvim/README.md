# nvim

Minimal Neovim config: core-only apart from three plugins, installed by the
built-in `vim.pack`. Python + Lua/shell LSP, fuzzy pickers, git gutter signs,
OSC 52 clipboard.

## Requirements

- **Neovim 0.12+** — uses `vim.pack`, `vim.lsp.enable`, `statuscolumn`,
  `winborder`. Ubuntu's apt ships 0.9, so install from Homebrew.
- **Homebrew** (macOS or Linux) — no distro repo carries all the tools below.
- **A C compiler** — treesitter parsers are compiled from source.
  `xcode-select --install`, or `build-essential` / `base-devel`.
- **A terminal that implements OSC 52** — Ghostty, Kitty, WezTerm, iTerm2.
  **macOS Terminal.app does not**, and yanks there silently go nowhere.

## Setup

```sh
cd nvim && ./setup.sh
```

Idempotent — re-running reports what is already done rather than repeating it.
It installs the Homebrew packages, copies the config to `~/.config/nvim`
(backing up any existing one), points git at nvim as its merge tool, installs
the plugins and builds the treesitter parsers, then prints anything still
missing.

For use over SSH, two more:

```sh
./setup.sh ssh-client HOST    # on the machine you sit at
./setup.sh ssh-server         # on the remote host (needs sudo)
```

Homebrew is the one thing the script will not install for you — it prints the
command and exits. The next section documents what the script applies, and
why, for doing it by hand or auditing it.

## Configuration outside nvim

Everything this config assumes but cannot set for itself. `setup.sh`
applies the git and Homebrew entries; the SSH and Ghostty ones need the
subcommands above, or the manual steps here.

| File | Machine | Purpose |
| --- | --- | --- |
| global git config | both | nvim as the merge/diff tool |
| `~/.profile` | server (Linux) | put Homebrew on `PATH` |
| `~/.ssh/config` | client | send `COLORTERM` |
| `/etc/ssh/sshd_config.d/99-colorterm.conf` | server | accept `COLORTERM` |
| `~/.config/ghostty/config` | client | get terminfo onto servers |

### git — 3-way merge

```sh
git config --global merge.tool nvimdiff
git config --global diff.tool nvimdiff
git config --global mergetool.prompt false
git config --global mergetool.keepBackup false
git config --global merge.conflictstyle zdiff3   # shows the common ancestor
```

`git mergetool` stacks LOCAL / BASE / REMOTE above the MERGED buffer. Walk
hunks with `]c` / `[c` and take a side with `<leader>1` / `2` / `3`, or take
one side for the whole file with `:%diffget LOCAL`. `:wqa` writes and quits;
`:cq` aborts and leaves the conflict alone.

`diffget` works per hunk, so one conflict block can need several
applications — and git marks the file resolved from whatever you wrote, it
never checks for leftover `<<<<<<<` markers. Re-read before `:wqa`.

### git — reviewing changes with `difftool`

`git difftool` opens the old and new versions side by side. Its two buffers
are a throwaway copy of the old blob and your working file — **not** named
LOCAL/BASE/REMOTE, so `<leader>1` / `2` / `3` do not apply here. Those are
mergetool only; difftool uses the generic two-buffer commands:

| Key | Action |
| --- | --- |
| `]c` / `[c` | next / previous change |
| `do` | diff obtain — pull the other side's version into this window |
| `dp` | diff put — push this window's version to the other |
| `<C-h/j/k/l>` | switch between the two windows |
| `zo` `zc` / `zR` `zM` | open / close one fold, or all (diff folds unchanged lines) |
| `<leader>u` | `:diffupdate`, recompute after an edit |
| `:qa` | close and advance to the *next* changed file |
| `:cq` | abort the whole difftool run |

Only the right-hand buffer is real — the left is a temp copy under `/tmp`, so
edits there evaporate and you will reach for `do` far more than `dp`. And
`:qa` advances rather than quits, because difftool walks the changed files one
at a time; `:cq` is the way out.

`git difftool --dir-diff` opens every changed file in one session instead of
file by file, and `git difftool main...feature` diffs against any ref.

### Homebrew on `PATH` (Linux server)

Ubuntu's `~/.bashrc` returns early for non-interactive shells, and login
shells read `~/.profile` instead — so `ssh host nvim` sees neither unless the
line is here:

```sh
# ~/.profile
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
```

### `COLORTERM` over SSH

Without it nvim probes the terminal with a `DCS +q` capability query, and a
terminal that ignores the query prints the payload as visible junk. Set it on
the *connection*, not in the server's shell rc: that way each client declares
its own capability instead of the server asserting it for everyone.

```
# client: ~/.ssh/config
Host myserver
  SetEnv COLORTERM=truecolor
```

```
# server: /etc/ssh/sshd_config.d/99-colorterm.conf
AcceptEnv COLORTERM
```

Then `sudo sshd -t && sudo systemctl reload ssh`.

### Ghostty terminfo

Ghostty sets `TERM=xterm-ghostty`, which servers do not know. Either let
Ghostty install it on first connect:

```
# ~/.config/ghostty/config
shell-integration-features = cursor,no-sudo,title,ssh-env,ssh-terminfo,path
```

or push it once per host:

```sh
infocmp -x xterm-ghostty | ssh myserver -- tic -x -
```

## Keys

Leader is `Space`. The LSP and navigation keys below are nvim's own defaults
and are deliberately not redefined.

| Key | Action |
| --- | --- |
| `<leader>f` `g` `b` `h` | fuzzy: files, live grep, buffers, help |
| `<leader>q` | toggle netrw file explorer (`:Explore` / `:Rexplore`) |
| `<leader>d` | diagnostics to loclist |
| `gt` `gT` | next / previous tab (built-in); `2gt` jumps to tab 2 |
| `<leader>=` | LSP format |
| `<leader>t` / `<leader>T` | toggle the side / bottom terminal panel |
| `<leader>n` | another shell when in a terminal, otherwise a new tab |
| `gt` `gT` `2gt` | inside a terminal: next / previous / Nth shell |
| `<leader>]` / `<leader>[` | next / previous shell in that panel |
| `<leader>e` / `<leader>E` | send line or selection to the side / bottom terminal |
| `<leader>r` / `<leader>R` | send a `path:line` reference to the side / bottom terminal |
| `<leader>i` | view the current file as an image |
| `<C-h/j/k/l>` | move between windows, including out of the terminal |
| `<C-x>` | hide the window; on the tab's last window, close the tab. Buffers stay loaded, shells keep running |
| `<Esc><Esc>` | terminal → normal mode |

Two terminal panels -- one down the side, one along the bottom -- and each
holds as many shells as you like, cycled like tabs within the panel. A row of
numbers appears along the top of a panel once it has more than one, and they
are clickable. `gt` / `gT` / `2gt` select shells inside a terminal, mirroring
how they move between tabpages everywhere else. Leave a
REPL in one shell and run commands in another. Lower case targets the side
panel, upper case the bottom, throughout.

Every tab gets its own pair, so a tab is a self-contained workspace. They are
separate processes, but every new shell sources the project's `.venv`/`venv`
activate script if it finds one searching upward from the file you were on, so
they all start in the same environment.
Closing a tab reaps its two shells rather than leaving them running as hidden
buffers. The bottom terminal splits the *current* window rather than the whole
screen, so a side terminal keeps its full height instead of being squashed.

A leader key cannot work in terminal mode -- mapping `<Space>` there would
hijack every "space then t" you type at the shell -- so `<C-x>` hides either
one from inside, the same key that hides any other window.

| `<leader>1` `2` `3` | merge: take hunk from LOCAL / BASE / REMOTE |
| `<leader>u` | merge: refresh the diff |
| `]h` `[h` | jump to next / previous git hunk |
| `gh` | git hunk text object (`dgh` reset, `ghgh` select) |
| `<leader>o` | toggle the inline git diff overlay |

### LSP and code navigation

Go-to-definition is the built-in tag jump: on LSP attach nvim sets
`tagfunc=v:lua.vim.lsp.tagfunc`, so the tag keys ask the language server.

| Key | Action |
| --- | --- |
| `<C-]>` | go to definition |
| `<C-t>` | jump back (tag stack; repeat to unwind) |
| `<C-w>]` | definition in a horizontal split |
| `<C-w>}` | definition in a preview window |
| `g<C-]>` | `:tjump` — pick from a list when several match |
| `grr` `gri` `grt` | references / implementation / type definition |
| `grn` `gra` | rename / code action |
| `gO` | document symbols |
| `K` | hover |
| `]d` `[d` | next / previous diagnostic |
| `<leader>d` | diagnostics to the location list |
| `<leader>=` | format via the language server |

Trap: `gd` and `gD` are **not** LSP here. They are unmapped, so they fall back
to vim's original textual search for a declaration in the current file. Most
distro configs rebind `gd` to `vim.lsp.buf.definition()`, so muscle memory
misleads: `gd` often appears to work while silently only matching text.

## Layout

```
setup.sh              installer (also: ssh-client HOST, ssh-server)
init.lua              sets the leader, then requires the modules below
lua/options.lua       editor options
lua/keymaps.lua       general keys, window hiding, netrw toggle
lua/autocmds.lua      yank highlight, whitespace trim, cursor restore
lua/reload.lua        instant reload when a file changes on disk
lua/treesitter.lua    treesitter highlighting
lua/lsp.lua           diagnostics, completion, per-buffer LSP setup
lua/plugins.lua       vim.pack and the three plugins, with their keys
lua/diffs.lua         diff colours and the mergetool keys
lua/images.lua        image viewing
lua/session.lua       per-directory window/tab layout
lua/terminal.lua      the terminal, send-to-terminal, and its keys
lua/prereq/           external tool checks (:checkhealth prereq)
lsp/*.lua             one table per language server
nvim-pack-lock.json   pinned plugin revisions
```

## Notes

- State that survives closing nvim: undo history ('undofile'), marks,
  registers and search/command history (shada), and the window/tab layout per
  directory. Bare `nvim` in a directory restores its layout; `nvim foo.py` just
  opens that file. `:SessionRestore` restores on demand. Headless runs neither
  save nor restore, so scripts cannot clobber a layout.
- Completion is nvim's built-in LSP completion. `autotrigger` alone only fires
  on the server's trigger characters -- for basedpyright `.` `[` `"` `'` -- so
  it covers `foo.` but never a bare identifier. A `TextChangedI` autocommand
  asks for completion once two word characters have been typed, which is what
  makes variables complete. `<C-Space>` triggers it by hand, `<C-x><C-o>` also
  works. 'completeopt' uses `noselect` so `<CR>` stays a newline.
- Update plugins: `:lua vim.pack.update()`, review the diff, `:w` to apply.
- Add a parser: `:lua require("nvim-treesitter").install({"go"})`.
- Buffers reload the instant a file changes on disk -- a git checkout, a
  formatter, an agent -- using the OS's own notifications (inotify / FSEvents),
  measured at 2-11 ms. The watch is on the file's *directory*, not the file:
  atomic writers replace the inode, and a watch on the file itself would then
  be pointing at a dead one. Unsaved edits are never lost: nvim warns with
  `W12` and keeps your version.
- Opening an image picks a viewer by what the machine can do: on a desktop it
  hands off to the OS viewer (`open` / `xdg-open`) for real zoom and pan; on a
  headless box over SSH it draws in the terminal with `timg`, whose kitty
  escapes travel back down the connection (view only, no zoom). Either way the
  bytes never enter a buffer. `<leader>i` views again.
  nvim cannot do this itself: `:terminal` swallows the graphics protocol and
  `:!` is handed a pipe, so nvim re-renders the escapes as literal text. The
  terminal path writes bytes straight at the terminal via `nvim_chan_send`.
