# dotfiles

WezTerm + zsh + Starship, Catppuccin Mocha everywhere.

| | |
|---|---|
| `wezterm/.wezterm.lua` | WezTerm config (zsh as default shell on Windows) |
| `zsh/.zshrc` | zsh options, completion, keybindings, plugins, Starship |
| `starship/starship.toml` | Powerline prompt |

## Install

```sh
git clone https://github.com/MatthewPocock/dotfiles ~/repos/dotfiles
~/repos/dotfiles/install.sh
```

Run it from **Git Bash** on Windows, or from a shell on **WSL / Linux / macOS**. It's safe to re-run, and any file it replaces is backed up as `*.bak.<timestamp>`.

**Everywhere**
- clones `zsh-autosuggestions`, `zsh-syntax-highlighting` and `zsh-completions` into `~/.zsh/plugins`
- writes a one-line `~/.zshrc` that sources `zsh/.zshrc` from this repo

**Windows (Git Bash)**
- installs WezTerm and Starship with winget
- installs zsh into Git for Windows from the MSYS2 package (asks for admin via UAC)
- installs JetBrainsMono Nerd Font for the current user
- sets `WEZTERM_CONFIG_FILE` and `STARSHIP_CONFIG` to point at this repo

**WSL / Linux / macOS**
- installs zsh with the system package manager and Starship into `~/.local/bin`
- symlinks `~/.wezterm.lua` to this repo

On WSL you can run the installer from the Windows clone (`/mnt/c/Users/<you>/repos/dotfiles/install.sh`) so both sides share one copy.

Put machine-specific settings or secrets in `~/.zshrc.local`. It's sourced last and never committed.

### Not automated
- Making zsh the default shell on Linux: `chsh -s $(which zsh)`
- Windows Terminal: add a profile with the command line
  `"C:/Program Files/Git/usr/bin/env.exe" MSYSTEM=MINGW64 CHERE_INVOKING=1 /usr/bin/zsh.exe --login -i`
  and the font `JetBrainsMono Nerd Font`
