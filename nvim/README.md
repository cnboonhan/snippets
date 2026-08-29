# nvim

Minimal Neovim config: core-only apart from four plugins, installed by the
built-in `vim.pack`. Python + Lua/shell LSP, fuzzy pickers, a file explorer, git
gutter signs, OSC 52 clipboard.

## Requirements

- **Neovim 0.12+** — uses `vim.pack`, `vim.lsp.enable`, `statuscolumn`,
  `winborder`. Ubuntu's apt ships 0.9, so install from Homebrew.
- **Homebrew** (macOS or Linux) — no distro repo carries all the tools below.
- **A C compiler** — treesitter parsers are compiled from source.
  `xcode-select --install`, or `build-essential` / `base-devel`.
- **A terminal that implements OSC 52** — Ghostty, Kitty, WezTerm, iTerm2.
  **macOS Terminal.app does not**, and yanks there silently go nowhere.

Homebrew is the only package manager involved. Every external tool is a brew
formula on both platforms — including the ones that are really node or Python
programs, `basedpyright`, `bash-language-server` and `copyparty`, whose
runtimes brew brings along — so there is no npm, pip or cargo anywhere. The two
things brew cannot supply are itself and the C compiler; plugins come from git
via `vim.pack`, pinned in `nvim-pack-lock.json`.

## Setup

```sh
cd nvim && ./setup.sh
```

Idempotent — re-running reports what is already done rather than repeating it.
It installs whatever is missing, copies the config to `~/.config/nvim` (backing
up any existing one), points git at nvim as its merge tool, keeps Claude Code
off the alternate screen, installs the plugins and builds the treesitter
parsers, then prints anything still missing.

It asks the config itself which tools are needed — the same list behind
`:checkhealth prereq` and `:PrereqInstall` — so a new tool is added in one
place rather than two that drift apart. And it installs only what is *missing
from `PATH`*, not everything the list names: `git` and `curl` are on any
machine that can run brew already, and installing Homebrew's copies over the
system ones would be waste.

For use over SSH, two more:

```sh
./setup.sh ssh-client HOST    # on the machine you sit at
./setup.sh ssh-server         # on the remote host (needs sudo)
```

Homebrew is the one thing the script will not install for you — it prints the
command and exits. The next section documents what the script applies, and
why, for doing it by hand or auditing it.

## Configuration outside nvim

Everything this config assumes but cannot set for itself. `setup.sh` applies
the git, Homebrew and Claude Code entries; the SSH and Ghostty ones need the
subcommands above, or the manual steps here.

| File | Machine | Purpose |
| --- | --- | --- |
| global git config | both | nvim as the merge/diff tool |
| `~/.profile` | server (Linux) | put Homebrew on `PATH` |
| `~/.ssh/config` | client | send `COLORTERM` |
| `/etc/ssh/sshd_config.d/99-colorterm.conf` | server | accept `COLORTERM` |
| `~/.config/ghostty/config` | client | get terminfo onto servers |
| `~/.zshrc`; `~/.profile` + `~/.bashrc` | both | keep Claude Code off the alternate screen |

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

### Claude Code on the primary screen

Claude Code draws into the terminal's *alternate screen* — it emits
`ESC[?1049h` at startup — and that second screen buffer has no scrollback: only
the frame currently drawn exists. Nothing older is anywhere for a terminal to
scroll to, so in an nvim panel `<Esc><Esc>` then `gg` lands at the top of the
*visible* frame with the rest of the session unreachable.

```sh
export CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1
```

`~/.zshrc` on the macOS client. On the Linux server it goes in **both**
`~/.profile` and `~/.bashrc`, for the same reason Homebrew's line does: login
shells read the first, interactive non-login shells (a tmux pane) read only the
second, and neither sources the other.

Claude Code then renders on the primary screen, where its history scrolls off
into the terminal's own scrollback — nvim's terminal buffer (10000 lines, the
default) in a panel, Ghostty's scrollback in a tab. Both machines set it in the
shell so it applies everywhere; `lua/terminal.lua` also sets it on nvim's own
environment, which every shell nvim spawns inherits, so panels keep working on
a machine where the profile line is missing.

To check which screen any program uses, capture it through a pty and look for
the sequence — a count of 1 means it switched, 0 means it stayed put:

```sh
grep -ac '\[?1049h' capture.bin
```

Related variables in the same group, if the mouse behaviour needs adjusting
too: `CLAUDE_CODE_DISABLE_VIRTUAL_SCROLL` (stop Claude Code handling scroll
events itself), `CLAUDE_CODE_SCROLL_SPEED`, `CLAUDE_CODE_DISABLE_MOUSE`.

## Keys

Leader is `Space`. Terminal keys work in terminal mode too, so they reach you
while you are typing in a shell.

