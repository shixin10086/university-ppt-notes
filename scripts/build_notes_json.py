#!/usr/bin/env python3
"""Convert cumulative Markdown notes into notes-only JSON for PPT injection."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


PAGE_RE = re.compile(r"^## P(\d+)\s+(.+?)\s*$", re.M)
LABEL_RE = re.compile(r"^【([^】]+)】\s*$", re.M)


def parse_markdown(path: Path) -> list[dict]:
    raw = path.read_text(encoding="utf-8")
    pages = []
    page_matches = list(PAGE_RE.finditer(raw))
    for index, match in enumerate(page_matches):
        start = match.end()
        end = page_matches[index + 1].start() if index + 1 < len(page_matches) else len(raw)
        section = raw[start:end]
        blocks = []
        label_matches = list(LABEL_RE.finditer(section))
        for block_index, label_match in enumerate(label_matches):
            block_start = label_match.end()
            block_end = label_matches[block_index + 1].start() if block_index + 1 < len(label_matches) else len(section)
            text = section[block_start:block_end].strip()
            text = re.sub(r"\n\s*---\s*$", "", text).strip()
            if text:
                blocks.append(f"【{label_match.group(1)}】\n{text}")
        pages.append({"slide": int(match.group(1)), "notes": "\n\n".join(blocks)})
    return pages


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    pages = parse_markdown(args.input)
    if not pages:
        raise SystemExit("No slide headings found. Expected headings such as '## P01 标题'.")
    expected = list(range(1, len(pages) + 1))
    actual = [item["slide"] for item in pages]
    if actual != expected:
        raise SystemExit(f"Slide numbers must be continuous from 1. Found: {actual}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(pages, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"slides": len(pages), "output": str(args.output)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
