#!/usr/bin/env python3
"""Run the actual converted Monitor against a capture fixture, then restart it.

This proves host collection/emission only, not the real Collector or its persistence.
"""
import argparse
import configparser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import queue
import subprocess
import sys
import threading
import time
from verify_monitor_payload import host_samples


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--monitor-root',type=Path,required=True)
    parser.add_argument('--config-source',type=Path,required=True)
    parser.add_argument('--evidence-root',type=Path,required=True)
    args=parser.parse_args()
    evidence=args.evidence_root;evidence.mkdir(parents=True,exist_ok=True)
    received=queue.Queue()
    class Receiver(BaseHTTPRequestHandler):
        protocol_version="HTTP/1.1"
        def log_message(self,*values):pass
        def do_POST(self):
            size=int(self.headers.get('Content-Length','0'))
            if self.path!='/ws/v1/timeline/metrics/' or not 0 < size <= 1048576:
                self.send_error(400);return
            try:
                data=json.loads(self.rfile.read(size))
            except (ValueError,UnicodeError):
                self.send_error(400);return
            received.put(data)
            self.send_response(200);self.send_header('Content-Length','2');self.end_headers();self.wfile.write(b'{}')
    server=ThreadingHTTPServer(('127.0.0.1',0),Receiver)
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
    conf=Path('/etc/ambari-metrics-monitor/conf');conf.mkdir(parents=True,exist_ok=True)
    (conf/'metric_groups.conf').write_bytes((args.config_source/'metric_groups.conf').read_bytes())
    config=configparser.RawConfigParser();config.read(args.config_source/'metric_monitor.ini')
    for section,key,value in [('default','metrics_servers','127.0.0.1'),('emitter','send_interval','12'),
        ('emitter','kinit_cmd',''),('emitter','klist_cmd',''),('collector','collector_sleep_interval','1'),
        ('collector','port',str(server.server_port))]:
        config.set(section,key,value)
    with (conf/'metric_monitor.ini').open('w') as stream:config.write(stream)
    for directory in ['/var/log/ambari-metrics-monitor','/var/run/ambari-metrics-monitor']:
        Path(directory).mkdir(parents=True,exist_ok=True)
    process=None
    pids=[]
    try:
        for phase in ('initial','restarted'):
            while not received.empty():received.get_nowait()
            started_ms=int(time.time()*1000)
            with (evidence/(phase+'-monitor.log')).open('w') as log:
                process=subprocess.Popen([sys.executable,str(args.monitor_root/'main.py')],stdout=log,stderr=subprocess.STDOUT)
                pids.append(process.pid)
                found=set();payloads=[];valid_payloads=0;deadline=time.monotonic()+150
                while time.monotonic()<deadline:
                    if process.poll() is not None:
                        raise RuntimeError('Real Monitor exited during '+phase+'; see its log')
                    try:data=received.get(timeout=1)
                    except queue.Empty:continue
                    payloads.append(data)
                    samples=host_samples(data,int(time.time()*1000),started_ms)
                    found.update(samples)
                    if samples=={'cpu_user','mem_total'}:valid_payloads+=1
                    if valid_payloads>=2:break
                (evidence/(phase+'-payloads.json')).write_text(json.dumps(payloads,indent=2)+'\n')
                if found!={'cpu_user','mem_total'} or valid_payloads<2:
                    raise AssertionError('Missing repeated fresh CPU/memory samples: '+str(found))
                pidfile=Path('/var/run/ambari-metrics-monitor/ambari-metrics-monitor.pid')
                assert pidfile.is_file() and int(pidfile.read_text().strip())==process.pid
                process.terminate()
                try:process.wait(timeout=15)
                except subprocess.TimeoutExpired:process.kill();process.wait(timeout=5);raise RuntimeError('Monitor did not stop gracefully')
                if process.returncode!=0:raise RuntimeError('Monitor stop failed: '+str(process.returncode))
                assert not pidfile.exists()
                process=None
        assert pids[0]!=pids[1]
        (evidence/'monitor-evidence.json').write_text(json.dumps({'profile':'monitor-real-host-capture-fixture',
            'source_identity':'ce919386e963841ea37f032c5ba6ed9c48298dd8','python':sys.version,
            'fresh_cpu_memory_before_restart':'PASS','fresh_cpu_memory_after_restart':'PASS',
            'collector_query':'NOT_RUN','collector_restart_persistence':'NOT_RUN'},indent=2)+'\n')
        print('PASS: real Monitor emitted fresh host CPU/memory before and after restart')
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            try:process.wait(timeout=10)
            except subprocess.TimeoutExpired:process.kill();process.wait(timeout=5)
        server.shutdown();server.server_close();thread.join(timeout=5)


if __name__=='__main__':main()
