from __future__ import annotations

import argparse
import json
from pathlib import Path

from tools_extract_lotm_pdf import fix_thai_spacing


def clean_text(text: str) -> str:
    text = fix_thai_spacing(text)
    replacements = {
        "มื้อค่าของสามพี่น้อง": "มื้อค่ำของสามพี่น้อง",
        "ฝึ ก": "ฝึก",
        "ปุ่ ม": "ปุ่ม",
        "เปิ ด": "เปิด",
        "ปิ ด": "ปิด",
        "ฟื้ น": "ฟื้น",
    }
    for wrong, right in replacements.items():
        text = text.replace(wrong, right)
    return text


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_json")
    parser.add_argument("output_json")
    args = parser.parse_args()

    payload = json.loads(Path(args.input_json).read_text(encoding="utf-8"))
    for chapter in payload.get("chapters", []):
        chapter["title"] = clean_text(str(chapter.get("title", ""))).strip()
        chapter["content"] = clean_text(str(chapter.get("content", ""))).strip()

    output = Path(args.output_json)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"chapters={len(payload.get('chapters', []))}")
    print(f"json={output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
