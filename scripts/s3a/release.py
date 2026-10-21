"""Release gate for actual S3A and fixture assertions, never skipped jobs."""
import json,os,sys
from pathlib import Path
from results import INITIAL,RESTORED
API_INITIAL={'tls_verified','crud','list_exact','multipart_complete','multipart_abort','readonly_denied','bad_key_denied','bad_secret_denied','anonymous_denied','untrusted_tls_denied','retained_object'}
API_RESTORED={'tls_verified','restart_read','permissions_retained','cleanup'}
def validate(s3a,api):
    expected_s3a={'initial.'+k for k in INITIAL}|{'restored.'+k for k in RESTORED}|{'s3a_multipart'}
    expected_api={'initial.'+k for k in API_INITIAL}|{'restored.'+k for k in API_RESTORED}
    for report,expected in [(s3a,expected_s3a),(api,expected_api)]:
        if report.get('status')!='PASS' or set(report.get('checks',{}))!=expected or any(v!='PASS' for v in report['checks'].values()):
            raise ValueError('Incomplete or unsuccessful actual integration evidence')
if __name__=='__main__':
    root=Path(sys.argv[1]);s=json.loads((root/'s3a-summary.json').read_text());a=json.loads((root/'summary.json').read_text());validate(s,a)
    record={'status':'PASS','build_run_id':os.environ['SDK_PACKAGE_RUN'],'test_run_id':os.environ['GITHUB_RUN_ID'],'test_head_sha':os.environ['GITHUB_SHA'],'s3a':s,'api':a}
    (root/'release-evidence.json').write_text(json.dumps(record,indent=2)+'\n')
