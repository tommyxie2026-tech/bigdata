#!/usr/bin/env python3
"""Wait for the real Collector query API before starting its Monitor."""
import json
import socket
import time
import urllib.parse
import urllib.request


def wait_ready(timeout_seconds=180):
    deadline=time.monotonic()+timeout_seconds
    last=None
    while time.monotonic()<deadline:
        now=int(time.time()*1000)
        query=urllib.parse.urlencode({'metricNames':'cpu_user','appId':'HOST',
            'hostname':socket.gethostname(),'startTime':max(0,now-60000),'endTime':now,
            'precision':'seconds','grouped':'false'})
        try:
            with urllib.request.urlopen('http://127.0.0.1:6188/ws/v1/timeline/metrics?'+query,timeout=5) as response:
                payload=json.load(response)
            if isinstance(payload,dict) and isinstance(payload.get('metrics'),list):
                print('Collector query API ready',flush=True)
                return
            last='Invalid Collector response'
        except (OSError,ValueError) as error:last=repr(error)
        time.sleep(2)
    raise RuntimeError('Collector startup readiness deadline: '+str(last))


if __name__=='__main__':wait_ready()
