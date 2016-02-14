#!/bin/sh

set -e
set -u


##################################################
## LOGGING

msg() {
  printf "\033[1;32m==>\033[0m %s\n" "$@" >&2
}

msg2() {
  printf "\033[1;32m ->\033[0m %s\n" "$@" >&2
}

msg3() {
  printf "\033[1;34m  ->\033[0m %s\n" "$@" >&2
}

die() {
  printf "\033[1;31m==>\033[0m %s\n" "$@" >&2
  exit 1
}

##################################################
## MAIN FUNCTION

main() {
  if ! command -v "git" >/dev/null 2>&1; then
    die "Git should be installed, but we couldn't find it.  Aborting."
  fi

  msg "Updating git remotes in $(pwd)..."

  if ! git status >/dev/null 2>&1; then
    die "This isn't a Git repository!"
  fi

  local line name giturl path
  local branchname

  while read -r line; do
    # Skip blank
    if echo "$line" | grep -q '^$' ; then
      continue
    fi

    # Skip commented
    if echo "$line" | grep -q '^\s*#' ; then
      continue
    fi

    # Great!  Split into components
    name="$(echo "$line" | cut -d'|' -f1)"
    giturl="$(echo "$line" | cut -d'|' -f2)"
    path="$(echo "$line" | cut -d'|' -f3)"

    # Computed
    remotename="vendor_${name}"
    branchname="vendor_${name}_branch"

    msg2 "Checking $name"

    # Add remote
    if git remote | grep -q "^$remotename\$" ; then
      msg3 "Remote already exists: $remotename"
    else
      msg3 "Adding remote: $remotename $giturl"
      git remote add "$remotename" "$giturl" || die 'Could not add remote'
    fi

    # Fetch upstream
    git fetch "$remotename" || die "Could not fetch remote: $remotename"

    # Create branch
    if git branch --list | grep -q "$branchname" ; then
      msg3 "Branch already exists: $branchname"
    else
      msg3 "Adding branch: $branchname"
      git branch --track "$branchname" "$remotename/master" || die 'Could not add branch'
    fi
  done < "remotes.ini"

  msg 'Done!'
}

main "$@"
