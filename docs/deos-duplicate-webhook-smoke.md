# DeOS Duplicate Webhook Smoke

This document is a non-executable staging smoke fixture for DeOS review automation.

## Purpose

Validate that two deliveries for the same pull request head SHA update one DecisionOS summary comment instead of creating duplicates.

## Replay Contract

Both deliveries must use the same:

* repository;
* pull request number;
* base SHA;
* head SHA;
* DecisionOS summary idempotency key.

## Expected Result

The DeOS staging review should classify this change as:

* decision: `review`
* status: `neutral`
* DecisionOS summary marker count after both deliveries: `1`

## Safety Boundary

This fixture is documentation-only. It is not loaded by runtime code, packaging scripts, deployment manifests, dependencies, or tests.
