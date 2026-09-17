# VS Code setup

Reproduces this VS Code configuration on a fresh macOS or Linux machine.

```sh
./setup.sh
```

Idempotent — re-running reports "already satisfied" instead of repeating work.
Same check/fix structure as [`../nvim/setup.sh`](../nvim/setup.sh).

## What is here

| File | Contents |
| --- | --- |
| `keybindings.json` | `alt+*` workbench bindings — pane navigation (`hjkl`), terminal, quick open, search |
| `settings.json` | User settings |
| `extensions.txt` | Extension ids, one per line, installed via `code --install-extension` |
| `setup.sh` | Installs extensions, copies the two config files into the user directory |

## Where things land

| Platform | User directory |
| --- | --- |
| macOS | `~/Library/Application Support/Code/User/` |
| Linux | `${XDG_CONFIG_HOME:-~/.config}/Code/User/` |

Only `keybindings.json` and `settings.json` are touched; anything already there
is backed up alongside as `<name>.bak.<timestamp>` before being replaced.

## Doing it by hand

```sh
code --install-extension anthropic.claude-code
code --install-extension vscodevim.vim
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance
code --install-extension ms-python.vscode-python-envs
code --install-extension ms-python.debugpy
code --install-extension ms-vscode-remote.vscode-remote-extensionpack

cp keybindings.json settings.json ~/Library/Application\ Support/Code/User/
```

`code` is not on `PATH` after a fresh macOS install — run **Shell Command:
Install 'code' command in PATH** from the command palette, or call the binary
directly at
`/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code`.
`setup.sh` finds it either way.

## Capturing changes back

```sh
cp ~/Library/Application\ Support/Code/User/{keybindings.json,settings.json} .
code --list-extensions          # reconcile against extensions.txt
```
