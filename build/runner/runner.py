#!/usr/bin/env python3
"""Fortress Fargate execution runner (Phase 1 stub).

Reads JSON from FORTRESS_TASK_SPEC (defaults to {}). Writes JSON to
FORTRESS_RESULT_PATH (defaults to /tmp/result.json). Stdlib only.
"""

from __future__ import annotations

import json
import os
import sys
from typing import Any


def main() -> int:
    raw = os.environ.get("FORTRESS_TASK_SPEC", "{}")
    out_path = os.environ.get("FORTRESS_RESULT_PATH", "/tmp/result.json")

    try:
        spec: Any = json.loads(raw)
    except json.JSONDecodeError as e:
        err = {"ok": False, "error": f"invalid FORTRESS_TASK_SPEC JSON: {e}"}
        _write_json(out_path, err)
        return 1

    result = {
        "ok": True,
        "echo": spec,
        "message": "fortress-runner Phase 1 stub",
    }
    _write_json(out_path, result)
    print(json.dumps({"wrote": out_path, "ok": True}))
    return 0


def _write_json(path: str, obj: Any) -> None:
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, mode=0o755, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    sys.exit(main())
