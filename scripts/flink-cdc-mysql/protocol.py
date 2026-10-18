"""Validate Flink savepoint/restore evidence; pending and fresh starts never pass."""
import json
import sys

def savepoint_location(response):
    if response.get("status", {}).get("id") != "COMPLETED":
        raise ValueError("savepoint operation has not completed")
    operation = response.get("operation", {})
    if operation.get("failure-cause") or not operation.get("location"):
        raise ValueError("savepoint failed or has no location")
    return operation["location"]

def verify_stopped(response):
    if response.get("state") != "FINISHED":
        raise ValueError("original job has not finished stopping with savepoint")

def verify_restored(response, expected):
    restored = response.get("latest", {}).get("restored", {})
    if restored.get("external_path") != expected or restored.get("is_savepoint") is not True:
        raise ValueError("job has not restored the expected savepoint")

if __name__ == "__main__":
    data = json.load(sys.stdin)
    if sys.argv[1] == "location":
        print(savepoint_location(data))
    elif sys.argv[1] == "stopped":
        verify_stopped(data)
    elif sys.argv[1] == "restored":
        verify_restored(data, sys.argv[2])
    else:
        raise SystemExit("unknown protocol operation")
