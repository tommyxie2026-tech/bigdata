"""Reuse a successful packaging job only when all payload inputs still match."""
import base64
import json
import os
from pathlib import Path
import subprocess
import yaml

WORKFLOW='.github/workflows/ambari-metrics-rpms.yml'
INPUTS=['package-rpms.sh','prepare-rpm-config.py','runtime.sh','port_monitor.py','contract.json',
        'specs/collector.spec','specs/monitor.spec',
        'units/ambari-metrics-collector.service','units/ambari-metrics-hbase.service',
        'units/ambari-metrics-monitor.service']

def package_identity(workflow):
    package=dict(workflow['jobs']['package'])
    for orchestration in ['needs','if']:package.pop(orchestration,None)
    return {'job':package,'source':{key:workflow['env'][key] for key in ['SOURCE_BUILD_RUN_ID','SOURCE_BUILD_HEAD']}}

def main():
    repo=os.environ['GITHUB_REPOSITORY'];run=os.environ['RPM_REUSE_RUN']
    assert run.isdigit()
    def api(path):return json.loads(subprocess.check_output(['gh','api',f'repos/{repo}/{path}']))
    metadata=api(f'actions/runs/{run}')
    assert metadata['head_repository']['full_name']==repo and metadata['status']=='completed'
    assert metadata['path']==WORKFLOW
    jobs=api(f'actions/runs/{run}/jobs?filter=latest&per_page=100')['jobs']
    assert any(j['name']=='Package real Collector and Monitor RPMs' and j['conclusion']=='success' for j in jobs)
    artifacts=api(f'actions/runs/{run}/artifacts?per_page=100')['artifacts']
    assert any(a['name']=='ambari-metrics-3.0.0-candidate-rpms' and not a['expired'] for a in artifacts)
    sha=metadata['head_sha']
    def original(path):return base64.b64decode(api(f'contents/{path}?ref={sha}')['content'])
    same=package_identity(yaml.safe_load(original(WORKFLOW)))==package_identity(yaml.safe_load(Path(WORKFLOW).read_bytes()))
    for relative in INPUTS:
        path='scripts/ambari-metrics/'+relative
        same=original(path)==Path(path).read_bytes() and same
    with open(os.environ['GITHUB_OUTPUT'],'a') as out:
        out.write('build='+str(not same).lower()+'\n')
        out.write('run='+ (run if same else os.environ['GITHUB_RUN_ID'])+'\n')
    print('unchanged validated RPM reuse' if same else 'packaging inputs changed; fresh RPM required')

if __name__=='__main__':main()
