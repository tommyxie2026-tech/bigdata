#!/usr/bin/env python3
"""Run RPM-provided service commands as ams; prove Collector persistence and recovery."""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', type=Path, required=True)
    args = parser.parse_args()
    evidence = args.evidence
    evidence.mkdir(parents=True, exist_ok=True)
    processes = []
    logs = []
    identities = []

    def stop_all():
        failures = []
        for name, process in reversed(processes):
            if process.poll() is not None:
                failures.append(name + ' exited unexpectedly: ' + str(process.returncode))
                continue
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=60)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=10)
                failures.append(name + ' failed graceful stop')
        processes.clear()
        for stream in logs:
            stream.close()
        logs.clear()
        if failures:
            raise RuntimeError('; '.join(failures))

    started_ms = int(time.time() * 1000)
    try:
        for phase in ('initial', 'restarted'):
            fresh_after_ms = int(time.time() * 1000)
            for name, command in [
                ('hbase', ['/usr/libexec/ambari-metrics/runtime', 'hbase']),
                ('collector', ['/usr/libexec/ambari-metrics/runtime', 'collector']),
                ('monitor', ['/usr/bin/python3', '/usr/lib/ambari-metrics-monitor/main.py'])]:
                stream = (evidence/(phase + '-' + name + '.log')).open('w')
                logs.append(stream)
                process = subprocess.Popen(['runuser', '-u', 'ams', '--', *command],
                    stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
                processes.append((name, process))
            identities.append({name: p.pid for name, p in processes})
            command = [sys.executable, str(Path(__file__).with_name('verify_collector.py')),
                '--start-ms', str(started_ms), '--output', str(evidence/(phase + '-query.json')),
                '--fresh-after-ms', str(fresh_after_ms)]
            if phase == 'restarted':
                command += ['--before', str(evidence/'initial-query.json')]
            subprocess.run(command, check=True, timeout=270)
            assert all(p.poll() is None for _, p in processes), 'A real service exited during query'
            stop_all()
        assert all(identities[0][name] != identities[1][name] for name in identities[0])
        result = {'component': 'ambari-metrics', 'version': '3.0.0',
            'source_identity': 'ce919386e963841ea37f032c5ba6ed9c48298dd8',
            'clean_openEuler_rpm_install': 'PASS', 'actual_host_collection': 'PASS',
            'collector_timestamp_query': 'PASS', 'restart_historical_values': 'PASS',
            'fresh_metrics_after_restart': 'PASS', 'service_processes': identities}
        (evidence/'acceptance.json').write_text(json.dumps(result, indent=2) + '\n')
    finally:
        if processes:
            stop_all()


if __name__ == '__main__':
    main()
