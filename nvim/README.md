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
| `<leader>=` | LSP format |
| `<leader>t` | toggle bottom terminal |
| `<leader>e` | send line / selection to the terminal and run it |
| `<leader>r` | send a `path:line` reference instead of the code |
| `<C-h/j/k/l>` | move between windows, including out of the terminal |
| `<Esc><Esc>` | terminal → normal mode |
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
init.lua              options, keymaps, autocmds, treesitter, LSP, plugins
lsp/*.lua             one file per language server
lua/terminal.lua      toggle terminal + send-to-terminal
lua/prereq/           external tool checks (:checkhealth prereq)
nvim-pack-lock.json   pinned plugin revisions
```

## Notes

- Update plugins: `:lua vim.pack.update()`, review the diff, `:w` to apply.
- Add a parser: `:lua require("nvim-treesitter").install({"go"})`.
- Buffers reload the instant a file changes on disk -- a git checkout, a
  formatter, an agent -- using the OS's own notifications (inotify / FSEvents),
  measured at 2-11 ms. The watch is on the file's *directory*, not the file:
  atomic writers replace the inode, and a watch on the file itself would then
  be pointing at a dead one. Unsaved edits are never lost: nvim warns with
  `W12` and keeps your version.
- Images cannot render inside nvim: `:terminal` swallows the kitty graphics
  protocol and `:!` re-renders escapes as text. Run `timg` in a real shell.
