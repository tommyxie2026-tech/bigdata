"""Strict, disposable S3A fixture configuration; never a production credential source."""
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

def configuration(warehouse):
    if not re.fullmatch(r's3a://bigdata-ci-fixture/warehouse/[a-z0-9-]+',warehouse):
        raise ValueError('Expected a dedicated S3A fixture warehouse')
    values={
        'fs.s3a.impl':'org.apache.hadoop.fs.s3a.S3AFileSystem',
        'fs.s3a.endpoint':'https://localhost:8334',
        'fs.s3a.endpoint.region':'us-east-1',
        'fs.s3a.path.style.access':'true',
        'fs.s3a.connection.ssl.enabled':'true',
        'fs.s3a.ssl.channel.mode':'default_jsse_with_gcm',
        'fs.s3a.aws.credentials.provider':'org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider',
        'fs.s3a.access.key':'fixture-admin',
        'fs.s3a.secret.key':'fixture-admin-secret',
        'fs.s3a.connection.establish.timeout':'5s',
        'fs.s3a.connection.timeout':'10s',
        'fs.s3a.retry.limit':'1',
        'fs.s3a.attempts.maximum':'2',
    }
    root=ET.Element('configuration')
    for key,value in values.items():
        item=ET.SubElement(root,'property')
        ET.SubElement(item,'name').text=key
        ET.SubElement(item,'value').text=value
    return ET.tostring(root,encoding='unicode')+'\n'

if __name__=='__main__':Path(sys.argv[2]).write_text(configuration(sys.argv[1]))