| Key | Action |
| --- | --- |
| `<C-h/j/k/l>` | move between windows (also from a terminal) |
| `<C-n>` / `<C-p>` | next / previous — shell inside a terminal, otherwise tab |
| `<C-t>` | new — shell inside a terminal, otherwise tab |
| `<C-x>` | hide the window; on a tab's last window, close the tab |
| `<Esc>` | clear search highlight |
| `<Esc><Esc>` | terminal → normal mode, for scrolling and copying output |
| `<leader>f` `g` `b` `h` | fuzzy: files, live grep, buffers, help |
| `<leader>q` | toggle the file explorer (mini.files) |
| `<leader>e` / `<leader>E` | send line or selection to the **bottom** / side terminal |
| `<leader>r` / `<leader>R` | send a `path:line` reference to the **side** / bottom terminal |
| `<leader>y` / `<leader>Y` | pull the highlighted text into the editor buffer — dedented / verbatim |
| `<leader>]` / `<leader>[` | next / previous shell in a panel, from anywhere |
| `<leader>d` | diagnostics to the location list |
| `<leader>=` | format via the language server |
| `<leader>B` | git blame for this line |
| `<leader>o` | toggle the inline git diff overlay |
| `<leader>1` `2` `3` `u` | mergetool: take LOCAL / BASE / REMOTE, refresh |

Lower case sends commands to the bottom panel and references to the side one,
on purpose: commands belong with the shell you run things in, references belong
with the agent reading them.

A closed panel absorbs the first press: `<leader>e` and `<leader>r` open it and
send nothing, and the press after that delivers. So the send keys double as
"give me a terminal", which is why there is no `<leader>t`. Focus stays in the
editor as the panel opens, so pressing again sends straight away; `<C-l>`
moves into the shell instead. Nothing is fired at a shell that has only just
started, and a visual selection is not consumed — the split ends visual mode,
but `gv` reselects it for the second press. `<C-x>` hides a panel, the same key
that hides any other window.

`<leader>y` is the return path: `<Esc><Esc>` out of a shell, `V` to highlight
output, then `<leader>y` drops it into the editor below its cursor. Focus stays
in the terminal so you can keep picking; successive yanks stack in order rather
than piling up in reverse. It dedents by default, because output almost always
arrives indented and that indentation is rarely wanted; `<leader>Y` keeps it
verbatim. Dedent removes only the *common* indent, so a copied block keeps its
shape.

