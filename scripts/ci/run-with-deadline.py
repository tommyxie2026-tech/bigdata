#!/usr/bin/env python3
"""Run a process tree with a deadline; return 124 on timeout, including cleanup."""
import argparse
import os
import signal
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('seconds', type=int)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.seconds <= 0 or not args.command:
        parser.error('a positive deadline and a command are required')
    child = subprocess.Popen(args.command, start_new_session=True)

    def stop_group():
        try:
            os.killpg(child.pid, signal.SIGTERM)
        except ProcessLookupError:
            return
        try:
            child.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass
        # A child may exit before its own descendants. Always clean the group.
        try:
            os.killpg(child.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        child.wait()

    def interrupted(signum, _frame):
        stop_group()
        raise SystemExit(128 + signum)

    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        return child.wait(timeout=args.seconds)
    except subprocess.TimeoutExpired:
        print('Command timeout after {} seconds; terminating process tree'.format(args.seconds),
              file=sys.stderr, flush=True)
        stop_group()
        return 124


if __name__ == '__main__':
    sys.exit(main())
