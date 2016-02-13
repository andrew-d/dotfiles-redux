#!/bin/sh

set -eu


VERSION=0.0.1

# Default configuration
VERBOSITY=2
DOTFILES="$HOME"/.dotfiles
GITHUB_PATH=git://github.com/andrew-d/dotfiles-redux.git
BACKUP_DIR=
DID_BACKUP=0

# Derived variables
CANONICAL="$(cd -P -- "$(dirname -- "$0")" && printf '%s\n' "$(pwd -P)/$(basename -- "$0")")"
SCRIPT_NAME="$(basename "$CANONICAL")"
CURRENT_DIR="$(dirname "$CANONICAL")"
REPO_ROOT="$(cd -P -- "$CURRENT_DIR/../" && printf '%s\n' "$(pwd -P)")"

##################################################
## LOGGING

log_trace() {
  [ $VERBOSITY -lt 5 ] && return
  printf "\033[1;34m==>\033[0m  $@\n" >&2
}

log_debug() {
  [ $VERBOSITY -lt 4 ] && return
  printf "\033[1;34m==>\033[0m  $@\n" >&2
}

log_info() {
  [ $VERBOSITY -lt 3 ] && return
  printf "\033[1;32m==>\033[0m  $@\n" >&2
}

log_info_sub() {
  [ $VERBOSITY -lt 3 ] && return
  printf "\033[1;32m ->\033[0m  $@\n" >&2
}

log_warn() {
  [ $VERBOSITY -lt 2 ] && return
  printf "\033[1;33m==>\033[0m  $@\n" >&2
}

log_error() {
  [ $VERBOSITY -lt 1 ] && return
  printf "\033[1;31m==>\033[0m  $@\n" >&2
}

log_crit() {
  log_error "$@"
  maybe_exit 1
}


##################################################
## UTILITY FUNCTIONS

_are_we_testing() {
  if [ "${__DOTFILES_IS_TEST:-false}" = "true" ]; then
    return 0
  else
    return 1
  fi
}

maybe_exit() {
  if _are_we_testing; then
    # Do nothing
    true
  else
    exit "$@"
  fi
}

assert() {
  local lineno msg

  if [ $# -lt 2 ]; then
    log_warn "Not enough parameters for assert()"
    return
  fi

  lineno="$2"
  msg="${3:-}"

  if [ ! $1 ]; then
    log_error "Assertion failed: \"$1\""
    log_error "File \"$0\", line $lineno"
    if [ -n "$msg" ]; then
      log_error "Message: $msg"
    fi

    maybe_exit 1
  fi
}

# OS detection.  Will exit if unknown.
os_type() {
  local uname
  uname=`uname -s | tr '[A-Z]' '[a-z]'`

  case $uname in
    darwin|linux)
      echo "$uname"
      ;;
    *)
      log_crit "Unknown system: $uname"
      ;;
  esac
}

# Is this OS X?
is_osx() {
  [ os_type = "darwin" ] || return 1
}

# Is this Linux?
is_linux() {
  [ os_type = "linux" ] || return 1
}

# Check if a given executable exists in our $PATH.
has_executable() {
  assert "$# -eq 1" $LINENO "Wrong number of arguments for has_executable()"

  command -v "$1" 2>&1 >/dev/null || return 1
}

# Is this a restart?
is_restart() {
  [ "${__DOTFILES_IS_RESTART:-0}" -eq 1 ] || return 1
}

# Truncate a string to a certain number of characters
truncate() {
  assert "$# -eq 2" $LINENO "Wrong number of arguments for truncate()"

  local s len
  s="$1"
  len="$2"

  echo `echo "$s" | head -c $len`
}

# Is a function with the given name declared?
is_function_declared() {
  assert "$# -eq 1" $LINENO "Wrong number of arguments for is_function_declared()"

  if type "$1" | grep -q "shell function"; then
    return 0
  else
    return 1
  fi
}

# Backup a file to the backup directory
backup_file() {
  assert "$# -eq 1" $LINENO "Wrong number of arguments for backup_file()"

  DID_BACKUP=1

  # Create directory if it doesn't exist
  if [ ! -e "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
  fi

  # Move existing file there
  log_info_sub "Backing up file: $1"
  mv "$1" "$BACKUP_DIR/"
}

# Backup the given file if it exists
backup_file_if_exists() {
  assert "$# -eq 1" $LINENO "Wrong number of arguments for backup_file_if_exists()"

  if [ ! -e "$1" ]; then
    return
  fi

  backup_file "$1"
}

# Somewhat hackish, but portable, version of the `readlink` utility.
readlink_portable() {
  assert "$# -eq 1" $LINENO "Wrong number of arguments for readlink_portable()"

  local link_name ls_output

  link_name="$1"
  if [ ! -e "$link_name" ]; then
    return 1
  fi

  # If we have the 'readlink' command, use it
  if has_executable "readlink"; then
    echo "$(readlink -- "$link_name")"
  else
    ls_output="$(ls -dl -- "$link_name")"
    echo "${ls_output#*"${link_name} -> "}"
  fi
}

# Mimic the functionality of `readlink -f` on systems that don't have it.



##################################################
## HELP AND FLAG-PARSING

usage() {
  cat <<HELP
Usage: $SCRIPT_NAME

See the README for documentation.
https://github.com/andrew-d/dotfiles

Copyright (c) 2016 Andrew Dunham
Licensed under the MIT license.
HELP
  maybe_exit
}

parse_flags() {
  local key

  while [ $# -gt 0 ]; do
    key="$1"

    case $key in
      -h|--help)
        usage
        ;;
      -V|--version)
        echo "$VERSION"
        maybe_exit
        ;;
      -v)
        VERBOSITY=`expr $VERBOSITY + 1`
        ;;
      -q)
        VERBOSITY=`expr $VERBOSITY - 1`
        ;;
      -b|--backup)
        BACKUP_DIR="$1"
        shift
        ;;
      *)
        log_warn "Unknown option: $key"
        ;;
    esac

    shift
  done

  # Default value for backup directory
  if [ -z "$BACKUP_DIR" ]; then
    BACKUP_DIR="$DOTFILES/backups/$(date "+%Y_%m_%d-%H_%M_%S")/"
  fi

  log_trace "VERBOSITY   = $VERBOSITY"
  log_trace "CURRENT_DIR = $CURRENT_DIR"
  log_trace "REPO_ROOT   = $REPO_ROOT"
  log_trace "DOTFILES    = $DOTFILES"
  log_trace "BACKUP_DIR  = $BACKUP_DIR"
}

##################################################
## FUNCTIONALITY

check_executables() {
  # Common
  if ! has_executable "git"; then
    log_crit "Git should be installed, but we couldn't find it.  Aborting."
  fi

  if is_osx; then
    _check_executables_osx
  elif is_linux; then
    _check_executables_linux
  fi
}

_check_executables_osx() {
  if ! has_executable "gcc"; then
    log_crit "XCode or the Command Line Tools for XCode must be installed first."
  fi
}

_check_executables_linux() {
  log_debug "No current executable checks on Linux"
}

check_repo_update() {
  local prev_head curr_head

  prev_head=`git rev-parse HEAD`
  git pull
  curr_head=`git rev-parse HEAD`

  if [ ! "$prev_head" = "$curr_head" ]; then
    log_warn "Changes detected, restarting script..."
    log_debug "Updated from $(truncate "$prev_head" 7) --> $(truncate "$curr_head" 7)"
    exec env __DOTFILES_IS_RESTART=1 "$CANONICAL" "$@"
  fi
}

# Runs a single step of our process
run_step() {
  assert "$# -eq 1" $LINENO "Wrong number of arguments for run_step()"

  local files base dest skip

  files="$(find "$DOTFILES"/"$1" -type f -depth 1)"

  # Ignore the '*' file - if this happens, it means there are no files that
  # match this glob.
  if [ "$files" = "$DOTFILES/$1/*" ]; then
    log_debug "No files found"
    return
  else
    log_trace "Files = $files"
  fi

  # Run information function, if it exists.
  if is_function_declared "${1}_before"; then
    "${1}_before"
  fi

  for f in $files; do
    base="$(basename "$f")"
    dest="$HOME"/"$base"

    log_trace "Processing file: $base"

    # Skip files named '.gitkeep'
    if [ "$base" = ".gitkeep" ]; then
      continue
    fi

    # If the test function is declared, run it.
    if is_function_declared "${1}_test"; then
      skip="$("${1}_test" "$f" "$dest")"

      # If the test function returns a string, then print and run it.
      if [ "$skip" ]; then
        log_warn "Skipping $dest: $skip"
        continue
      fi
    fi

    # If necessary, back up the destination file
    backup_file_if_exists "$dest"

    # Perform the operation.
    "${1}_perform" "$f" "$dest"
  done
}

# Copying
copy_before() {
  log_info "Copying files..."
}

copy_test() {
  # Only care if the destination exists
  if [ -e "$2" ]; then
    # Are they the same file?
    if cmp "$1" "$2" 2> /dev/null; then
      echo "same file"
      return
    else
      log_debug "File exists but is different: $2"
    fi

    # Get modification times
    local srcmod destmod
    srcmod="$(stat -f '%Um' "$1")"
    destmod="$(stat -f '%Um' "$2")"

    # Don't overwrite if our destination is newer
    if [ "$srcmod" -lt "$destmod" ]; then
      echo "destination file is newer"
    fi
  fi
}

copy_perform() {
  log_info_sub "Copying $1 --> $2"
  cp -a "$1" "$2"
}

# Linking
link_before() {
  log_info "Linking files..."
}

link_perform() {
  log_debug "Would link $1 to $2"
}

# Initialization
init_before() {
  log_info "Running initialization scripts..."
}

init_perform() {
  log_debug "Would run $1"
}

##################################################
## MAIN FUNCTION

main() {
  parse_flags "$@"
  check_executables

  # Clone / update our dotfiles repository
  if [ ! -d "$DOTFILES" ]; then
    log_info "Dotfiles directory ($DOTFILES) does not exist. Cloning from GitHub..."
    git clone $GITHUB_PATH $DOTFILES

    cd "$DOTFILES"
  elif ! is_restart; then
    log_debug "Checking for an out-of-date repository"

    cd "$DOTFILES"
    check_repo_update "$@"
  fi

  # Perform actual processing
  run_step "copy"
  run_step "link"
  run_step "init"

  log_info "Done!"
}

# Only run our main function if we're not testing
if [ ! "${__DOTFILES_IS_TEST:-false}" = "true" ]; then
  main "$@"
fi
