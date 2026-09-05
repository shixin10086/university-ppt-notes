#!/usr/bin/env python3
"""Create and maintain metadata-only progress for the guided notes workflow."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


STAGES = {
    "ppt_confirmed", "deck_analyzed", "batch_drafting", "batch_review",
    "batch_written", "final_audit", "revision_review", "final_export", "complete",
}
AUDIT_STATUSES = {"not_started", "in_progress", "issues", "passed"}
STATE_KEYS = {
    "schema_version", "ppt_path", "slide_count", "target_start", "target_end",
    "batch_size", "confirmed_through", "current_batch", "stage",
    "cumulative_notes_path", "audit", "outputs", "updated_at",
}


def timestamp() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def validate(data: dict) -> None:
    unexpected = set(data) - STATE_KEYS
    if unexpected:
        raise ValueError(f"State contains unsupported fields: {sorted(unexpected)}")
    if set(data["current_batch"]) != {"start", "end"}:
        raise ValueError("current_batch contains unsupported fields.")
    if set(data["audit"]) != {"status", "issue_pages"}:
        raise ValueError("audit contains unsupported fields.")
    count = int(data["slide_count"])
    start = int(data["target_start"])
    end = int(data["target_end"])
    confirmed = int(data["confirmed_through"])
    batch = data["current_batch"]
    if count < 1 or not (1 <= start <= end <= count):
        raise ValueError("Target range must be inside the PPT slide range.")
    if not (start - 1 <= confirmed <= end):
        raise ValueError("confirmed_through must be immediately before or inside the target range.")
    if not (start <= int(batch["start"]) <= int(batch["end"]) <= end):
        raise ValueError("Current batch must be inside the target range.")
    if data["stage"] not in STAGES:
        raise ValueError(f"Unknown stage: {data['stage']}")
    if data["audit"]["status"] not in AUDIT_STATUSES:
        raise ValueError(f"Unknown audit status: {data['audit']['status']}")
    if any(int(page) < start or int(page) > end for page in data["audit"].get("issue_pages", [])):
        raise ValueError("Audit issue page is outside the target range.")


def read_state(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    validate(data)
    return data


def write_state(path: Path, data: dict) -> None:
    validate(data)
    data["updated_at"] = timestamp()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def command_init(args: argparse.Namespace) -> dict:
    target_end = args.target_end or args.slide_count
    data = {
        "schema_version": 1,
        "ppt_path": args.ppt,
        "slide_count": args.slide_count,
        "target_start": args.target_start,
        "target_end": target_end,
        "batch_size": args.batch_size,
        "confirmed_through": args.confirmed_through if args.confirmed_through is not None else args.target_start - 1,
        "current_batch": {
            "start": args.target_start,
            "end": min(args.target_start + args.batch_size - 1, target_end),
        },
        "stage": "ppt_confirmed",
        "cumulative_notes_path": args.notes or "",
        "audit": {"status": "not_started", "issue_pages": []},
        "outputs": [],
        "updated_at": "",
    }
    write_state(args.state, data)
    return data


def command_update(args: argparse.Namespace) -> dict:
    data = read_state(args.state)
    if args.stage:
        data["stage"] = args.stage
    if args.confirmed_through is not None:
        data["confirmed_through"] = args.confirmed_through
    if args.batch_start is not None or args.batch_end is not None:
        if args.batch_start is None or args.batch_end is None:
            raise ValueError("Provide both --batch-start and --batch-end.")
        data["current_batch"] = {"start": args.batch_start, "end": args.batch_end}
    if args.notes is not None:
        data["cumulative_notes_path"] = args.notes
    if args.audit_status:
        data["audit"]["status"] = args.audit_status
    if args.issue_pages is not None:
        data["audit"]["issue_pages"] = sorted(set(args.issue_pages))
    for output in args.output or []:
        if output not in data["outputs"]:
            data["outputs"].append(output)
    write_state(args.state, data)
    return data


def make_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    init = subparsers.add_parser("init", help="Initialize a metadata-only state file.")
    init.add_argument("--state", type=Path, required=True)
    init.add_argument("--ppt", required=True)
    init.add_argument("--slide-count", type=int, required=True)
    init.add_argument("--target-start", type=int, default=1)
    init.add_argument("--target-end", type=int)
    init.add_argument("--batch-size", type=int, default=5)
    init.add_argument("--confirmed-through", type=int)
    init.add_argument("--notes")
    show = subparsers.add_parser("show", help="Validate and print the current state.")
    show.add_argument("--state", type=Path, required=True)
    update = subparsers.add_parser("update", help="Update validated workflow metadata.")
    update.add_argument("--state", type=Path, required=True)
    update.add_argument("--stage", choices=sorted(STAGES))
    update.add_argument("--confirmed-through", type=int)
    update.add_argument("--batch-start", type=int)
    update.add_argument("--batch-end", type=int)
    update.add_argument("--notes")
    update.add_argument("--audit-status", choices=sorted(AUDIT_STATUSES))
    update.add_argument("--issue-pages", type=int, nargs="*")
    update.add_argument("--output", action="append")
    return parser


def main() -> None:
    args = make_parser().parse_args()
    if args.command == "init":
        data = command_init(args)
    elif args.command == "show":
        data = read_state(args.state)
    else:
        data = command_update(args)
    print(json.dumps(data, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