Scrolling a panel means leaving terminal mode first: `<Esc><Esc>`, then
`<C-b>` / `<C-u>` / `gg` as usual. The window and shell keys above are mapped
in terminal mode and will not scroll, and a full-screen TUI has no history to
offer at all — see [Claude Code on the primary
screen](#claude-code-on-the-primary-screen).

### Insert mode

| Key | Action |
| --- | --- |
| `<C-Space>` | ask for completion by hand (`<C-x><C-o>` also works) |
| `<Tab>` / `<S-Tab>` | jump between snippet placeholders, otherwise a plain Tab |

### Commands

| Command | Action |
| --- | --- |
| `:Venv` | browse for a Python environment; `<CR>` enters a folder or selects it |
| `:Venv <path>` | activate it if it is an environment, otherwise browse from there |
| `:VenvShow` | report the active environment |
| `:Serve [port]` | serve the working directory over HTTP on loopback |
| `:ServeStop` | stop it |
| `:Blame` | git blame for the current line |
| `:SessionRestore` | restore this directory's layout |
| `:PrereqInstall` | brew install any missing external tools |
| `:checkhealth prereq` | report which external tools are missing |

`:Serve` with no argument starts at port 8000 and scans upward for a free one,
so several nvim instances do not collide. Set `vim.g.serve_port` to start that
scan somewhere else — useful when a fixed port is already forwarded over SSH.
An explicit `:Serve <port>` uses exactly that port and says so if it is taken,
rather than quietly serving somewhere you did not ask for.

### Already in nvim or the plugins

Not configured here, but present — worth knowing before installing anything:

| Key | From |
| --- | --- |
| `gcc` / `gc` | comment toggle — **built in**, no plugin needed |
| `]q` `[q` `]l` `[l` `]b` `[b` `]a` `[a` | quickfix, loclist, buffer, arglist navigation |
| `]d` `[d` `]D` `[D` | next / previous / first / last diagnostic |
| `]<Space>` `[<Space>` | add an empty line below / above |
| `gx` | open the file or URL under the cursor |
| `<C-w>d` | diagnostics for the line in a float |
| `<C-s>` | signature help, in insert mode |
| `]h` `[h` `]H` `[H` `gh` `gH` | git hunks: move, first/last, apply, reset (mini.diff) |
| `]n` `[n` `an` `in` | treesitter node selection (nvim-treesitter) |

### LSP and code navigation

Go-to-definition is the built-in tag jump: on LSP attach nvim sets
`tagfunc=v:lua.vim.lsp.tagfunc`, so the tag keys ask the language server.

| Key | Action |
| --- | --- |
| `<C-]>` | go to definition |
| `<C-o>` | jump back (jumplist; tag jumps land in it too) |
| ~~`<C-t>`~~ | the tag-stack jump back, **remapped** to "new shell/tab" — use `<C-o>` |
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
init.lua              sets the leader, then requires the modules below
lua/options.lua       editor options
lua/keymaps.lua       general keys, window and tab movement, window hiding
lua/autocmds.lua      yank highlight, whitespace trim, cursor restore
lua/reload.lua        instant reload when a file changes on disk
lua/treesitter.lua    treesitter highlighting
lua/lsp.lua           diagnostics, completion, per-buffer LSP setup
lua/plugins.lua       vim.pack and the four plugins, with their keys
lua/diffs.lua         diff colours, mergetool keys, git blame
lua/session.lua       per-directory window/tab layout
lua/serve.lua         the HTTP file server
lua/venv.lua          switching Python environment without restarting
lua/terminal.lua      the terminal panels, their shells, and their keys
lua/prereq/           external tool checks (:checkhealth prereq)
lsp/*.lua             one table per language server
nvim-pack-lock.json   pinned plugin revisions
```

## Notes

- State that survives closing nvim: undo history ('undofile'), marks,
  registers and search/command history (shada), and the window/tab layout per
  directory. Terminal windows come back too, with their shells restarted —
  live, but with no scrollback, and only the ones that were visible in a
  window. Restored terminals are adopted by the panel keys, and get the
  project environment sourced — nvim restarts those shells itself, so they
  never pass through the code that would otherwise activate the venv. Bare
  `nvim` in a directory restores its layout; `nvim foo.py` just opens that
  file. `:SessionRestore` restores on demand. Headless runs neither save nor
  restore, so scripts cannot clobber a layout.
- Completion is nvim's built-in LSP completion. `autotrigger` alone only fires
  on the server's trigger characters — for basedpyright `.` `[` `"` `'` — so
  it covers `foo.` but never a bare identifier. A `TextChangedI` autocommand
  asks for completion once two word characters have been typed, which is what
  makes variables complete. `<C-Space>` triggers it by hand, `<C-x><C-o>` also
  works. 'completeopt' uses `noselect` so `<CR>` stays a newline.
- Buffers reload the instant a file changes on disk — a git checkout, a
  formatter, an agent — using the OS's own notifications (inotify / FSEvents),
  measured at 2-11 ms. The watch is on the file's *directory*, not the file:
  atomic writers replace the inode, and a watch on the file itself would then
  be pointing at a dead one. Unsaved edits are never lost: nvim warns with
  `W12` and keeps your version.
- Images, video and PDFs: nvim cannot draw them, and a terminal render has no
  zoom or pan. Use `:Serve` and open `http://127.0.0.1:8000` in a browser —
  over SSH forward it with `ssh -L 8000:localhost:8000 <host>`. That gives real
  zoom, pan, video seeking and a PDF viewer. The server is `copyparty`, which
  *renders* what it serves instead of leaving the browser to guess from a MIME
  type: source files and markdown open in its own viewer, PDFs inline, media in
  a player, all over Range requests. A plain static server cannot manage this —
  a browser downloads whatever it has no viewer for, which is every `.md`,
  `.lua` and `.yaml`, and under miniserve every PDF too, since it marks those
  `Content-Disposition: attachment`. python3's `http.server` is the fallback
  when copyparty is missing; it downloads everything and has no Range support,
  so video cannot seek. copyparty's thumbnail and index cache is pointed at
  `stdpath("cache")/copyparty`, so it leaves no `.hist` folder inside the
  project being served.
- Python environment: `:Venv` browses for one, sets `$VIRTUAL_ENV` and `$PATH`,
  restarts basedpyright against the new interpreter, sources it in terminals
  that are already open, and makes new shells source it too. No nvim restart
  needed. Shells that are *busy* are skipped and reported: sending `source ...`
  to a shell running a REPL or an agent would go to that program as input, not
  to the shell. A shell at its prompt has no child processes, which is the test.
  The choice is remembered per working directory under `stdpath("state")/venvs`,
  so a restart keeps it — otherwise an environment living outside the project
  would be lost, since the upward search cannot see it. A venv activated in the
  shell that launched nvim wins over the remembered one, and a remembered venv
  that has been deleted is forgotten rather than failing every startup.
- A full-screen TUI in a panel keeps no history nvim can reach, because the
  alternate screen has no scrollback. For Claude Code there is a variable that
  fixes it, set on both machines — see [Claude Code on the primary
  screen](#claude-code-on-the-primary-screen).
- Clipboard: yanks go out over OSC 52, so they reach the local clipboard from
  any machine with nothing installed at either end. Pasting deliberately does
  *not* use it. Reading a clipboard over OSC 52 means asking the terminal and
  waiting for an answer — nvim blocks a second, prints "Waiting for OSC 52
  response ... Ctrl-C to interrupt", then waits nine more — and Ghostty
  defaults to `clipboard-read = ask`, so every `p` sat behind a prompt. `p`
  answers from nvim's own register instead: instant, and it cannot hang. Text
  copied in *another* application comes in through the terminal's own paste
  (Cmd/Ctrl-V), which arrives as a bracketed paste and works in any mode.
- Update plugins: `:lua vim.pack.update()`, review the diff, `:w` to apply.
- Add a parser: `:lua require("nvim-treesitter").install({"go"})`.
