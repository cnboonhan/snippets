#!/usr/bin/env bash
# Install this Neovim config on macOS or Linux. Idempotent: re-running is safe
# and reports "already done" rather than repeating work.
#
#   ./setup.sh                    install everything for this machine
#   ./setup.sh ssh-client HOST    let this machine send COLORTERM to HOST
#   ./setup.sh ssh-server         let this machine accept COLORTERM (needs sudo)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
ITEMS=(init.lua lsp lua nvim-pack-lock.json)
PARSERS='{"python"}'

step() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
info() { printf '   %s\n' "$*"; }
die()  { printf '\n!! %s\n' "$*" >&2; exit 1; }

# The config's own requirement list decides what is needed, so a new tool is
# added in one place rather than two that drift apart -- which is how the file
# server once ended up missing from this script. It reports what is *missing*
# rather than everything it wants, so a tool the system already provides is
# left alone: git and curl exist on any machine that can run brew, and
# installing Homebrew's copies over them is pure waste. This is the same list
# :PrereqInstall works from. neovim has to be installed first, since it is what
# answers.
missing_formulae() {
    nvim --headless --clean --cmd "set runtimepath^=$REPO" -c 'lua
        local out = {}
        for _, r in ipairs(require("prereq").missing()) do
            if r.pkg then out[#out + 1] = r.pkg end
        end
        io.write(table.concat(out, " "))' -c 'qa!' 2>/dev/null
}

find_brew() {
    command -v brew && return 0
    for p in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
        [ -x "$p" ] && { echo "$p"; return 0; }
    done
    return 1
}

# ---------------------------------------------------------------- subcommands

ssh_client() {
    local host="${1:-}"
    [ -n "$host" ] || die "usage: $0 ssh-client HOST"
    local cfg="$HOME/.ssh/config"
    mkdir -p "$HOME/.ssh"; touch "$cfg"
    if grep -qiE "^[[:space:]]*Host[[:space:]]+$host([[:space:]]|$)" "$cfg"; then
        info "$cfg already has a Host block for $host - check it sends COLORTERM"
        return
    fi
    cat >> "$cfg" <<EOF

Host $host
  # nvim probes the terminal for truecolor with a DCS +q query that some
  # terminals print as visible junk; sending COLORTERM skips the probe.
  SetEnv COLORTERM=truecolor
EOF
    info "added Host $host with SetEnv COLORTERM=truecolor"
}

ssh_server() {
    local f=/etc/ssh/sshd_config.d/99-colorterm.conf
    if sudo test -f "$f"; then info "$f already exists"; return; fi
    echo 'AcceptEnv COLORTERM' | sudo tee "$f" >/dev/null
    sudo sshd -t || die "sshd config invalid - $f left in place, fix before reloading"
    sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd 2>/dev/null || \
        info "reload sshd yourself to apply"
    info "added AcceptEnv COLORTERM and reloaded sshd"
}

# ------------------------------------------------------------------ main flow

main() {
    step "Homebrew"
    local brew; brew="$(find_brew)" || die \
'Homebrew not found. Install it, then re-run:
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   Linux also needs distro build tools first (build-essential / base-devel).'
    info "using $brew"
    eval "$("$brew" shellenv)"

    step "Linux: Homebrew on PATH for future shells"
    if [ "$(uname -s)" = "Linux" ]; then
        # bashrc returns early for non-interactive shells, so ssh host nvim
        # never sees it; login shells read ~/.profile instead.
        if grep -q 'brew shellenv' "$HOME/.profile" 2>/dev/null; then
            info "$HOME/.profile already sets it"
        else
            printf '\n# Homebrew\neval "$(%s shellenv)"\n' "$brew" >> "$HOME/.profile"
            info "appended to ~/.profile"
        fi
    else
        info "macOS - not needed"
    fi

    step "Packages"
    if "$brew" list --formula neovim >/dev/null 2>&1; then
        info "neovim already installed"
    else
        info "installing neovim"
        "$brew" install neovim
    fi
    local missing=()
    read -ra missing <<<"$(missing_formulae)"
    if [ ${#missing[@]} -eq 0 ]; then
        info "every tool the config needs is already on PATH"
    else
        info "installing: ${missing[*]}"
        "$brew" install "${missing[@]}"
        # A formula that is installed but unlinked stays off PATH: `install`
        # only warns about it. Linking is a no-op for anything just installed.
        "$brew" link "${missing[@]}" >/dev/null 2>&1 || true
    fi
    command -v cc >/dev/null || info "WARNING: no C compiler; treesitter parsers cannot build"

    step "Claude Code on the primary screen"
    # It draws into the terminal's alternate screen, which has no scrollback, so
    # a session cannot be scrolled back through -- in a panel or anywhere else.
    local rcs
    if [ "$(uname -s)" = "Darwin" ]; then
        rcs="$HOME/.zshrc"
    else
        # Ubuntu's rc files do not chain: login shells read the first,
        # interactive non-login ones (a tmux pane) only the second.
        rcs="$HOME/.profile $HOME/.bashrc"
    fi
    for rc in $rcs; do
        if grep -q CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN "$rc" 2>/dev/null; then
            info "$(basename "$rc") already sets it"
        else
            printf '\n# Claude Code renders into the alternate screen, which has no\n# scrollback; staying on the primary screen makes its history scrollable.\nexport CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1\n' >> "$rc"
            info "appended to $(basename "$rc")"
        fi
    done

    step "Config -> $NVIM_DIR"
    local same=1
    for i in "${ITEMS[@]}"; do
        diff -rq "$REPO/$i" "$NVIM_DIR/$i" >/dev/null 2>&1 || { same=0; break; }
    done
    if [ "$same" = 1 ]; then
        info "already identical"
    else
        if [ -e "$NVIM_DIR" ]; then
            local bak
            bak="$NVIM_DIR.bak.$(date +%Y%m%d%H%M%S)"
            mv "$NVIM_DIR" "$bak"; info "existing config backed up to $bak"
        fi
        mkdir -p "$NVIM_DIR"
        for i in "${ITEMS[@]}"; do cp -R "$REPO/$i" "$NVIM_DIR/"; done
        info "installed $(printf '%s ' "${ITEMS[@]}")"
    fi

    step "git as merge/diff tool"
    git config --global merge.tool nvimdiff
    git config --global diff.tool nvimdiff
    git config --global mergetool.prompt false
    git config --global mergetool.keepBackup false
    git config --global merge.conflictstyle zdiff3
    info "merge.tool=nvimdiff conflictstyle=zdiff3"

    step "Plugins and treesitter parsers"
    nvim --headless -c 'qa!' >/dev/null 2>&1 || true
    info "plugins installed (pinned by nvim-pack-lock.json)"
    nvim --headless \
        -c "lua require('nvim-treesitter').install($PARSERS):wait(300000)" \
        -c 'qa!' 2>&1 | grep -iE 'error|installed' | sed 's/^/   /' || true

    step "Result"
    nvim --headless -c 'lua
        local m = require("prereq").missing()
        if #m == 0 then print("   all external tools present")
        else
            print("   missing " .. #m .. " tool(s):")
            for _, r in ipairs(m) do print("     " .. r.bin .. " -- " .. r.why) end
        end' -c 'qa!' 2>&1 | grep -vE '^\s*$' || true
    cat <<'EOF'

   Remaining, if you use this over SSH:
     ./setup.sh ssh-client HOST     on the machine you sit at
     ./setup.sh ssh-server          on the remote host
   And use a terminal that implements OSC 52 (Ghostty, Kitty, WezTerm,
   iTerm2). macOS Terminal.app does not, and yanks there go nowhere.
EOF
}

case "${1:-}" in
    ssh-client) shift; ssh_client "$@" ;;
    ssh-server) ssh_server ;;
    ""|install) main ;;
    *) die "unknown command: $1 (try: install | ssh-client HOST | ssh-server)" ;;
esac
