from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_json")
    parser.add_argument("output_json")
    parser.add_argument("--start", type=int, default=1)
    parser.add_argument("--end", type=int, required=True)
    args = parser.parse_args()

    source = json.loads(Path(args.input_json).read_text(encoding="utf-8"))
    chapters = [
        chapter
        for chapter in source.get("chapters", [])
        if args.start <= int(chapter.get("chapter_no", 0)) <= args.end
    ]
    found = {int(chapter["chapter_no"]) for chapter in chapters}
    missing = [number for number in range(args.start, args.end + 1) if number not in found]

    payload = {
        "title": source.get("title", "ราชันย์เร้นลับ"),
        "source_name": f"{source.get('source_name', 'PDF')} chapters {args.start}-{args.end}",
        "chapters": chapters,
        "missing_chapters": missing,
    }

    output = Path(args.output_json)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"chapters={len(chapters)}")
    print(f"missing={missing}")
    print(f"json={output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
