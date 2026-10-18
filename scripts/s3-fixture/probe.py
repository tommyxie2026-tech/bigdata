"""Exercise a real TLS S3 endpoint; all credentials below are disposable fixture data."""
import argparse
import hashlib
import json
import time
from pathlib import Path
import boto3
from botocore import UNSIGNED
from botocore.config import Config
from botocore.exceptions import ClientError,SSLError
from checks import require_denied,exact_keys,write_report

BUCKET="bigdata-ci-fixture"
PROOF=b"seaweedfs-4.48-bigdata-restart-proof-v1"
KEY="persistent/proof.txt"
INITIAL={"tls_verified","crud","list_exact","multipart_complete","multipart_abort",
         "readonly_denied","bad_key_denied","bad_secret_denied","anonymous_denied",
         "untrusted_tls_denied","retained_object"}
RESTORED={"tls_verified","restart_read","permissions_retained","cleanup"}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase",choices=("initial","restored"))
    parser.add_argument("--endpoint",required=True)
    parser.add_argument("--ca",required=True)
    parser.add_argument("--evidence",required=True)
    args=parser.parse_args()
    if not args.endpoint.startswith("https://"):
        raise ValueError("A verified HTTPS endpoint is required")
    evidence=Path(args.evidence);evidence.mkdir(parents=True,exist_ok=True)
    checks={}
    observed={'denials':[]}
    def client(access="fixture-admin",secret="fixture-admin-secret",verify=None,unsigned=False):
        return boto3.client("s3",endpoint_url=args.endpoint,region_name="us-east-1",
            aws_access_key_id=access,aws_secret_access_key=secret,
            verify=args.ca if verify is None else verify,
            config=Config(signature_version=UNSIGNED if unsigned else "s3v4",
                connect_timeout=2,read_timeout=5,retries={"max_attempts":1,"mode":"standard"},
                s3={"addressing_style":"path"}))
    admin=client()
    deadline=time.monotonic()+180
    while True:
        try:
            admin.list_buckets()
            break
        except Exception:
            if time.monotonic()>=deadline:raise
            time.sleep(2)
    checks["tls_verified"]="PASS"
    def read(key):
        response=admin.get_object(Bucket=BUCKET,Key=key)
        with response["Body"] as body:
            return body.read()
    def denied(c,operation,**kwargs):
        try: getattr(c,operation)(**kwargs)
        except ClientError as error:
            require_denied(error.response)
            observed['denials'].append({'operation':operation,'http_status':403,'code':error.response['Error']['Code']})
        else:raise AssertionError("Unauthorized request unexpectedly succeeded")
    if args.phase=="initial":
        admin.create_bucket(Bucket=BUCKET)
        assert admin.head_bucket(Bucket=BUCKET)["ResponseMetadata"]["HTTPStatusCode"]==200
        assert BUCKET in {b["Name"] for b in admin.list_buckets()["Buckets"]}
        payload=(b"bigdata-s3-fixture"+bytes([0])+b"exact-object-body")*32
        key="objects/value.bin"
        admin.put_object(Bucket=BUCKET,Key=key,Body=payload)
        actual=read(key)
        assert actual==payload
        observed['crud']={'size':len(actual),'sha256':hashlib.sha256(actual).hexdigest()}
        response=admin.list_objects_v2(Bucket=BUCKET)
        assert not response.get("IsTruncated")
        exact_keys(response.get("Contents",[]),{key})
        checks["list_exact"]="PASS"
        reader=client("fixture-reader","fixture-reader-secret")
        with reader.get_object(Bucket=BUCKET,Key=key)["Body"] as body:assert body.read()==payload
        denied(reader,"put_object",Bucket=BUCKET,Key="forbidden",Body=b"not-allowed")
        checks["readonly_denied"]="PASS"
        denied(client("unknown-key","unknown-secret"),"get_object",Bucket=BUCKET,Key=key)
        checks["bad_key_denied"]="PASS"
        denied(client(secret="wrong-secret"),"get_object",Bucket=BUCKET,Key=key)
        checks["bad_secret_denied"]="PASS"
        denied(client(unsigned=True),"get_object",Bucket=BUCKET,Key=key)
        checks["anonymous_denied"]="PASS"
        try:client(verify=True).list_buckets()
        except SSLError:checks["untrusted_tls_denied"]="PASS"
        else:raise AssertionError("Self-signed TLS endpoint was accepted without its CA")
        admin.delete_object(Bucket=BUCKET,Key=key)
        try:admin.get_object(Bucket=BUCKET,Key=key)
        except ClientError as error:
            assert error.response["ResponseMetadata"]["HTTPStatusCode"]==404
            assert error.response["Error"]["Code"]=="NoSuchKey"
        else:raise AssertionError("Deleted object remained readable")
        checks["crud"]="PASS"
        key="multipart/complete.bin"
        upload=admin.create_multipart_upload(Bucket=BUCKET,Key=key)["UploadId"]
        parts=[];digest=hashlib.sha256()
        for number,body in enumerate((b"A"*(5*1024*1024),b"B"*(1024*1024)),1):
            digest.update(body)
            part=admin.upload_part(Bucket=BUCKET,Key=key,UploadId=upload,PartNumber=number,Body=body)
            parts.append({"PartNumber":number,"ETag":part["ETag"]})
        admin.complete_multipart_upload(Bucket=BUCKET,Key=key,UploadId=upload,MultipartUpload={"Parts":parts})
        actual=read(key)
        assert hashlib.sha256(actual).hexdigest()==digest.hexdigest()
        observed['multipart']={'size':len(actual),'sha256':digest.hexdigest()}
        admin.delete_object(Bucket=BUCKET,Key=key)
        checks["multipart_complete"]="PASS"
        aborted=admin.create_multipart_upload(Bucket=BUCKET,Key="multipart/abort")["UploadId"]
        admin.upload_part(Bucket=BUCKET,Key="multipart/abort",UploadId=aborted,PartNumber=1,Body=b"discard")
        admin.abort_multipart_upload(Bucket=BUCKET,Key="multipart/abort",UploadId=aborted)
        assert not admin.list_multipart_uploads(Bucket=BUCKET).get("Uploads")
        checks["multipart_abort"]="PASS"
        admin.put_object(Bucket=BUCKET,Key=KEY,Body=PROOF,Metadata={"sha256":hashlib.sha256(PROOF).hexdigest()})
        assert read(KEY)==PROOF
        exact_keys(admin.list_objects_v2(Bucket=BUCKET).get("Contents",[]),{KEY})
        checks["retained_object"]="PASS"
    else:
        assert read(KEY)==PROOF
        assert admin.head_object(Bucket=BUCKET,Key=KEY)["Metadata"]["sha256"]==hashlib.sha256(PROOF).hexdigest()
        exact_keys(admin.list_objects_v2(Bucket=BUCKET).get("Contents",[]),{KEY})
        observed["restart"]={"size":len(PROOF),"sha256":hashlib.sha256(read(KEY)).hexdigest()}
        checks["restart_read"]="PASS"
        denied(client("fixture-reader","fixture-reader-secret"),"delete_object",Bucket=BUCKET,Key=KEY)
        checks["permissions_retained"]="PASS"
        admin.delete_object(Bucket=BUCKET,Key=KEY)
        exact_keys(admin.list_objects_v2(Bucket=BUCKET).get("Contents",[]),set())
        admin.delete_bucket(Bucket=BUCKET)
        assert BUCKET not in {b["Name"] for b in admin.list_buckets()["Buckets"]}
        checks["cleanup"]="PASS"
    (evidence/(args.phase+"-observations.json")).write_text(json.dumps(observed,indent=2)+"\n")
    write_report(evidence/(args.phase+".json"),checks,INITIAL if args.phase=="initial" else RESTORED)
    print(json.dumps({"phase":args.phase,"checks":checks,"status":"PASS"},sort_keys=True))

if __name__=="__main__":main()
