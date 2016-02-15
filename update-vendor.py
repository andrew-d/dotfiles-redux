#!/usr/bin/env python

from __future__ import print_function

import os
import sys
import time
import yaml
import subprocess
from optparse import OptionParser


DRY_RUN = False
FNULL = open(os.devnull, 'w')


##################################################
## LOGGING

def msg(s):
    print("\033[1;32m==>\033[0m %s" % (s,), file=sys.stderr)


def msg2(s):
    print("\033[1;32m ->\033[0m %s" % (s,), file=sys.stderr)


def msg3(s):
    print("\033[1;34m  ->\033[0m %s" % (s,), file=sys.stderr)


def err(s):
    print("\033[1;31m==>\033[0m %s" % (s,), file=sys.stderr)


def die(s):
    err(s)
    sys.exit(1)


##################################################
## PROCESS MANAGEMENT

def maybe_run(cmdline, **kwargs):
    if DRY_RUN:
        print('+ %s' % (' '.join(cmdline),), file=sys.stderr)
        return

    proc = subprocess.Popen(cmdline, **kwargs)
    return proc


def maybe_call(cmdline, **kwargs):
    if DRY_RUN:
        print('+ %s' % (' '.join(cmdline),), file=sys.stderr)
        return

    return subprocess.call(cmdline, **kwargs)


def maybe_check_call(cmdline, **kwargs):
    if DRY_RUN:
        print('+ %s' % (' '.join(cmdline),), file=sys.stderr)
        return

    return subprocess.check_call(cmdline, **kwargs)


def which(program):
    def is_exe(fpath):
        return os.path.isfile(fpath) and os.access(fpath, os.X_OK)

    fpath, fname = os.path.split(program)
    if fpath:
        if is_exe(program):
            return program

    else:
        for path in os.environ["PATH"].split(os.pathsep):
            path = path.strip('"')
            exe_file = os.path.join(path, program)

            if is_exe(exe_file):
                return exe_file

    return None


##################################################
## FUNCTIONALITY

def require_clean_work_tree():
    """
    Returns whether the working tree is clean
    """

    # Update index
    subprocess.check_call([
        'git',
        'update-index',
        '-q',
        '--ignore-submodules',
        '--refresh',
    ])

    # Disallow unstaged changes in the working tree
    ret = subprocess.call(['git', 'diff-files', '--quiet', '--ignore-submodules', '--'])
    if ret != 0:
        err("Repository has unstaged changes")
        subprocess.call([
            'git',
            'diff-files',
            '--name-status',
            '-r',
            '--ignore-submodules',
            '--',
        ], stdout=sys.stderr)
        sys.exit(1)


    # Disallow uncommitted changes in the index
    ret = subprocess.call(['git', 'diff-index', '--cached', '--quiet', 'HEAD', '--ignore-submodules', '--'])
    if ret != 0:
        err("Repository has uncommitted changes")
        subprocess.call([
            'git',
            'diff-index',
            '--cached',
            '--name-status',
            '-r',
            '--ignore-submodules',
            'HEAD',
            '--',
        ], stdout=sys.stderr)
        sys.exit(1)


def main():
    parser = OptionParser()
    parser.add_option('-n', '--dry-run', dest="dry_run", action="store_true",
                      help="Dry run mode (makes no changes)")
    parser.add_option('-p', '--pull', dest="pull", action="store_true",
                      help="Run 'git pull' on the remote's branch")
    parser.add_option('-u', '--update', dest="update", action="store_true",
                      help="Update the data in the current repository from the branch")

    (options, args) = parser.parse_args()

    # Set global dryrun flag
    global DRY_RUN
    DRY_RUN = options.dry_run

    if which('git') is None:
        die("Git should be installed, but we couldn't find it.  Aborting.")

    msg("Updating git remotes in %s..." % (os.path.abspath(os.curdir),))

    if subprocess.call(['git', 'status'], stderr=FNULL, stdout=FNULL) != 0:
        die("This isn't a Git repository!")

    require_clean_work_tree()

    # Load config from our file
    with open('remotes.yaml', 'rb') as f:
        config = yaml.load(f)

    remotes = subprocess.check_output(['git', 'remote']).split('\n')
    remotes = [x.strip() for x in remotes]

    branches = subprocess.check_output(['git', 'branch', '--list']).split('\n')
    branches = [x.strip(' *') for x in branches]

    for remote in config:
        name    = remote['name']
        git_url = remote['git_url']
        path    = remote['path']

        remote_name = "vendor_" + name
        branch_name = "vendor_" + name + "_branch"

        msg2("Checking " + name)

        # Add the remote to Git
        if remote_name in remotes:
            msg3("Remote already exists: " + remote_name)
        else:
            msg3("Adding remote: %s %s" % (remote_name, git_url))
            maybe_check_call([
                'git',
                'remote',
                'add',
                remote_name,
                git_url,
            ])

        # Fetch from upstream
        maybe_check_call([
            'git',
            'fetch',
            remote_name,
        ])

        # Create the Git branch
        if branch_name in branches:
            msg3("Branch already exists: " + branch_name)
        else:
            msg3("Adding branch: " + branch_name)
            maybe_check_call([
                'git',
                'branch',
                '--track',
                branch_name,
                remote_name + "/master",
            ])

        # Maybe run git pull
        if options.pull:
            current_ref = subprocess.check_output(['git', 'symbolic-ref', '-q', '--short', 'HEAD']).strip()

            msg3("Running 'git pull' on branch: " + branch_name)

            maybe_check_call(['git', 'checkout', branch_name])
            maybe_check_call(['git', 'pull'])
            maybe_check_call(['git', 'checkout', current_ref])

    # We need to update the local tree as a final step, since we can't checkout
    # another branch (e.g. above) after we've modified the current one.
    if options.update:
        for remote in config:
            path = remote['path']

            # The refspec is the same as branch_name...
            vendor_refspec = "vendor_" + remote['name'] + "_branch"

            # ... except that we may have a subpath
            srcpath = remote.get('srcpath')
            if srcpath is not None:
                vendor_refspec += ":" + srcpath

            msg3("Using refspec '%s' to update: %s" % (vendor_refspec, path))
            maybe_check_call([
                'git',
                'read-tree',
                '--prefix=' + path,
                '-u',
                vendor_refspec,
            ])

    msg("Done!")
    time.sleep(0.4)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
