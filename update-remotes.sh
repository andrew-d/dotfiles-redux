#!/bin/sh

set -e
set -u


DRY_RUN=0
PULL=0
UPDATE=0

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

err() {
  printf "\033[1;31m==>\033[0m %s\n" "$@" >&2
}

die() {
  err "$@"
  exit 1
}

##################################################
## UTILITY

maybe_run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "+ $@" >&2
  else
    "$@"
  fi
}

require_clean_work_tree() {
  local err

  # Update the index
  git update-index -q --ignore-submodules --refresh
  err=0

  # Disallow unstaged changes in the working tree
  if ! git diff-files --quiet --ignore-submodules -- ; then
	err "Repository has unstaged changes"
	git diff-files --name-status -r --ignore-submodules -- >&2
	err=1
  fi

  # Disallow uncommitted changes in the index
  if ! git diff-index --cached --quiet HEAD --ignore-submodules -- ; then
	err "Repository has uncommitted changes"
	git diff-index --cached --name-status -r --ignore-submodules HEAD -- >&2
	err=1
  fi

  if [ $err = 1 ]; then
	err "Please commit or stash them."
	exit 1
  fi
}

##################################################
## MAIN FUNCTION


usage() {
  cat <<EOF >&2
Usage: $(basename "$0") [options]

Options:
  -h or --help      Show this help
  -n                Dry-run mode (makes no changes)
  -p or --pull      Run 'git pull' on the remote's branch
  -u or --update    Update the data in the current repository from the branch
EOF
}


parse_options() {
  while [ $# -gt 0 ]; do
    key="$1"

    case $key in
      -h|--help)
        usage
        exit 0
        ;;
      -n)
        DRY_RUN=1
        ;;
      -p|--pull)
        PULL=1
        ;;
      -u|--update)
        UPDATE=1
        ;;
      *)
        die "Unknown option: $key"
        ;;
    esac

    # Shift past this argument
    shift
  done
}

main() {
  if ! command -v "git" >/dev/null 2>&1; then
    die "Git should be installed, but we couldn't find it.  Aborting."
  fi

  parse_options "$@"

  msg "Updating git remotes in $(pwd)..."

  if ! git status >/dev/null 2>&1; then
    die "This isn't a Git repository!"
  fi

  require_clean_work_tree

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
    srcpath="$(echo "$line" | cut -d'|' -f4)"

    # Path must end with '/'
    if ! echo "$path" | grep -q '/$'; then
      path="$path/"
    fi

    # Computed
    remotename="vendor_${name}"
    branchname="vendor_${name}_branch"

    msg2 "Checking $name"

    # Add remote
    if git remote | grep -q "^$remotename\$" ; then
      msg3 "Remote already exists: $remotename"
    else
      msg3 "Adding remote: $remotename $giturl"
      maybe_run git remote add "$remotename" "$giturl" || die 'Could not add remote'
    fi

    # Fetch upstream
    maybe_run git fetch "$remotename" || die "Could not fetch remote: $remotename"

    # Create branch
    if git branch --list | grep -q "$branchname" ; then
      msg3 "Branch already exists: $branchname"
    else
      msg3 "Adding branch: $branchname"
      maybe_run git branch --track "$branchname" "$remotename/master" || die 'Could not add branch'
    fi

    # Maybe run pull
    if [ $PULL = 1 ]; then
      local current_ref
      current_ref="$(git symbolic-ref -q --short HEAD)"
      [ ! $? ] && die 'Could not get current ref'

      msg3 "Running 'git pull' on branch: $branchname"
      maybe_run git checkout "$branchname"
      maybe_run git pull
      maybe_run git checkout "$current_ref"
    fi

    # Maybe run update
    if [ $UPDATE = 1 ]; then
      local vendor_refspec

      vendor_refspec="$branchname"
      if [ ! -z "$srcpath" ]; then
        vendor_refspec="$vendor_refspec:$srcpath"
      fi

      msg3 "Using refspec '$vendor_refspec' to update: $path"
      maybe_run git read-tree "--prefix=$path" -u "$vendor_refspec" || die 'Could not update tree'
    fi
  done < "remotes.ini"

  msg 'Done!'
}

main "$@"
