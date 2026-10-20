"""Strict result collection; missing or repeated assertions never become PASS."""
import json
import sys
from pathlib import Path
INITIAL={'tls_verified','crud_exact','list_exact','seek','readonly','denied_write','retained'}
RESTORED={'restart_exact','readonly','denied_delete','cleanup'}
def parse_phase(lines,phase,required):
    seen={}
    for line in lines:
        if not line.startswith('S3A_'):continue
        fields=line.strip().split()
        if len(fields)!=3 or fields[0]!='S3A_PASS' or fields[1]!=phase or fields[2] in seen:
            raise ValueError('Invalid assertion record: '+line)
        seen[fields[2]]='PASS'
    if set(seen)!=required:raise ValueError('Incomplete or unexpected assertion set: '+repr(seen))
    return seen
if __name__=='__main__':
    root=Path(sys.argv[1]);checks={}
    for phase,required in [('initial',INITIAL),('restored',RESTORED)]:
        result=parse_phase((root/('s3a-'+phase+'.log')).read_text().splitlines(),phase,required)
        checks.update({phase+'.'+k:v for k,v in result.items()})
    multipart=json.loads((root/'s3a-multipart.json').read_text())
    if multipart.get('status')!='PASS' or multipart.get('size')!=12*1024*1024 or not multipart.get('etag','').strip('"').endswith('-3'):
        raise ValueError('S3A multipart upload not independently verified')
    checks['s3a_multipart']='PASS'
    (root/'s3a-summary.json').write_text(json.dumps({'status':'PASS','checks':checks},indent=2)+'\n')
