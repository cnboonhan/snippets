#!/usr/bin/env bash
# Install this Neovim config on macOS or Linux. Idempotent: re-running is safe
# and reports "already satisfied" rather than repeating work.
#
#   ./setup.sh
#
# Structure: every concern is a validation function and a remediation function.
# main() is nothing but the list of those pairs, in dependency order. A check
# never changes the machine (so a satisfied machine is never touched), a fix
# is only reached when its check failed, and require() re-runs the check
# afterwards so a fix that silently did nothing is an error rather than a lie.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
ITEMS=(init.lua lsp lua nvim-pack-lock.json)
PARSERS=(python)
GIT_SETTINGS=(
    merge.tool=nvimdiff
    diff.tool=nvimdiff
    mergetool.prompt=false
    mergetool.keepBackup=false
    merge.conflictstyle=zdiff3
)
BREW=  # set by brew_exists, used by every fix that installs something

step() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
info() { printf '   %s\n' "$*"; }
die()  { printf '\n!! %s\n' "$*" >&2; exit 1; }

# require LABEL CHECK FIX -- the only control flow in this script.
require() {
    local label="$1" check="$2" fix="$3"
    step "$label"
    if "$check"; then info "already satisfied"; return 0; fi
    "$fix"
    "$check" || die "$label: $check still fails after $fix"
}

# ----------------------------------------------------------------- compiler

# `command -v cc` is not enough on macOS: /usr/bin/cc exists as a stub before
# the Command Line Tools are installed and only fails when actually run. The
# parsers are C, so the honest check is to compile something.
cc_works() {
    local t rc
    t="$(mktemp -d)"
    echo 'int main(void) { return 0; }' > "$t/probe.c"
    cc -o "$t/probe" "$t/probe.c" >/dev/null 2>&1
    rc=$?
    rm -rf "$t"
    return $rc
}

# Nothing here can finish the job synchronously: on macOS the Command Line
# Tools are a GUI download that runs on its own, and on Linux Homebrew needed a
# compiler to bootstrap at all, so a missing one means the distro build tools
# were never installed. Both cases end in instructions and a re-run.
cc_install() {
    if [ "$(uname -s)" = "Darwin" ]; then
        xcode-select --install 2>/dev/null || true
        die 'no working C compiler. Accept the Command Line Tools install that
   just opened (or run: xcode-select --install), let it finish, then re-run.'
    fi
    die 'no working C compiler. Install the distro build tools, then re-run:
   Debian/Ubuntu  sudo apt install build-essential
   Arch           sudo pacman -S base-devel
   Fedora         sudo dnf group install development-tools'
}

# ------------------------------------------------------------------- homebrew

find_brew() {
    command -v brew && return 0
    for p in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
        [ -x "$p" ] && { echo "$p"; return 0; }
    done
    return 1
}

# The one check with a side effect, deliberately: everything downstream needs
# brew's environment, and this is the single place that knows where brew is.
brew_exists() {
    BREW="$(find_brew)" || return 1
    eval "$("$BREW" shellenv)"
    info "using $BREW"
}

brew_install() {
    die 'Homebrew not found. Install it, then re-run:
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   Linux also needs distro build tools first (build-essential / base-devel).'
}

# Homebrew on Linux lives outside the default PATH, so future shells need the
# shellenv line. macOS installs into a path the system already searches.
# Whether ~/.bashrc puts brew on PATH *before* it abandons non-interactive
# shells. Presence is not enough: Ubuntu's stock file already mentions brew far
# below that early return, where `ssh host command` never reaches -- which is
# how this looked satisfied while mosh-server stayed missing. Compare line
# numbers instead.
bashrc_brew_is_early() {
    local first guard
    first=$(grep -n -m1 -F "$(dirname "$BREW")" "$HOME/.bashrc" 2>/dev/null | cut -d: -f1)
    [ -n "$first" ] || return 1
    guard=$(grep -n -m1 -E '^[[:space:]]*\*\)[[:space:]]*return' "$HOME/.bashrc" 2>/dev/null | cut -d: -f1)
    [ -n "$guard" ] || return 0
    [ "$first" -lt "$guard" ]
}

