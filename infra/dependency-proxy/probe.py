#!/usr/bin/env python3
"""Prove all three real package caches with exact bytes and retained proxy URLs."""
import argparse
import hashlib
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import ssl
import urllib.parse
import urllib.request
BASE='https://localhost:8443'
class Links(HTMLParser):
    def __init__(self):super().__init__();self.links=[]
    def handle_starttag(self,tag,attrs):
        if tag=='a':
            value=dict(attrs).get('href')
            if value:self.links.append(value)
def get(url, proxy=False):
    assert urllib.parse.urlsplit(url).scheme=='https','Non-HTTPS package URL rejected'
    context=ssl.create_default_context(cafile=os.environ['PROXY_CA_FILE'] if proxy else None)
    with urllib.request.urlopen(url,context=context,timeout=25) as response:
        assert urllib.parse.urlsplit(response.geturl()).scheme=='https','HTTPS downgrade rejected'
        if proxy:assert urllib.parse.urlsplit(response.geturl()).netloc=='localhost:8443','Proxy redirected client outside cache'
        data=response.read(1048577)
    assert len(data)<=1048576,'Probe artifact larger than 1 MB'
    return data
def proxy_url(value,origin):
    url=urllib.parse.urljoin(origin,value)
    parsed=urllib.parse.urlsplit(url)
    assert parsed.scheme=='https' and parsed.netloc=='localhost:8443' and parsed.path.startswith(('/npm/','/pypi/'))
    return url.split('#')[0]
def main():
    p=argparse.ArgumentParser();p.add_argument('phase',choices=['cold','warm','restarted']);p.add_argument('--evidence',type=Path,required=True);a=p.parse_args()
    a.evidence.mkdir(parents=True,exist_ok=True)
    manifest_path=a.evidence/'cache-objects.json'
    if a.phase=='cold':
        npm=json.loads(get('https://registry.npmjs.org/is-number/7.0.0'))
        proxy_npm=json.loads(get(BASE+'/npm/is-number/7.0.0',True))
        npm_url=proxy_url(proxy_npm['dist']['tarball'],BASE+'/npm/')
        py=json.loads(get('https://pypi.org/pypi/six/1.17.0/json'))
        upstream=next(x for x in py['urls'] if x['filename']=='six-1.17.0-py2.py3-none-any.whl')
        simple=BASE+'/pypi/root/pypi/+simple/six/'
        links=Links();links.feed(get(simple,True).decode())
        wheel_url=proxy_url(next(x for x in links.links if 'six-1.17.0-py2.py3-none-any.whl' in x),simple)
        maven='junit/junit/4.13.2/junit-4.13.2.jar'
        objects={'maven':{'url':BASE+'/maven/ci-maven/'+maven,'upstream':'https://repo.maven.apache.org/maven2/'+maven},
                 'npm':{'url':npm_url,'upstream':npm['dist']['tarball']},
                 'pypi':{'url':wheel_url,'upstream':upstream['url']}}
        for name,value in objects.items():
            reference=get(value['upstream']);actual=get(value['url'],True)
            assert actual==reference,name+' cold proxy bytes differ'
            value['sha256']=hashlib.sha256(actual).hexdigest()
            if name=='npm':
                import base64
                assert 'sha512-'+base64.b64encode(hashlib.sha512(actual).digest()).decode()==npm['dist']['integrity']
            if name=='pypi':assert value['sha256']==upstream['digests']['sha256']
            value.pop('upstream')
        manifest_path.write_text(json.dumps(objects,indent=2)+'\n')
    else:
        objects=json.loads(manifest_path.read_text())
        for name,value in objects.items():
            assert hashlib.sha256(get(value['url'],True)).hexdigest()==value['sha256'],name+' cache bytes changed'
    (a.evidence/(a.phase+'-evidence.json')).write_text(json.dumps({'phase':a.phase,'objects':objects,'status':'PASS'},indent=2)+'\n')
    print(a.phase+': PASS Maven, npm and PyPI bytes match')
if __name__=='__main__':main()
