# Loaded from ~/.zshrc (see install.sh). Works in Git Bash zsh, WSL, Linux and macOS.

DOTFILES=${${(%):-%x}:A:h:h}
export STARSHIP_CONFIG=$DOTFILES/starship/starship.toml
[[ $OSTYPE == msys* ]] && STARSHIP_CONFIG=$(cygpath -m "$STARSHIP_CONFIG")

# ---- PATH ------------------------------------------------------------------
typeset -U path
[[ -d ~/.local/bin ]] && path=(~/.local/bin $path)

# ---- History ---------------------------------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS
setopt SHARE_HISTORY INC_APPEND_HISTORY

# ---- General options -------------------------------------------------------
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT
setopt INTERACTIVE_COMMENTS NO_BEEP EXTENDED_GLOB

# ---- Completion ------------------------------------------------------------
fpath=(~/.zsh/plugins/zsh-completions/src $fpath)
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) || ! -e ~/.zcompdump ]]; then compinit 2>/dev/null; else compinit -C; fi
zmodload zsh/complist
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# ---- Key bindings ----------------------------------------------------------
bindkey -e
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[4~' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^H' backward-kill-word
bindkey '^[[3;5~' kill-word
bindkey -M menuselect '^[[Z' reverse-menu-complete

# ---- Aliases ---------------------------------------------------------------
alias ls='ls --color=auto --group-directories-first'
alias ll='ls -lAh'
alias la='ls -A'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias gst='git status -sb'
alias gl='git log --oneline --graph --decorate -20'
if [[ -n $WSL_DISTRO_NAME ]]; then alias open='explorer.exe'
elif [[ $OSTYPE == msys* || $OSTYPE == cygwin* ]]; then alias open='start'
fi
eval "$(dircolors -b 2>/dev/null)"

# ---- Plugins ---------------------------------------------------------------
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6c7086'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
source ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ---- Prompt ----------------------------------------------------------------
[[ -x "/c/Program Files/starship/bin/starship.exe" ]] && ! command -v starship >/dev/null && \
  path+=("/c/Program Files/starship/bin")
if command -v starship >/dev/null 2>&1; then
  # starship's init loses its quoting when the exe path has a space (C:\Program Files)
  eval "$(starship init zsh --print-full-init | sed "s|''\([^']*starship\.exe\)''|\"\1\"|g")"
fi

[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