brew_on_path() {
    [ "$(uname -s)" = "Linux" ] || { info "macOS - not needed"; return 0; }
    grep -q 'brew shellenv' "$HOME/.profile" 2>/dev/null || return 1
    bashrc_brew_is_early
}

# Two files, because bash reads a different one for each kind of shell and
# neither sources the other:
#
#   login shell      (ssh host, then type)   -> ~/.profile
#   non-interactive  (ssh host command)      -> ~/.bashrc
#
# The second is the one that bites. Ubuntu's ~/.bashrc abandons non-interactive
# shells in its first few lines, so anything appended to it is never reached and
# ~/.profile is not consulted at all -- `ssh host nvim` and, in particular,
# mosh, which starts mosh-server over a non-interactive ssh command and reports
# it as missing. Getting in above that early return is the whole point, so this
# prepends rather than appends.
brew_path_append() {
    local bin tmp
    bin="$(dirname "$BREW")"

    if ! grep -q 'brew shellenv' "$HOME/.profile" 2>/dev/null; then
        printf '\n# Homebrew\neval "$(%s shellenv)"\n' "$BREW" >> "$HOME/.profile"
        info "appended shellenv to ~/.profile"
    fi

    if ! bashrc_brew_is_early; then
        tmp="$(mktemp)"
        {
            printf '# Homebrew, above the non-interactive early return below:\n'
            printf '# `ssh host command` reads this file and nothing else, and mosh\n'
            printf '# starts mosh-server exactly that way.\n'
            printf 'export PATH=%s:$PATH\n\n' "$bin"
            cat "$HOME/.bashrc" 2>/dev/null
        } > "$tmp"
        # cat rather than mv, so the file keeps its own permissions.
        cat "$tmp" > "$HOME/.bashrc"
        rm -f "$tmp"
        info "prepended PATH to ~/.bashrc"
    fi
}

# ------------------------------------------------------------------- packages

nvim_exists() { command -v nvim >/dev/null 2>&1; }
nvim_install() { info "installing neovim"; "$BREW" install neovim; }

