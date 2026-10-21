#!/usr/bin/env python3
"""Query the actual Collector; compare host timestamps and persistence across restart."""
import argparse
import json
import math
import socket
import time
import urllib.parse
import urllib.request
from pathlib import Path


def samples(payload, hostname, start_ms, end_ms):
    result = {}
    for metric in payload.get('metrics', []):
        name = metric.get('metricname')
        if name not in ('cpu_user', 'mem_total') or metric.get('hostname') != hostname or metric.get('appid') != 'HOST':
            continue
        for timestamp, value in metric.get('metrics', {}).items():
            if isinstance(value, bool) or not isinstance(value, (float, int)) or not math.isfinite(value):
                continue
            if not str(timestamp).isdigit() or not start_ms <= int(timestamp) <= end_ms:
                continue
            if (name == 'cpu_user' and not 0 <= value <= 100) or (name == 'mem_total' and value <= 0):
                continue
            points = result.setdefault(name, {})
            if str(timestamp) in points and points[str(timestamp)] != value:
                raise AssertionError('Conflicting Collector values for the same host timestamp')
            points[str(timestamp)] = value
    return result


def assert_persisted(before, after):
    assert set(before) == {'cpu_user', 'mem_total'} and all(before.values())
    for name, points in before.items():
        for timestamp, value in points.items():
            assert after.get(name, {}).get(timestamp) == value, (name, timestamp, 'historical value lost or changed')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--start-ms', type=int, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--before', type=Path)
    parser.add_argument('--fresh-after-ms', type=int)
    args = parser.parse_args()
    hostname = socket.gethostname()
    before = json.loads(args.before.read_text())['accepted_samples'] if args.before else None
    deadline = time.monotonic() + 240
    last_error = None
    while time.monotonic() < deadline:
        now = int(time.time() * 1000)
        query = urllib.parse.urlencode({'metricNames': 'cpu_user,mem_total', 'appId': 'HOST',
            'hostname': hostname, 'startTime': args.start_ms, 'endTime': now,
            'precision': 'seconds', 'grouped': 'false'})
        try:
            with urllib.request.urlopen('http://127.0.0.1:6188/ws/v1/timeline/metrics?' + query, timeout=5) as response:
                payload = json.load(response)
            accepted = samples(payload, hostname, args.start_ms, now + 5000)
            assert set(accepted) == {'cpu_user', 'mem_total'}
            if before:
                assert_persisted(before, accepted)
            if args.fresh_after_ms:
                assert set(samples(payload, hostname, args.fresh_after_ms, now + 5000)) == {'cpu_user', 'mem_total'}
            args.output.write_text(json.dumps({'hostname': hostname, 'accepted_samples': accepted,
                'query': payload, 'queried_at_ms': now}, indent=2) + '\n')
            print('PASS: actual Collector returned timestamped host metrics' + (' and preserved historical values' if before else ''))
            return
        except (OSError, ValueError, AssertionError) as error:
            last_error = repr(error)
        time.sleep(3)
    raise RuntimeError('Collector query deadline: ' + str(last_error))


if __name__ == '__main__':
    main()
