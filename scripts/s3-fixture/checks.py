"""Strict assertions: HTTP/network failures are never mistaken for access denial."""
import json
def require_denied(response):
    if (response.get("ResponseMetadata",{}).get("HTTPStatusCode") != 403 or
        response.get("Error",{}).get("Code") not in
        {"AccessDenied","InvalidAccessKeyId","SignatureDoesNotMatch"}):
        raise ValueError("Expected an actual S3 authorization rejection: " + repr(response))
def exact_keys(contents, expected):
    keys=[entry["Key"] for entry in contents]
    if len(keys)!=len(set(keys)) or set(keys)!=expected:
        raise ValueError("Unexpected object inventory: " + repr(keys))
def write_report(path, checks, required):
    if not required.issubset(checks) or any(checks[k]!="PASS" for k in required):
        raise ValueError("Required checks did not all pass")
    path.write_text(json.dumps({"status":"PASS","checks":checks},indent=2)+"\n")
