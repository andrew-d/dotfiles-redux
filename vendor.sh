#!/bin/sh

set -u


DRY_RUN=0
VENDORFILE=vendor.ini
CACHE_DIR=.vendor-cache


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

clone_and_copy() {
  local repo_url dest rev cache_dir

  repo_url="$1"
  dest="$2"
  rev="${3:-}"

  # Figure out where we would store this in our cache directory.
  last_component="$(echo "$repo_url" | sed -E 's|^.*\/([^/]+)\.git$|\1|')"
  repo_hash="$(echo "$repo_url" | shasum | cut -d' ' -f1)"
  cache_dir="$CACHE_DIR/${last_component}-${repo_hash}"

  # Do the rest of the work in a subshell to avoid polluting our environment
  (
    # If the cache directory exists, then we don't need to clone it.  We just 'git pull' instead.
    if [ -d "$cache_dir" ]; then
      cd "$cache_dir"
      msg3 "Cache directory exists - running 'git pull'"
      maybe_run git -C "$cache_dir" pull || exit 1
    else
      msg3 "Cloning repo"
      maybe_run git clone "$repo_url" "$cache_dir" || exit 1
    fi

    # If we have a revision, check it out
    if [ ! -z "$rev" ]; then
      msg3 "Resetting to the given revision"
      maybe_run git -C "$cache_dir" reset --hard "$rev" || ( err "Could not check out revision: $rev" ; exit 1 )
    fi

    # Copy all contents of the repo to the destination directory, except the '.git' directory
    msg3 "Copying to destination: $dest/"
    maybe_run rsync -av "$cache_dir/" "$dest/" --exclude=.git || exit 1
  )
  ret=$?

  return $?
}

usage() {
  cat <<EOF >&2
Usage: $(basename "$0") [options]

Options:
  -h or --help      Show this help
  -n                Dry-run mode (makes no changes)
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
      *)
        die "Unknown option: $key"
        ;;
    esac

    # Shift past this argument
    shift
  done
}


main() {
  parse_options "$@"

  if ! command -v "git" >/dev/null 2>&1; then
    die "Git should be installed, but we couldn't find it.  Aborting."
  fi

  if [ ! -s "$VENDORFILE" ]; then
    die "Could not find vendor file: $VENDORFILE"
  fi

  msg "Updating vendored repos in $(pwd)..."

  local line path repo ref
  while read -r line; do
    # Skip blank
    if echo "$line" | grep -q '^$' ; then
      continue
    fi

    # Skip commented
    if echo "$line" | grep -q '^\s*#' ; then
      continue
    fi

    # Collapse tab characters
    line="$(echo "$line" | tr -s '\t')"

    # Split into components
    path="$(echo "$line" | cut -d'	' -f1)"
    repo="$(echo "$line" | cut -d'	' -f2)"
    ref="$(echo "$line" | cut -d'	' -f3)"

    # Prefix $path with the current path
    path="$(pwd -P)/$path"

    # Repo must end with '.git' (currently)
    if ! echo "$repo" | grep -q '\.git$' ; then
      err "Repo does not end with '.git': $repo"
      continue
    fi

    msg "Processing: $repo"

    # Remove the destination path, if necessary.
    if [ -e "$path" ]; then
      msg2 "Removing existing path..."
      maybe_run rm -rf -- "$path" || die "Could not remove path: $path"
    fi

    # Re-make the destination directory
    maybe_run mkdir -p "$path" || die "Could not create path: $path"

    # Clone and copy
    msg2 "Copying from remote..."
    clone_and_copy "$repo" "$path" "$ref" || die "Error while clone/copying"
  done < "$VENDORFILE"

  msg "Done!"
}

main "$@"
