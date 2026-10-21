#!/usr/bin/env python3
"""Assemble a candidate only from proven same-repository build and real-test jobs."""
import argparse
import base64
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import yaml
from contract import require,validate_acceptance,validate_queries,validate_checksums,SOURCE

ROOT=Path(__file__).resolve().parents[2]
WORKFLOW='.github/workflows/ambari-metrics-rpms.yml'
PACKAGE='Package real Collector and Monitor RPMs'
TEST='Clean openEuler install and real Collector restart persistence'


def successful(jobs,name):
    found=[j for j in jobs if j.get('name')==name]
    return bool(found) and all(j.get('status')=='completed' and j.get('conclusion')=='success' for j in found)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--test-run-id',required=True)
    parser.add_argument('--package-run-id',required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    require(all(x.isdigit() and int(x)>0 for x in [args.test_run_id,args.package_run_id]),'Invalid run ID')
    require(not args.output.exists(),'Candidate output must be fresh')
    repo=os.environ['GITHUB_REPOSITORY']
    def api(path):return json.loads(subprocess.check_output(['gh','api',f'repos/{repo}/{path}'],timeout=45))
    def run(run_id):
        value=api(f'actions/runs/{run_id}')
        require(value.get('head_repository',{}).get('full_name')==repo,'Foreign producer/test')
        require(value.get('status')=='completed' and value.get('path')==WORKFLOW,'Wrong or live workflow')
        return value,api(f'actions/runs/{run_id}/jobs?filter=latest&per_page=100')['jobs']
    producer,producer_jobs=run(args.package_run_id)
    tested,test_jobs=run(args.test_run_id)
    require(successful(producer_jobs,PACKAGE),'No actual successful RPM packaging job')
    require(successful(test_jobs,TEST),'No actual successful clean-install/persistence job')
    def original(sha,path):
        return base64.b64decode(api(f'contents/{path}?ref={sha}')['content'])
    spec=importlib.util.spec_from_file_location('rpm_selector',ROOT/'scripts/ambari-metrics/select-rpm.py')
    selector=importlib.util.module_from_spec(spec);spec.loader.exec_module(selector)
    current=yaml.safe_load((ROOT/WORKFLOW).read_bytes())
    old=yaml.safe_load(original(producer['head_sha'],WORKFLOW))
    test_workflow=yaml.safe_load(original(tested['head_sha'],WORKFLOW))
    require(selector.package_identity(old)==selector.package_identity(current),'Packaging job/source changed')
    require(selector.package_identity(test_workflow)==selector.package_identity(current),'Test used different packaging inputs')
    require(test_workflow['jobs']['test']==current['jobs']['test'],'Acceptance workflow changed')
    hashes={}
    for relative in selector.INPUTS:
        path='scripts/ambari-metrics/'+relative;value=(ROOT/path).read_bytes()
        require(original(producer['head_sha'],path)==value,'Producer payload recipe changed: '+path)
        require(original(tested['head_sha'],path)==value,'Test payload recipe changed: '+path)
        hashes[path]=hashlib.sha256(value).hexdigest()
    for relative in ['test-rpms.sh','test_collector_live.py','verify_collector.py','select-rpm.py']:
        path='scripts/ambari-metrics/'+relative
        require(original(tested['head_sha'],path)==(ROOT/path).read_bytes(),'Acceptance logic changed: '+path)
    if args.package_run_id==args.test_run_id:
        require(successful(test_jobs,PACKAGE),'Same-run packaging did not actually run')
    else:
        packaging=[j for j in test_jobs if j.get('name')==PACKAGE]
        require(packaging and all(j.get('conclusion')=='skipped' for j in packaging),'Unexpected producer selection')
        require(successful(test_jobs,'select'),'RPM reuse selector did not pass')
        require(str(test_workflow['env']['RPM_REUSE_RUN'])==args.package_run_id,'Test did not select this RPM producer')
    with tempfile.TemporaryDirectory() as temp:
        temp=Path(temp);candidate=temp/'candidate';evidence=temp/'tested'
        for run_id,name,path in [(args.package_run_id,'ambari-metrics-3.0.0-candidate-rpms',candidate),
                                  (args.test_run_id,'ambari-metrics-3.0.0-rpm-installation-evidence',evidence)]:
            subprocess.run(['gh','run','download',run_id,'--repo',repo,'--name',name,'--dir',str(path)],check=True,timeout=600)
        acceptance=json.loads((evidence/'acceptance.json').read_text());validate_acceptance(acceptance)
        initial=json.loads((evidence/'initial-query.json').read_text())
        restarted=json.loads((evidence/'restarted-query.json').read_text());validate_queries(initial,restarted)
        digests=validate_checksums(candidate)
        # Header validation happens on CI, without installing or trusting filenames alone.
        command="set -e; for file in /rpm/*.rpm; do rpm -qp --queryformat '%{NAME} %{VERSION} %{ARCH}\\n' \"$file\"; done"
        actual=subprocess.check_output(['docker','run','--rm','-v',str(candidate/'rpms')+':/rpm:ro',
            'openeuler/openeuler:22.03-lts-sp4','bash','-c',command],text=True,timeout=180)
        require(set(actual.splitlines())=={'ambari-metrics-collector 3.0.0 x86_64','ambari-metrics-monitor 3.0.0 noarch'},'RPM header identity mismatch')
        args.output.mkdir(parents=True)
        shutil.copytree(candidate/'rpms',args.output/'rpms')
        shutil.copytree(evidence,args.output/'test-evidence')
        shutil.copytree(candidate/'evidence',args.output/'build-evidence')
        (args.output/'evidence').mkdir()
        (args.output/'evidence/SHA256SUMS').write_text(''.join(d+'  rpms/'+n+'\n' for n,d in sorted(digests.items())))
        identity=hashlib.sha256(json.dumps(hashes,sort_keys=True,separators=(',',':')).encode()).hexdigest()
        result={'schema':'bigdata.metrics-candidate/v1','component':'ambari-metrics','version':'3.0.0',
            'source_identity':SOURCE,'compatibility_identity':identity,'packaging_inputs':hashes,
            'build_run_id':int(args.package_run_id),'test_run_id':int(args.test_run_id),
            'producer_head':producer['head_sha'],'tested_head':tested['head_sha'],
            'rpm_sha256':digests,'actual_acceptance':'PASS','publication':'NOT_RUN'}
        (args.output/'evidence/candidate.json').write_text(json.dumps(result,indent=2)+'\n')
        print('Validated original RPMs, actual host query history and restart; release candidate assembled')

if __name__=='__main__':main()
