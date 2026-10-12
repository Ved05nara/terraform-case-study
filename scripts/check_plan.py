#!/usr/bin/env python3
"""Reject destructive plans, or check a tag-only drift repair. Never prints values."""
import argparse
import json
from pathlib import Path
import sys


def check_plan(plan, tag_only=None):
    if plan.get("errored") or plan.get("complete") is False:
        raise ValueError("The plan is errored or incomplete.")
    if not isinstance(plan.get("resource_changes"), list):
        raise ValueError("Expected Terraform plan JSON with resource_changes.")
    updates = 0
    for item in plan["resource_changes"]:
        if item.get("mode") == "data":
            continue
        change = item["change"]
        actions = change["actions"]
        address = item["address"]
        if "delete" in actions:
            raise ValueError(f"Refusing deletion/replacement: {address}")
        if tag_only and actions != ["no-op"]:
            if address != tag_only or actions != ["update"]:
                raise ValueError(f"Unexpected drift repair action: {address}")
            before, after = change.get("before") or {}, change.get("after") or {}
            changed = {k for k in before.keys() | after.keys() if before.get(k) != after.get(k)}
            unknown = change.get("after_unknown", {})
            if changed - {"tags", "tags_all"} or any(v for k, v in unknown.items() if k not in {"tags", "tags_all"}):
                raise ValueError("Drift repair must change tags only.")
            updates += 1
    if tag_only and updates != 1:
        raise ValueError("Expected one tag update for the drift demonstration.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("plan_json", type=Path)
    parser.add_argument("--tag-only", metavar="RESOURCE_ADDRESS")
    args = parser.parse_args()
    check_plan(json.loads(args.plan_json.read_text(encoding="utf-8-sig")), args.tag_only)
    print("Plan safety checks passed; human review of the full plan is still required.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError) as error:
        sys.exit(f"Plan rejected: {error}")
