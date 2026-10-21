#!/usr/bin/env python3
"""Report observed queue/job times without treating skipped or live jobs as passed."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import urllib.request


def elapsed(start, end):
    if not start or not end:
        return None
    try:
        seconds=(datetime.fromisoformat(end.replace('Z','+00:00')) -
                 datetime.fromisoformat(start.replace('Z','+00:00'))).total_seconds()
    except (ValueError, TypeError):
        return None
    return seconds if seconds >= 0 else None


def timing_report(run, jobs, *, component, build_run_id='', test_run_id=''):
    return {'schema':'bigdata.ci-timing/v1', 'component':component,
            'run_id':run.get('id'), 'head_sha':run.get('head_sha'),
            'run_status':run.get('status'), 'run_conclusion':run.get('conclusion'),
            'observed_at':datetime.now(timezone.utc).isoformat(),
            'run_queue_seconds':elapsed(run.get('created_at'),run.get('run_started_at')),
            'original_build_run_id':build_run_id or None,
            'reused_test_run_id':test_run_id or None,
            'jobs':[{'id':job.get('id'), 'name':job.get('name'),
                     'status':job.get('status'), 'conclusion':job.get('conclusion'),
                     'duration_seconds':elapsed(job.get('started_at'),job.get('completed_at'))}
                    for job in jobs]}


def get_api(path):
    request=urllib.request.Request('https://api.github.com/repos/'+os.environ['GITHUB_REPOSITORY']+'/'+path,
        headers={'Authorization':'Bearer '+os.environ['GITHUB_TOKEN'],
                 'Accept':'application/vnd.github+json'})
    with urllib.request.urlopen(request,timeout=20) as response:
        return json.load(response)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--component',required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    run_id=os.environ['GITHUB_RUN_ID']
    run=get_api('actions/runs/'+run_id)
    jobs=[]
    for page in range(1,11):
        batch=get_api('actions/runs/'+run_id+'/jobs?filter=latest&per_page=100&page='+str(page))['jobs']
        jobs.extend(batch)
        if len(batch)<100:break
    else:
        raise ValueError('Timing job inventory is incomplete')
    report=timing_report(run,jobs,component=args.component,
                         build_run_id=os.environ.get('RPM_BUILD_RUN_ID',''),
                         test_run_id=os.environ.get('PR_TEST_RUN_ID',''))
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')
    summary=os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary,'a') as stream:
            stream.write('\n### Observed CI timings: '+args.component+'\n\n')
            stream.write('Run queue: '+str(report['run_queue_seconds'])+' seconds. In-progress/unknown durations remain null.\n\n')
            stream.write('| Job | Status | Conclusion | Seconds |\n|---|---|---|---|\n')
            for job in report['jobs']:
                name=str(job['name']).replace('|','/').replace('\n',' ')
                stream.write('| '+name+' | '+str(job['status'])+' | '+str(job['conclusion'])+' | '+str(job['duration_seconds'])+' |\n')
    print('Wrote observed CI timing evidence to '+str(args.output))


if __name__=='__main__':main()
