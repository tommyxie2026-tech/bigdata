# DeOS Coverage Gap Smoke

This document is a non-executable staging smoke fixture for DeOS review automation.

## Proposed Critical Change

The retention metadata contract is changed from a nullable timestamp to a required epoch value:

```text
retention_expires_at: optional timestamp -> required int64 epoch_seconds
```

Consumers are expected to treat `0` as "retain forever" and positive values as an expiration deadline.

## Missing Test Evidence

This change intentionally includes no evidence for:

* migration of existing null values;
* rollback compatibility with older consumers;
* boundary behavior at `0` and the maximum `int64` value;
* mixed-version reader and writer behavior.

## Expected Result

The DeOS staging review should classify this change as:

* decision: `review`
* status: `neutral`

## Safety Boundary

This fixture is documentation-only. It is not loaded by runtime code, migrations, packaging scripts, deployment manifests, or tests.
