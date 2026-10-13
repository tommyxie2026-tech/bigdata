#!/usr/bin/env python3
"""Minimal Trino statement client used by the clean-container smoke test."""

from __future__ import annotations

import json
import time
import urllib.request
from collections.abc import Callable, Mapping
from typing import Any


def collect_query_response(
    response: Mapping[str, Any],
    fetch_next: Callable[[str], Mapping[str, Any]],
    *,
    timeout_seconds: int = 90,
    now: Callable[[], float] = time.monotonic,
) -> dict[str, Any]:
    """Collect row batches from every page of Trino's nextUri protocol."""
    deadline = now() + timeout_seconds
    rows: list[Any] = []
    columns = None
    current = response

    while True:
        error = current.get("error")
        if error:
            raise RuntimeError(f"Trino query failed: {json.dumps(error)}")
        if current.get("columns") is not None:
            columns = current["columns"]
        rows.extend(current.get("data") or [])

        next_uri = current.get("nextUri")
        if not next_uri:
            break
        if now() > deadline:
            raise TimeoutError("Trino SELECT 1 timed out")
        current = fetch_next(next_uri)

    return {"columns": columns, "data": rows, "stats": current.get("stats")}


def main() -> None:
    request = urllib.request.Request(
        "http://127.0.0.1:8080/v1/statement",
        data=b"SELECT 1",
        method="POST",
        headers={
            "X-Trino-User": "ci",
            "Content-Type": "text/plain; charset=utf-8",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        initial = json.load(response)

    def fetch_next(url: str) -> Mapping[str, Any]:
        with urllib.request.urlopen(url, timeout=30) as response:
            return json.load(response)

    result = collect_query_response(initial, fetch_next)
    rows = result["data"]
    if len(rows) != 1 or len(rows[0]) != 1 or str(rows[0][0]) != "1":
        raise SystemExit(f"unexpected Trino query response: {json.dumps(result)}")
    print(json.dumps({"query": "SELECT 1", "data": rows}))


if __name__ == "__main__":
    main()
