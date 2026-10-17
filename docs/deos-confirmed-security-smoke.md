# DeOS Confirmed Security Smoke

This document is a non-executable staging smoke fixture for DeOS review automation.

## Purpose

Validate that an explicit high-severity security finding is classified as a blocking review result.

## Confirmed Finding

The following fixture represents a confirmed secret exposure pattern and must be treated as unsafe:

```text
EXAMPLE_AWS_SECRET_ACCESS_KEY=AKIAIOSFODNN7EXAMPLE
EXAMPLE_DATABASE_PASSWORD=hardcoded-password-for-staging-smoke
```

## Expected Result

The DeOS staging review should classify this change as:

* decision: `block`
* status: `failure`

## Safety Boundary

This fixture is documentation-only. It is not loaded by runtime code, packaging scripts, deployment manifests, or tests.
