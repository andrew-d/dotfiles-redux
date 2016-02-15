#
# bashrc
#
# This file contains configuration that is not shell- or operating
# system-specific.
#
#


# Enable vi-style keybindings
set -o vi

# Check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# Autocorrect typos in path names when using `cd`
shopt -s cdspell

# Ignore Ctrl-D once before logging out.
export IGNOREEOF=1

# SSH auto-completion based on entries in known_hosts.
if [[ -e ~/.ssh/known_hosts ]]; then
  complete -o default -W "$(cat ~/.ssh/known_hosts | sed 's/[, ].*//' | sort | uniq | grep -v '[0-9]')" ssh scp stfp
fi

# Sexy sexy prompt - stolen from:
# https://github.com/mathiasbynens/dotfiles/blob/master/.bash_prompt
if [[ $COLORTERM = gnome-* && $TERM = xterm ]] && infocmp gnome-256color >/dev/null 2>&1; then
  export TERM=gnome-256color
elif infocmp xterm-256color >/dev/null 2>&1; then
  export TERM=xterm-256color
fi

# Create color variables
if tput setaf 1 &> /dev/null; then
  tput sgr0
  if [[ $(tput colors) -ge 256 ]] 2>/dev/null; then
    MAGENTA=$(tput setaf 9)
    ORANGE=$(tput setaf 172)
    GREEN=$(tput setaf 190)
    PURPLE=$(tput setaf 141)
    WHITE=$(tput setaf 256)
  else
    MAGENTA=$(tput setaf 5)
    ORANGE=$(tput setaf 4)
    GREEN=$(tput setaf 2)
    PURPLE=$(tput setaf 1)
    WHITE=$(tput setaf 7)
  fi
  BOLD=$(tput bold)
  RESET=$(tput sgr0)
else
  MAGENTA="\033[1;31m"
  ORANGE="\033[1;33m"
  GREEN="\033[1;32m"
  PURPLE="\033[1;35m"
  WHITE="\033[1;37m"
  BOLD=""
  RESET="\033[m"
fi

export MAGENTA
export ORANGE
export GREEN
export PURPLE
export WHITE
export BOLD
export RESET

function parse_git_dirty() {
  [[ $(git status 2> /dev/null | tail -n1) != "nothing to commit (working directory clean)" ]] && echo "*"
}

function parse_git_branch() {
  git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e "s/* \(.*\)/\1$(parse_git_dirty)/"
}

PS1="\[${BOLD}${MAGENTA}\]\u \[$RESET\]at \[$ORANGE\]\h \[$RESET\]in \[$GREEN\]\w\[$RESET\]\$([[ -n \$(git branch 2> /dev/null) ]] && echo \" on \")\[$PURPLE\]\$(parse_git_branch)\[$RESET\]\n\$ \[$RESET\]"

# TODO: use this one from minibashrc?
# export PS1="\[\033[38;5;196m\]\u\[$(tput sgr0)\]\[\033[38;5;15m\] at \[$(tput sgr0)\]\[\033[38;5;208m\]\H\[$(tput sgr0)\]\[\033[38;5;15m\] in \[$(tput sgr0)\]\[\033[38;5;11m\]\w\[$(tput sgr0)\]\[\033[38;5;15m\]\n\[$(tput sgr0)\]\[\033[38;5;5m\]\\$\[$(tput sgr0)\] "


# Bash history config.
export HISTSIZE=32768
export HISTFILESIZE=$HISTSIZE
export HISTCONTROL=ignoredups:ignorespace

# Append to the Bash history file, rather than overwriting it
shopt -s histappend

# Make some commands not show up in history
export HISTIGNORE="ls:[bf]g:pwd:exit:date:clear"

# If possible, add tab completion for more commands
[[ -f /etc/bash_completion ]] && source /etc/bash_completion

# Try to find pythonz
[[ -s $HOME/.pythonz/etc/bashrc ]] && . $HOME/.pythonz/etc/bashrc


# ------------------------------------------------------------
# If the OS-specific config file exists, then we use it.
_DOTFILES_LOCAL="$HOME/.bashrc.$(uname -s | tr '[:upper:]' '[:lower:]')"
if [ -f "$_DOTFILES_LOCAL" ]; then
  . "$_DOTFILES_LOCAL"
fi
unset _DOTFILES_LOCAL

# vim: set filetype=sh:
