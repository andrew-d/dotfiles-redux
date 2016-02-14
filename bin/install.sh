#!/bin/sh

set -e
set -u


VERSION=0.0.1

# Default configuration
VERBOSITY=3
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

log() {
  local message level ilevel color sindent

  message="$1"
  level="${2:-debug}"
  indent="${3:-0}"

  # Map the input level string to a number
  case $level in
    trace)
      ilevel=5
      ;;
    debug)
      ilevel=4
      ;;
    info)
      ilevel=3
      ;;
    warn)
      ilevel=2
      ;;
    error)
      ilevel=1
      ;;
    crit)
      ilevel=0
      ;;
  esac

  # Don't log if the verbosity is lower, except for critical messages.
  if [ ! "$ilevel" -eq "0" ]; then
    if [ "$VERBOSITY" -lt "$ilevel" ]; then
      return
    fi
  fi

  # Find the color for this message
  case $ilevel in
    5|4)
      # Blue
      color="\033[1;34m"
      ;;
    3)
      # Green
      color="\033[1;32m"
      ;;
    2)
      # Yellow
      color="\033[1;33m"
      ;;
    1|0)
      # Red
      color="\033[1;31m"
      ;;
    *)
      # Magenta (unknown)
      color="\033[1;35m"
      ;;
  esac

  # Find the prefix arrow for 'indent'
  case $indent in
    0)
      sindent="==>"
      ;;
    1)
      sindent="  ->"
      ;;
    2)
      sindent="   ->"
      ;;
    *)
      # Unknown
      sindent="??>"
      ;;
  esac

  # Log everything
  printf "$color%s\033[0m  %s\n" \
    "$sindent" \
    "$message" >&2

  # Maybe exit on critical messages
  if [ "$ilevel" -eq "0" ]; then
    maybe_exit 1
  fi
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
  local msg

  if [ $# -lt 1 ]; then
    log "Not enough parameters for assert()" "warn"
    return
  fi

  msg="${2:-}"

  if [ ! "$1" ]; then
    log "Assertion failed: \"$1\"" "error"
    if [ -n "$msg" ]; then
      log "Message: $msg" "error"
    fi

    maybe_exit 1
  fi
}

# OS detection.  Will exit if unknown.
os_type() {
  local uname
  uname="$(uname -s | tr '[:upper:]' '[:lower:]')"

  case $uname in
    darwin|linux)
      echo "$uname"
      ;;
    *)
      log "Unknown system: $uname" "crit"
      ;;
  esac
}

# Is this OS X?
is_osx() {
  local type
  type="$(os_type)"
  [ "$type" = "darwin" ] || return 1
}

# Is this Linux?
is_linux() {
  local type
  type="$(os_type)"
  [ "$type" = "linux" ] || return 1
}

# Check if a given executable exists in our $PATH.
has_executable() {
  assert "$# -eq 1" "Wrong number of arguments for has_executable()"

  command -v "$1" >/dev/null 2>&1 || return 1
}

# Is this a restart?
is_restart() {
  [ "${__DOTFILES_IS_RESTART:-0}" -eq 1 ] || return 1
}

# Truncate a string to a certain number of characters
truncate() {
  assert "$# -eq 2" "Wrong number of arguments for truncate()"

  local s len
  s="$1"
  len="$2"

  echo "$s" | head -c "$len"
}

# Is a function with the given name declared?
is_function_declared() {
  assert "$# -eq 1" "Wrong number of arguments for is_function_declared()"

  if type "$1" | grep -qi "function"; then
    return 0
  else
    return 1
  fi
}

# Backup a file to the backup directory
backup_file() {
  assert "$# -eq 1" "Wrong number of arguments for backup_file()"

  DID_BACKUP=1

  # Create directory if it doesn't exist
  if [ ! -e "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
  fi

  # Move existing file there
  log "Backing up file: $1" "info" 1
  mv "$1" "$BACKUP_DIR/"
}

# Backup the given file if it exists
backup_file_if_exists() {
  assert "$# -eq 1" "Wrong number of arguments for backup_file_if_exists()"

  if [ ! -e "$1" ]; then
    return
  fi

  backup_file "$1"
}

# Somewhat hackish, but portable, version of the `readlink` utility.
readlink_portable() {
  assert "$# -eq 1" "Wrong number of arguments for readlink_portable()"

  local link_name have_readlink ls_output

  link_name="$1"
  if [ ! -e "$link_name" ]; then
    return 1
  fi

  # Find out if we have a readlink command.  We also allow turning this check
  # off for testing.
  have_readlink=no
  if [ ! "${__DOTFILES_TEST_NO_READLINK:-false}" = "true" ]; then
    if has_executable "readlink"; then
      have_readlink=yes
    fi
  fi

  # If we have the 'readlink' command, use it
  if [ "$have_readlink" = "yes" ]; then
    readlink -- "$link_name"
  else
    ls_output="$(ls -dl -- "$link_name")"
    echo "${ls_output#*"${link_name} -> "}"
  fi
}

strlen() {
  assert "$# -eq 1" "Wrong number of arguments for strlen()"
  printf "$1" | wc -c
}

##################################################
## REALPATH
##
## Note: this implementation was taken from here:
##   https://github.com/mkropat/sh-realpath/blob/master/realpath.sh
##
## The following code (until the next '#'-marked
## section) is under the following MIT license:
##   https://github.com/mkropat/sh-realpath/blob/master/LICENSE.txt

realpath() {
    canonicalize_path "$(resolve_symlinks "$1")"
}

resolve_symlinks() {
    _resolve_symlinks "$1"
}

_resolve_symlinks() {
    _assert_no_path_cycles "$@" || return

    local dir_context path
    path=$(readlink -- "$1")
    if [ $? -eq 0 ]; then
        dir_context=$(dirname -- "$1")
        _resolve_symlinks "$(_prepend_dir_context_if_necessary "$dir_context" "$path")" "$@"
    else
        printf '%s\n' "$1"
    fi
}

_prepend_dir_context_if_necessary() {
    if [ "$1" = . ]; then
        printf '%s\n' "$2"
    else
        _prepend_path_if_relative "$1" "$2"
    fi
}

_prepend_path_if_relative() {
    case "$2" in
        /* ) printf '%s\n' "$2" ;;
         * ) printf '%s\n' "$1/$2" ;;
    esac
}

_assert_no_path_cycles() {
    local target path

    target=$1
    shift

    for path in "$@"; do
        if [ "$path" = "$target" ]; then
            return 1
        fi
    done
}

canonicalize_path() {
    if [ -d "$1" ]; then
        _canonicalize_dir_path "$1"
    else
        _canonicalize_file_path "$1"
    fi
}

_canonicalize_dir_path() {
    (cd "$1" 2>/dev/null && pwd -P)
}

_canonicalize_file_path() {
    local dir file
    dir=$(dirname -- "$1")
    file=$(basename -- "$1")
    (cd "$dir" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$file")
}

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
        VERBOSITY=$(( VERBOSITY + 1 ))
        ;;
      -q)
        VERBOSITY=$(( VERBOSITY - 1 ))
        ;;
      -b|--backup)
        BACKUP_DIR="$1"
        shift
        ;;
      *)
        log "Unknown option: $key" "warn"
        ;;
    esac

    shift
  done

  # Default value for backup directory
  if [ -z "$BACKUP_DIR" ]; then
    BACKUP_DIR="$DOTFILES/backups/$(date "+%Y_%m_%d-%H_%M_%S")/"
  fi

  log "VERBOSITY   = $VERBOSITY" "trace"
  log "CURRENT_DIR = $CURRENT_DIR" "trace"
  log "REPO_ROOT   = $REPO_ROOT" "trace"
  log "DOTFILES    = $DOTFILES" "trace"
  log "BACKUP_DIR  = $BACKUP_DIR" "trace"
}

##################################################
## FUNCTIONALITY

check_executables() {
  # Common
  if ! has_executable "git"; then
    log "Git should be installed, but we couldn't find it.  Aborting." "crit"
  fi

  if is_osx; then
    _check_executables_osx
  elif is_linux; then
    _check_executables_linux
  fi
}

_check_executables_osx() {
  if ! has_executable "gcc"; then
    log "XCode or the Command Line Tools for XCode must be installed first." "crit"
  fi
}

_check_executables_linux() {
  log "No current executable checks on Linux" "debug"
}

check_repo_update() {
  local prev_head curr_head

  prev_head="$(git rev-parse HEAD)"
  git pull
  curr_head="$(git rev-parse HEAD)"

  if [ ! "$prev_head" = "$curr_head" ]; then
    log "Changes detected, restarting script..." "warn"
    log "Updated from $(truncate "$prev_head" 7) --> $(truncate "$curr_head" 7)"
    exec env __DOTFILES_IS_RESTART=1 "$CANONICAL" "$@"
  fi
}

# Runs a single step of our process
run_step() {
  assert "$# -eq 1" "Wrong number of arguments for run_step()"

  local files base dest skip

  files="$(find "$DOTFILES"/"$1" -maxdepth 1 -type f)"

  # Ignore the '*' file - if this happens, it means there are no files that
  # match this glob.
  if [ "$files" = "$DOTFILES/$1/*" ]; then
    log "No files found"
    return
  else
    log "Files = $files" "trace"
  fi

  # Run information function, if it exists.
  if is_function_declared "${1}_before"; then
    "${1}_before"
  fi

  for src in $files; do
    base="$(basename "$src")"
    dest="$HOME"/"$base"

    log "Processing file: $base" "trace"

    # Skip files named '.gitkeep'
    if [ "$base" = ".gitkeep" ]; then
      continue
    fi

    # If the test function is declared, run it.
    if is_function_declared "${1}_test"; then
      skip="$("${1}_test" "$src" "$dest")"

      # If the test function returns a string, then print it and skip.
      if [ "$skip" ]; then
        log "Skipping $dest: $skip" "info" 1
        continue
      fi
    fi

    # If necessary, back up the destination file
    backup_file_if_exists "$dest"

    # Perform the operation.
    "${1}_perform" "$src" "$dest"
  done
}

# Copying
copy_before() {
  log "Copying files..." "info"
}

copy_test() {
  # Only care if the destination exists
  if [ -e "$2" ]; then
    # Are they the same file?
    if cmp "$1" "$2" 2> /dev/null; then
      echo "same file"
      return
    else
      log "File exists but is different: $2" "debug" 2
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
  log "Copying $1 --> $2" "info" 1
  cp -a "$1" "$2"
}

# Linking
link_before() {
  log "Linking files..." "info"
}

link_test() {
  # Note: we get passed (src, dest), where 'src' is the file in our repo.

  local expected_target actual_target
  expected_target="$(realpath "$1")"

  # If the destination is a link...
  if [ -L "$2" ]; then
    actual_target="$(realpath "$2")"

    # Only skip if it points to the right destination.
    if [ "$expected_target" = "$actual_target" ]; then
      echo 'link already exists'
    else
      log "Link '$2' exists, but points to: $actual_target" "warn" 1
      log "Should point to: $expected_target" "debug" 1
    fi
  fi
}

link_perform() {
  log "Linking $1 --> $2" "info" 1

  # TODO(andrew-d): Make relative to $HOME?
  ln -sf "$1" "$2"
}

# Initialization
init_before() {
  log "Running initialization scripts..." "info"
}

init_perform() {
  log "Would run $1"
}

##################################################
## MAIN FUNCTION

main() {
  parse_flags "$@"
  check_executables

  # Clone / update our dotfiles repository
  if [ ! -d "$DOTFILES" ]; then
    log "Dotfiles directory ($DOTFILES) does not exist. Cloning from GitHub..." "info"
    git clone "$GITHUB_PATH" "$DOTFILES"

    cd "$DOTFILES"
  elif ! is_restart; then
    log "Checking for an out-of-date repository"

    cd "$DOTFILES"
    check_repo_update "$@"
  fi

  # Perform actual processing
  run_step "copy"
  run_step "link"
  run_step "init"

  if [ "$DID_BACKUP" -eq 1 ]; then
    log "Backups are stored in: $BACKUP_DIR" "info"
  fi

  log "Done!" "info"
}

# Only run our main function if we're not testing
if [ ! "${__DOTFILES_IS_TEST:-false}" = "true" ]; then
  main "$@"
fi
