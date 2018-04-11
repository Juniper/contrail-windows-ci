#!/usr/bin/env python3

import os
import subprocess

def get_linter_targets():
    roles_dir = './ansible/roles'
    roles = [os.path.join(roles_dir, o) for o in os.listdir(roles_dir)
                if os.path.isdir(os.path.join(roles_dir, o))]

    yamls_dir = './ansible'
    yamls = [os.path.join(yamls_dir, o) for o in os.listdir(yamls_dir)
                if o.endswith('.yml')]

    return roles + yamls

def lint(targets):
    success = True

    for target in targets:
        print('Running ansible-lint on {}...'.format(target), flush=True)
        if subprocess.call(['ansible-lint', target]) != 0:
            success = False

    return success

def main():
    targets = get_linter_targets()
    return 0 if lint(targets) else 1

if __name__ == '__main__':
    exit(main())