# The config's own requirement list decides what is needed, so a new tool is
# added in one place rather than two that drift apart -- which is how the file
# server once ended up missing from this script. It reports what is *missing*
# rather than everything it wants, so a tool the system already provides is
# left alone: git and curl exist on any machine that can run brew, and
# installing Homebrew's copies over them is pure waste. This is the same list
# :checkhealth prereq reports from. It needs nvim, which is why it runs after
# it. This script is the only thing that installs: the config only reports.
missing_formulae() {
    nvim --headless --clean --cmd "set runtimepath^=$REPO" -c 'lua
        local out = {}
        for _, r in ipairs(require("prereq").missing()) do
            if r.pkg then out[#out + 1] = r.pkg end
        end
        io.write(table.concat(out, " "))' -c 'qa!' 2>/dev/null
}

tools_exist() { [ -z "$(missing_formulae)" ]; }

tools_install() {
    local missing=()
    read -ra missing <<<"$(missing_formulae)"
    info "installing: ${missing[*]}"
    "$BREW" install "${missing[@]}"
    # A formula that is installed but unlinked stays off PATH: `install` only
    # warns about it. Linking is a no-op for anything just installed.
    "$BREW" link "${missing[@]}" >/dev/null 2>&1 || true
}

# --------------------------------------------------------------------- config

config_installed() {
    local i
    for i in "${ITEMS[@]}"; do
        diff -rq "$REPO/$i" "$NVIM_DIR/$i" >/dev/null 2>&1 || return 1
    done
}

config_install() {
    if [ -e "$NVIM_DIR" ]; then
        local bak="$NVIM_DIR.bak.$(date +%Y%m%d%H%M%S)"
        mv "$NVIM_DIR" "$bak"; info "existing config backed up to $bak"
    fi
    mkdir -p "$NVIM_DIR"
    local i
    for i in "${ITEMS[@]}"; do cp -R "$REPO/$i" "$NVIM_DIR/"; done
    info "installed $(printf '%s ' "${ITEMS[@]}")"
}

git_configured() {
    local kv
    for kv in "${GIT_SETTINGS[@]}"; do
        [ "$(git config --global "${kv%%=*}" 2>/dev/null)" = "${kv#*=}" ] || return 1
    done
}

git_configure() {
    local kv
    for kv in "${GIT_SETTINGS[@]}"; do
        git config --global "${kv%%=*}" "${kv#*=}"
    done
    info "${GIT_SETTINGS[*]}"
}

# --------------------------------------------------- plugins and parsers

nvim_data() { nvim --headless --clean -c 'lua io.write(vim.fn.stdpath("data"))' -c 'qa!' 2>/dev/null; }

# Names come from the lock file, so adding a plugin needs no edit here.
# vim.pack unpacks each one into site/pack/core/opt/<name>.
plugins_installed() {
    [ -z "$(nvim --headless --clean -c "lua
        local root = vim.fs.joinpath(vim.fn.stdpath('data'), 'site', 'pack', 'core', 'opt')
        local lock = vim.json.decode(table.concat(vim.fn.readfile('$REPO/nvim-pack-lock.json'), '\n'))
        for name in pairs(lock.plugins) do
            if vim.fn.isdirectory(vim.fs.joinpath(root, name)) == 0 then io.write(name, ' ') end
        end" -c 'qa!' 2>/dev/null)" ]
}

# Starting nvim is the install: plugins.lua calls vim.pack.add with
# confirm = false, pinned by nvim-pack-lock.json.
plugins_install() {
    info "starting nvim once to let vim.pack fetch them"
    nvim --headless -c 'qa!' >/dev/null 2>&1 || true
}

parsers_installed() {
    local dir p
    dir="$(nvim_data)/site/parser"
    for p in "${PARSERS[@]}"; do [ -f "$dir/$p.so" ] || return 1; done
}

parsers_install() {
    local list
    list="$(printf '"%s",' "${PARSERS[@]}")"
    info "compiling: ${PARSERS[*]}"
    nvim --headless \
        -c "lua require('nvim-treesitter').install({${list%,}}):wait(300000)" \
        -c 'qa!' 2>&1 | grep -iE 'error|installed' | sed 's/^/   /' || true
}

# --------------------------------------------------------------------- result

summary() {
    step "Result"
    nvim --headless -c 'lua
        local m = require("prereq").missing()
        if #m == 0 then print("   all external tools present")
        else
            print("   missing " .. #m .. " tool(s):")
            for _, r in ipairs(m) do print("     " .. r.bin .. " -- " .. r.why) end
        end' -c 'qa!' 2>&1 | grep -vE '^\s*$' || true
    cat <<'EOF'

   Use a terminal that implements OSC 52 (Ghostty, Kitty, WezTerm,
   iTerm2). macOS Terminal.app does not, and yanks there go nowhere.
EOF
    colorterm_server_note
}

# ------------------------------------------------------------------ COLORTERM

# Without it the far end has only TERM to go on. Over plain ssh that is usually
# enough, since a terminal's own terminfo says truecolor -- but mosh replaces
# TERM with its own xterm-256color whatever the client is, so terminfo then
# says 256 and colours silently degrade. Declaring it on the connection fixes
# both, and mosh inherits it because mosh shells out to ssh.
#
# Host * rather than a named host: this needs no hostname, so it stays true for
# machines added later. A server that does not accept the variable ignores it.
colorterm_sent() {
    ssh -G localhost 2>/dev/null | grep -qiE '^setenv .*COLORTERM=truecolor'
}

colorterm_send() {
    mkdir -p "$HOME/.ssh"
    # Prepended: ssh takes the first value it sees for a keyword, so a later
    # Host block cannot override this, and a Host * at the bottom would lose to
    # anything above it.
    local tmp; tmp="$(mktemp)"
    {
        printf '# Tell every host this terminal does truecolor. Needed under mosh,\n'
        printf '# which forces TERM=xterm-256color and would otherwise degrade colour.\n'
        printf 'Host *\n  SetEnv COLORTERM=truecolor\n\n'
        cat "$HOME/.ssh/config" 2>/dev/null
    } > "$tmp"
    cat "$tmp" > "$HOME/.ssh/config"
    rm -f "$tmp"
    chmod 600 "$HOME/.ssh/config"
    info "prepended Host * SetEnv COLORTERM=truecolor to ~/.ssh/config"
}

# The other half lives on the machine being connected *to* and needs root, so
# it is reported rather than done.
colorterm_server_note() {
    [ "$(uname -s)" = "Linux" ] || return 0
    grep -rqs '^AcceptEnv.*COLORTERM' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/ && return 0
    cat <<'EOF'

   This machine's sshd drops COLORTERM, so clients cannot declare truecolor.
   To accept it:
     echo 'AcceptEnv COLORTERM' | sudo tee /etc/ssh/sshd_config.d/99-colorterm.conf
     sudo sshd -t && sudo systemctl reload ssh
EOF
}

# ----------------------------------------------------------------------- tmux

# tmux defaults set-clipboard to "external", which reserves the system
# clipboard for its own copy-mode and silently drops OSC 52 coming from a
# program inside it -- so a yank in nvim never reaches the terminal at the far
# end of the ssh connection, with no error anywhere. "on" lets it through.
tmux_conf() {
    if [ -f "$HOME/.tmux.conf" ]; then
        echo "$HOME/.tmux.conf"
    elif [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf" ]; then
        echo "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
    else
        echo "$HOME/.tmux.conf"
    fi
}

tmux_clipboard_ok() {
    command -v tmux >/dev/null 2>&1 || { info "tmux not installed - not needed"; return 0; }
    grep -qE '^[[:space:]]*set(-option)?[[:space:]]+-g[[:space:]]+set-clipboard[[:space:]]+on' \
        "$(tmux_conf)" 2>/dev/null
}

tmux_clipboard_set() {
    local f; f="$(tmux_conf)"
    mkdir -p "$(dirname "$f")"
    cat >> "$f" <<'CONF'

# Let programs inside tmux set the system clipboard with OSC 52 -- a yank in
# nvim above all. The default, "external", keeps that for tmux's own copy-mode
# and drops the application's sequence without a word.
set -g set-clipboard on
CONF
    info "appended set-clipboard on to $f"
    # A server already running keeps its old value until told otherwise.
    if tmux set -g set-clipboard on 2>/dev/null; then
        info "applied to the running tmux server too"
    fi
}

# ------------------------------------------------------------------ main flow

main() {
    require "C compiler for treesitter"         cc_works          cc_install
    require "Homebrew"                          brew_exists       brew_install
    require "Homebrew on PATH for ssh sessions"  brew_on_path      brew_path_append
    require "Neovim"                            nvim_exists       nvim_install
    require "External tools the config needs"   tools_exist       tools_install
    require "Config in $NVIM_DIR"               config_installed  config_install
    require "git as merge/diff tool"            git_configured    git_configure
    require "Plugins"                           plugins_installed plugins_install
    require "Treesitter parsers"                parsers_installed parsers_install
    require "COLORTERM sent to remote hosts"    colorterm_sent    colorterm_send
    require "tmux may set the clipboard"        tmux_clipboard_ok tmux_clipboard_set
    summary
}

main
