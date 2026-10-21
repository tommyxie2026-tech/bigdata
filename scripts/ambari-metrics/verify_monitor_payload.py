"""Validate actual timestamped host samples emitted by the upstream Monitor."""
import math


def host_samples(payload, now_ms, started_ms):
    found = set()
    if not isinstance(payload, dict) or not isinstance(payload.get('metrics'), list):
        return found
    for metric in payload['metrics']:
        if not isinstance(metric, dict):
            continue
        name = metric.get('metricname')
        if name not in ('cpu_user', 'mem_total') or not metric.get('hostname'):
            continue
        points = metric.get('metrics')
        if not isinstance(points, dict):
            continue
        for timestamp, value in points.items():
            try:
                timestamp = int(timestamp)
            except (TypeError, ValueError, OverflowError):
                continue
            if timestamp < started_ms - 5000 or timestamp > now_ms + 5000:
                continue
            if type(value) not in (int, float) or not math.isfinite(value):
                continue
            if name == 'cpu_user' and 0 <= value <= 100:
                found.add(name)
            if name == 'mem_total' and value > 0:
                found.add(name)
    return found
