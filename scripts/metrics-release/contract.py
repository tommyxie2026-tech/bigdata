"""Pure evidence checks for a real Metrics release; these do not replace CI job provenance."""
import hashlib
import math
from pathlib import Path
import re

SOURCE='ce919386e963841ea37f032c5ba6ed9c48298dd8'
GATES=('clean_openEuler_rpm_install','actual_host_collection','collector_timestamp_query',
       'restart_historical_values','fresh_metrics_after_restart')


def require(condition,message):
    if not condition:raise ValueError(message)


def validate_acceptance(value):
    require(value.get('component')=='ambari-metrics' and value.get('version')=='3.0.0','Wrong component/version')
    require(value.get('source_identity')==SOURCE,'Wrong source identity')
    require(all(value.get(key)=='PASS' for key in GATES),'Actual acceptance incomplete')
    phases=value.get('service_processes',[])
    require(isinstance(phases,list) and len(phases)==2,'Need initial and restarted services')
    for phase in phases:
        require(isinstance(phase,dict) and set(phase)=={'hbase','collector','monitor'},'Missing real service')
        require(all(type(pid) is int and pid>0 for pid in phase.values()),'Invalid service PID')
        require(len(set(phase.values()))==3,'Duplicate simultaneous PID')
    require(all(phases[0][name]!=phases[1][name] for name in phases[0]),'Service was not restarted')


def points(value,at):
    require(isinstance(value,dict) and set(value)=={'cpu_user','mem_total'},'Need CPU and memory')
    for name,values in value.items():
        require(isinstance(values,dict) and values,'Missing timestamped metric')
        for timestamp,number in values.items():
            require(isinstance(timestamp,str) and timestamp.isdigit() and 0<int(timestamp)<=at+5000,'Invalid timestamp')
            require(type(number) in (float,int) and math.isfinite(number),'Invalid metric value')
            require(0<=number<=100 if name=='cpu_user' else number>0,'Metric out of bounds')


def observed(snapshot):
    host=snapshot.get('hostname');at=snapshot.get('queried_at_ms')
    require(isinstance(host,str) and host and type(at) is int and at>0,'Invalid actual query identity')
    accepted=snapshot.get('accepted_samples');points(accepted,at)
    minimum=min(int(t) for values in accepted.values() for t in values)
    actual={}
    for metric in snapshot.get('query',{}).get('metrics',[]):
        name=metric.get('metricname')
        if name not in accepted or metric.get('hostname')!=host or metric.get('appid')!='HOST':continue
        for timestamp,number in metric.get('metrics',{}).items():
            if not isinstance(timestamp,str) or not timestamp.isdigit() or int(timestamp)<minimum:continue
            if int(timestamp)>at+5000:continue
            values=actual.setdefault(name,{})
            require(timestamp not in values or values[timestamp]==number,'Conflicting raw metric samples')
            values[timestamp]=number
    points(actual,at)
    require(actual==accepted,'Accepted samples differ from actual Collector query')
    return accepted


def validate_queries(before,after):
    initial=observed(before);restarted=observed(after)
    require(before['hostname']==after['hostname'],'Host changed across restart')
    require(after['queried_at_ms']>before['queried_at_ms'],'Query did not advance')
    for name,values in initial.items():
        require(all(restarted[name].get(t)==v for t,v in values.items()),'Historical metric lost or changed')
        require(any(int(t)>before['queried_at_ms'] for t in restarted[name]),'No fresh metric after restart')


def validate_checksums(root):
    root=Path(root);directory=root/'rpms'
    require(directory.is_dir() and not directory.is_symlink(),'Invalid RPM directory')
    indexed={};kinds=set()
    for line in (root/'evidence/SHA256SUMS').read_text().splitlines():
        parts=line.split();require(len(parts)==2,'Malformed RPM checksum')
        digest,relative=parts
        require(re.fullmatch(r'[0-9a-f]{64}',digest),'Expected SHA256')
        name=Path(relative).name
        require(relative in (name,'./'+name,'rpms/'+name),'Unsafe checksum path')
        match=re.fullmatch(r'ambari-metrics-(collector|monitor)-3[.]0[.]0-[A-Za-z0-9._+-]+[.](x86_64|noarch)[.]rpm',name)
        require(match is not None,'Unexpected RPM name/version')
        kind,arch=match.groups()
        require(arch==('x86_64' if kind=='collector' else 'noarch'),'Unexpected architecture')
        require(kind not in kinds and name not in indexed,'Duplicate runtime RPM')
        path=directory/name;require(path.is_file() and not path.is_symlink(),'Missing or symlink RPM')
        h=hashlib.sha256()
        with path.open('rb') as stream:
            for block in iter(lambda:stream.read(1024*1024),b''):h.update(block)
        require(h.hexdigest()==digest,'RPM checksum mismatch')
        indexed[name]=digest;kinds.add(kind)
    require(kinds=={'collector','monitor'},'Need exact Collector and Monitor payloads')
    require({p.name for p in directory.iterdir()}==set(indexed),'Unexpected artifact payload')
    return indexed
