#!/usr/bin/env bash
# Install this VS Code config on macOS or Linux. Idempotent: re-running is safe
# and reports "already satisfied" rather than repeating work.
#
#   ./setup.sh
#
# Same shape as ../nvim/setup.sh: every concern is a validation function and a
# remediation function, and main() is nothing but those pairs in dependency
# order. A check never changes the machine, a fix is only reached when its
# check failed, and require() re-runs the check afterwards so a fix that
# silently did nothing is an error rather than a lie.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ITEMS=(keybindings.json settings.json)
CODE=      # set by code_exists, used by every extension function
USER_DIR=  # set by code_exists, differs per platform

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

# ---------------------------------------------------------------- vs code cli

# `code` is only on PATH if the user ran "Shell Command: Install 'code' command
# in PATH", which a fresh install has not, so look inside the app bundle too.
find_code() {
    command -v code && return 0
    for p in \
        "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" \
        "$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" \
        /usr/share/code/bin/code \
        /usr/bin/code \
        /snap/bin/code
    do
        [ -x "$p" ] && { echo "$p"; return 0; }
    done
    return 1
}

# A check with a side effect, deliberately: everything downstream needs the CLI
# and the user directory, and this is the single place that knows where both
# are. The user directory is not derivable from the CLI path -- it is a
# platform constant.
code_exists() {
    CODE="$(find_code)" || return 1
    if [ "$(uname -s)" = "Darwin" ]; then
        USER_DIR="$HOME/Library/Application Support/Code/User"
    else
        USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/Code/User"
    fi
    info "using $CODE"
}

code_install() {
    die 'Visual Studio Code not found. Install it, then re-run:
   macOS            brew install --cask visual-studio-code
   Debian/Ubuntu    https://code.visualstudio.com/docs/setup/linux
   Arch             yay -S visual-studio-code-bin'
}

# ------------------------------------------------------------------- settings

config_installed() {
    local i
    for i in "${ITEMS[@]}"; do
        diff -q "$REPO/$i" "$USER_DIR/$i" >/dev/null 2>&1 || return 1
    done
}

# Only the two files this repo owns are replaced, and each is backed up on its
# own: the user directory also holds snippets, history and extension state that
# are not ours to move aside.
config_install() {
    mkdir -p "$USER_DIR"
    local i bak
    for i in "${ITEMS[@]}"; do
        if [ -e "$USER_DIR/$i" ] && ! diff -q "$REPO/$i" "$USER_DIR/$i" >/dev/null 2>&1; then
            bak="$USER_DIR/$i.bak.$(date +%Y%m%d%H%M%S)"
            cp "$USER_DIR/$i" "$bak"; info "existing $i backed up to $bak"
        fi
        cp "$REPO/$i" "$USER_DIR/$i"
    done
    info "installed $(printf '%s ' "${ITEMS[@]}")"
}

# ----------------------------------------------------------------- extensions

wanted_extensions() {
    sed -e 's/#.*//' -e 's/[[:space:]]//g' "$REPO/extensions.txt" | grep -v '^$'
}

# Ids are compared lowercased: --list-extensions echoes the publisher's own
# casing, which does not always match what extensions.txt was written with.
extensions_installed() {
    local have missing=() e
    have="$("$CODE" --list-extensions 2>/dev/null | tr 'A-Z' 'a-z')"
    while read -r e; do
        grep -qxF "$(echo "$e" | tr 'A-Z' 'a-z')" <<<"$have" || missing+=("$e")
    done < <(wanted_extensions)
    [ ${#missing[@]} -eq 0 ] || { info "missing: ${missing[*]}"; return 1; }
}

extensions_install() {
    local e
    while read -r e; do
        info "installing $e"
        "$CODE" --install-extension "$e" --force >/dev/null || die "failed to install $e"
    done < <(wanted_extensions)
}

# ---------------------------------------------------------------------- main

summary() {
    step "Result"
    info "$(wanted_extensions | wc -l | tr -d ' ') extensions and ${#ITEMS[@]} config files in place"
    cat <<'EOF'

   Restart VS Code to pick up the new keybindings.
   The Vim extension owns normal-mode keys; the alt+* bindings in
   keybindings.json are workbench-level and fire from anywhere.
EOF
}

main() {
    require "Visual Studio Code"      code_exists          code_install
    require "Extensions"              extensions_installed extensions_install
    require "Config in the user dir"  config_installed     config_install
    summary
}

main
