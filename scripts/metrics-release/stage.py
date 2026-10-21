#!/usr/bin/env python3
"""Stage an evidence-validated Metrics candidate; never overwrite an existing release."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
from contract import SOURCE,require,validate_acceptance,validate_queries,validate_checksums

ROOT=Path(__file__).resolve().parents[2]


def stage(candidate,target):
    candidate,target=Path(candidate),Path(target)
    value=json.loads((candidate/'evidence/candidate.json').read_text())
    require(value.get('schema')=='bigdata.metrics-candidate/v1','Wrong candidate schema')
    require(value.get('component')=='ambari-metrics' and value.get('version')=='3.0.0','Wrong candidate component/version')
    require(value.get('source_identity')==SOURCE,'Wrong source identity')
    require(value.get('actual_acceptance')=='PASS' and value.get('publication')=='NOT_RUN','Unproven candidate')
    require(all(type(value.get(k)) is int and value[k]>0 for k in ['build_run_id','test_run_id']),'Invalid original runs')
    require(all(re.fullmatch('[0-9a-f]{40}',str(value.get(k,''))) for k in ['producer_head','tested_head']),'Invalid original heads')
    inputs=value.get('packaging_inputs')
    require(isinstance(inputs,dict) and inputs and all(isinstance(k,str) and re.fullmatch('[0-9a-f]{64}',str(v)) for k,v in inputs.items()),'Invalid payload identity')
    identity=hashlib.sha256(json.dumps(inputs,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    require(identity==value.get('compatibility_identity'),'Packaging identity mismatch')
    checksums=validate_checksums(candidate)
    require(checksums==value.get('rpm_sha256'),'Candidate digest identity mismatch')
    evidence=candidate/'test-evidence'
    validate_acceptance(json.loads((evidence/'acceptance.json').read_text()))
    validate_queries(json.loads((evidence/'initial-query.json').read_text()),json.loads((evidence/'restarted-query.json').read_text()))
    require(re.fullmatch('[0-9a-f]{40}',os.environ.get('GITHUB_SHA','')),'Invalid promotion commit')
    require(not target.exists(),'Existing Metrics release: compare published evidence and use a reviewed release revision')
    target.mkdir(parents=True)
    for name in checksums:shutil.copy2(candidate/'rpms'/name,target/name)
    (target/'SHA256SUMS').write_text(''.join(d+'  ./'+n+'\n' for n,d in sorted(checksums.items())))
    # Raw upstream logs are immutable diagnostics, not source-controlled text.
    # Retain them in the original Actions artifact and index their exact bytes.
    published=target/'test-evidence';published.mkdir()
    for name in ['acceptance.json','initial-query.json','restarted-query.json']:
        shutil.copy2(evidence/name,published/name)
    files={str(path.relative_to(evidence)):hashlib.sha256(path.read_bytes()).hexdigest()
           for path in sorted(evidence.rglob('*')) if path.is_file()}
    reference={'repository':os.environ.get('GITHUB_REPOSITORY','tommyxie2026-tech/bigdata'),
        'artifact_name':'ambari-metrics-3.0.0-rpm-installation-evidence',
        'test_run_id':value['test_run_id'],'files':files}
    (published/'artifact-index.json').write_text(json.dumps(reference,indent=2,sort_keys=True)+'\n')
    shutil.copytree(candidate/'build-evidence',target/'build-evidence')
    shutil.copy2(candidate/'evidence/candidate.json',target/'candidate.json')
    fields={'schema':'bigdata.rpm-repo/v2','component':'ambari-metrics','version':'3.0.0',
        'bigtop_version':'3.6.0','artifact_type':'management-plane-rpm',
        'test_profile':'real-host-cpu-memory-collector-restart-persistence','jdk':8,
        'jdk_package':'java-1.8.0-openjdk-devel','build_run_id':value['build_run_id'],
        'test_run_id':value['test_run_id'],'tested_artifact_run_id':value['test_run_id'],
        'promotion_workflow_commit':os.environ['GITHUB_SHA'],'source_identity':SOURCE,
        'compatibility_identity':identity,'compatibility_identity_format':'metrics-packaging-inputs-json/v1',
        'os':'openEuler 22.03 LTS SP4','rpm_count':2,'test_status':'PASS','repository_layout':'split-runtime/v2'}
    (target/'manifest.yaml').write_text(''.join(f'{key}: {item}\n' for key,item in fields.items()))


def verify_metadata(target):
    spec=importlib.util.spec_from_file_location('repository_verifier',ROOT/'scripts/ci/check-component-repo-fast-path.py')
    check=importlib.util.module_from_spec(spec);spec.loader.exec_module(check)
    digests=check.parse_checksum_file(target/'SHA256SUMS')
    entries=check.validate_repomd(target)
    primary=next(e['location'] for e in entries if e['type']=='primary')
    check.validate_primary(target,primary,'ambari-metrics','3.0.0',
        {'ambari-metrics-collector','ambari-metrics-monitor'},digests)
    print('Verified RPM checksums and complete repository metadata')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate',type=Path)
    parser.add_argument('--target',type=Path,required=True)
    parser.add_argument('--verify-metadata',action='store_true')
    args=parser.parse_args()
    if args.verify_metadata:verify_metadata(args.target)
    else:
        require(args.candidate is not None,'Candidate is required')
        stage(args.candidate,args.target)
