#!/usr/bin/env bash
# Set up WezTerm + zsh + Starship from this repo.
# Run from Git Bash on Windows, or from a shell on WSL / Linux / macOS.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_MSYS_PKG="zsh-5.9-3-x86_64.pkg.tar.zst"   # newer builds need a newer MSYS runtime than Git ships
NERD_FONT="JetBrainsMono"

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) OS=windows ;;
  Darwin)               OS=mac ;;
  *)                    OS=linux ;;
esac

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

backup() {
  [[ -e "$1" || -L "$1" ]] || return 0
  local dest="$1.bak.$(date +%Y%m%d%H%M%S)"
  mv "$1" "$dest"
  warn "backed up $1 -> $dest"
}

# ---- Windows ----------------------------------------------------------------

win_set_env() {
  powershell.exe -NoProfile -Command "[Environment]::SetEnvironmentVariable('$1', '$2', 'User')" >/dev/null
  ok "$1 = $2"
}

win_winget() {
  local id="$1" exe="$2"
  if [[ -x "$exe" ]]; then ok "$id already installed"; return; fi
  info "Installing $id"
  winget.exe install --id "$id" -e --silent --accept-source-agreements --accept-package-agreements
}

win_install_zsh() {
  local git_root
  git_root="$(cygpath -w /)"
  git_root="${git_root%\\}"
  if [[ -x /usr/bin/zsh.exe ]]; then ok "zsh already installed in Git Bash"; return; fi

  info "Installing zsh into Git for Windows ($git_root)"
  local tmp; tmp="$(mktemp -d)"
  curl -fsSL "https://mirror.msys2.org/msys/x86_64/$ZSH_MSYS_PKG" -o "$tmp/zsh.pkg.tar.zst"

  local zstd_url
  zstd_url="$(curl -fsSL https://api.github.com/repos/facebook/zstd/releases/latest | grep -oE 'https://[^"]*win64\.zip' | head -1)"
  curl -fsSL "$zstd_url" -o "$tmp/zstd.zip"
  (cd "$tmp" && unzip -q zstd.zip)
  "$(find "$tmp" -name zstd.exe | head -1)" -dq "$tmp/zsh.pkg.tar.zst" -o "$tmp/zsh.tar"
  mkdir -p "$tmp/root" && tar -xf "$tmp/zsh.tar" -C "$tmp/root"

  # Program Files needs admin: copy via an elevated robocopy (UAC prompt)
  local src; src="$(cygpath -w "$tmp/root")"
  powershell.exe -NoProfile -Command \
    "\$p = Start-Process robocopy -ArgumentList '\"$src\" \"$git_root\" /E /NFL /NDL /NJH /NJS' -Verb RunAs -Wait -PassThru; exit [int](\$p.ExitCode -ge 8)"
  rm -rf "$tmp"
  /usr/bin/zsh.exe --version && ok "zsh installed"
}

win_install_font() {
  local fonts_dir; fonts_dir="$(cygpath -u "$LOCALAPPDATA")/Microsoft/Windows/Fonts"
  if ls "$fonts_dir"/${NERD_FONT}NerdFont-*.ttf >/dev/null 2>&1; then ok "$NERD_FONT Nerd Font already installed"; return; fi

  info "Installing $NERD_FONT Nerd Font (per-user)"
  local tmp; tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$NERD_FONT.zip" -o "$tmp/font.zip"
  (cd "$tmp" && unzip -q font.zip "${NERD_FONT}NerdFont-*.ttf")
  mkdir -p "$fonts_dir"
  local f name
  for f in "$tmp"/${NERD_FONT}NerdFont-*.ttf; do
    name="$(basename "$f")"
    cp "$f" "$fonts_dir/"
    reg.exe add 'HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts' \
      //v "${name%.ttf} (TrueType)" //t REG_SZ //d "$(cygpath -w "$fonts_dir/$name")" //f >/dev/null
  done
  rm -rf "$tmp"
  ok "font installed (restart apps to pick it up)"
}

setup_windows() {
  win_winget wez.wezterm "/c/Program Files/WezTerm/wezterm-gui.exe"
  win_winget Starship.Starship "/c/Program Files/starship/bin/starship.exe"
  win_install_zsh
  win_install_font

  info "Pointing WezTerm and Starship at this repo"
  win_set_env WEZTERM_CONFIG_FILE "$(cygpath -w "$DOTFILES/wezterm/.wezterm.lua")"
  win_set_env STARSHIP_CONFIG "$(cygpath -w "$DOTFILES/starship/starship.toml")"
}

# ---- Linux / WSL / macOS -----------------------------------------------------

setup_unix() {
  if ! have zsh; then
    info "Installing zsh"
    if have apt-get; then sudo apt-get update -qq && sudo apt-get install -y zsh
    elif have dnf; then sudo dnf install -y zsh
    elif have pacman; then sudo pacman -S --noconfirm zsh
    elif have brew; then brew install zsh
    else warn "install zsh with your package manager"; fi
  else
    ok "zsh already installed"
  fi

  if have starship || [[ -x ~/.local/bin/starship ]]; then
    ok "starship already installed"
  else
    info "Installing starship to ~/.local/bin"
    mkdir -p ~/.local/bin
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b ~/.local/bin >/dev/null
    ok "starship installed"
  fi

  info "Linking WezTerm config"
  if [[ "$(readlink ~/.wezterm.lua 2>/dev/null)" != "$DOTFILES/wezterm/.wezterm.lua" ]]; then
    backup ~/.wezterm.lua
    ln -s "$DOTFILES/wezterm/.wezterm.lua" ~/.wezterm.lua
  fi
  ok "~/.wezterm.lua -> $DOTFILES/wezterm/.wezterm.lua"

  if [[ "$(basename "${SHELL:-}")" != zsh ]]; then
    warn "default shell is ${SHELL:-unknown}; switch with: chsh -s $(command -v zsh || echo /usr/bin/zsh)"
  fi
}

# ---- Shared -----------------------------------------------------------------

setup_plugins() {
  info "zsh plugins"
  mkdir -p ~/.zsh/plugins
  local p
  for p in zsh-autosuggestions zsh-syntax-highlighting zsh-completions; do
    if [[ -d ~/.zsh/plugins/$p/.git ]]; then
      git -C ~/.zsh/plugins/$p pull -q --ff-only && ok "$p updated"
    else
      git -c core.autocrlf=false clone -q --depth 1 "https://github.com/zsh-users/$p" ~/.zsh/plugins/$p && ok "$p cloned"
    fi
  done
}

setup_zshrc() {
  info "Linking ~/.zshrc"
  local line="source \"$DOTFILES/zsh/.zshrc\""
  if [[ -f ~/.zshrc && ! -L ~/.zshrc ]] && grep -qxF "$line" ~/.zshrc; then
    ok "~/.zshrc already loads $DOTFILES/zsh/.zshrc"
    return
  fi
  backup ~/.zshrc
  printf '%s\n' "$line" > ~/.zshrc
  ok "~/.zshrc -> $DOTFILES/zsh/.zshrc (put machine-specific bits in ~/.zshrc.local)"

  # an old standalone starship config would be ignored now; keep it out of the way
  [[ -f ~/.config/starship.toml && ! -L ~/.config/starship.toml ]] && backup ~/.config/starship.toml
  return 0
}

info "Installing dotfiles from $DOTFILES ($OS)"
if [[ $OS == windows ]]; then setup_windows; else setup_unix; fi
setup_plugins
setup_zshrc
info "Done. Open a new terminal to load everything."
