from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PYDEPS = ROOT / "pydeps"
PYTHAINLP_DATA = ROOT / "pythainlp-data"

if str(PYDEPS) not in sys.path:
    sys.path.insert(0, str(PYDEPS))
os.environ.setdefault("PYTHAINLP_DATA_DIR", str(PYTHAINLP_DATA))

from pythainlp.spell import spell  # noqa: E402


THAI_MARKS = "ัิีึืุู็่้๊๋์"
THAI_LEADS = "เแโใไ"
THAI_AFTER_MARK = "ะาำ"

PHRASE_REPLACEMENTS: dict[str, str] = {
    "เสียกเพรียกหา": "เสียงเพรียกหา",
    "พยาม": "พยายาม",
    "ซ้า": "ซ้ำ",
    "ฝี เท้า": "ฝีเท้า",
    "ฝ่ าย": "ฝ่าย",
    "อีกฝ่ าย": "อีกฝ่าย",
    "น้าตาล": "น้ำตาล",
    "น้าเสียง": "น้ำเสียง",
    "น้าค้าง": "น้ำค้าง",
    "น้าฝน": "น้ำฝน",
    "น้าใจ": "น้ำใจ",
    "น้าแข็ง": "น้ำแข็ง",
    "น้าหนัก": "น้ำหนัก",
    "น้าหอม": "น้ำหอม",
    "น้าเน่า": "น้ำเน่า",
    "น้าลาย": "น้ำลาย",
    "ออนหายใจ": "ถอนหายใจ",
    "เช้าร้าน": "เข้าร้าน",
    "มีดมน": "มืดมน",
    "เมื่อง": "เมือง",
    "ลมเหลวงันเหรอ": "ล้มเหลวงั้นเหรอ",
    "ลมเหลว": "ล้มเหลว",
    "งันเหรอ": "งั้นเหรอ",
    "มั่งตั้ง": "มั่งคั่ง",
    "หลุมบ่อตื่น ๆ": "หลุมบ่อตื้น ๆ",
    "โต๊ไม้ะ": "โต๊ะไม้",
    "บรรยกาศ": "บรรยากาศ",
    "สมดล": "สมดุล",
    "พยุ่ง": "พยุง",
    "ต่าถูก": "ต่ำถูก",
    "น้าเข้า": "นำเข้า",
    "ดานประวัติศาสตร์": "ด้านประวัติศาสตร์",
    "ร่ารวย": "ร่ำรวย",
    "กระหน่า": "กระหน่ำ",
    "ฝ่ ามือ": "ฝ่ามือ",
}

# Only apply these when PyThaiNLP also suggests the target, or when the observed
# OCR typo is too uncommon to be a valid Thai word in novel prose.
SPELL_CHECKED_REPLACEMENTS: dict[str, str] = {
    "มีดมน": "มืดมน",
    "ฝ่ าย": "ฝ่าย",
}


def normalize_thai_spacing(text: str) -> str:
    text = text.replace("ํา", "ำ")
    text = text.replace("\u00a0", " ")
    for _ in range(4):
        text = re.sub(rf"([ก-ฮ])[ \t]+([{THAI_MARKS}])", r"\1\2", text)
        text = re.sub(rf"([{THAI_MARKS}])[ \t]+([{THAI_MARKS}{THAI_AFTER_MARK}])", r"\1\2", text)
        text = re.sub(rf"([{THAI_MARKS}])[ \t]+([ก-ฮ{THAI_LEADS}])", r"\1\2", text)
        text = re.sub(rf"([{THAI_LEADS}])[ \t]+([ก-ฮ])", r"\1\2", text)
        text = re.sub(r"([ก-ฮ])[ \t]+ำ", r"\1ำ", text)
    return text


def cleanup_text(text: str, changes: Counter[str]) -> str:
    before = text
    text = normalize_thai_spacing(text)
    if text != before:
        changes["thai_spacing"] += 1

    noun_this_count = len(re.findall(r"(?<=[ก-ฮ])นี้่", text))
    if noun_this_count:
        text = re.sub(r"(?<=[ก-ฮ])นี้่", "นี้", text)
        changes["นี้่_after_word->นี้"] += noun_this_count
    if "นี้่" in text:
        count = text.count("นี้่")
        text = text.replace("นี้่", "นี่")
        changes["นี้่_standalone->นี่"] += count

    for wrong, right in SPELL_CHECKED_REPLACEMENTS.items():
        if wrong not in text:
            continue
        suggestions = spell(wrong)[:10]
        if right in suggestions or wrong in {"ฝ่ าย"}:
            count = text.count(wrong)
            text = text.replace(wrong, right)
            changes[f"{wrong}->{right}"] += count

    for wrong, right in PHRASE_REPLACEMENTS.items():
        if wrong in text:
            count = text.count(wrong)
            text = text.replace(wrong, right)
            changes[f"{wrong}->{right}"] += count

    # Keep punctuation readable without altering sentence meaning.
    text = re.sub(r"\s+([”’!?.,…])", r"\1", text)
    text = re.sub(r"([“‘])\s+", r"\1", text)
    return text


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_json")
    parser.add_argument("output_json")
    parser.add_argument("--report", default="")
    args = parser.parse_args()

    payload = json.loads(Path(args.input_json).read_text(encoding="utf-8"))
    changes: Counter[str] = Counter()
    examples: list[dict] = []

    for chapter in payload.get("chapters", []):
        old_title = str(chapter.get("title", ""))
        old_content = str(chapter.get("content", ""))
        new_title = cleanup_text(old_title, changes)
        new_content = cleanup_text(old_content, changes)
        chapter["title"] = new_title
        chapter["content"] = new_content

        if (old_title, old_content) != (new_title, new_content) and len(examples) < 30:
            examples.append(
                {
                    "chapter_no": chapter.get("chapter_no"),
                    "old_title": old_title,
                    "new_title": new_title,
                    "old_sample": old_content[:240],
                    "new_sample": new_content[:240],
                }
            )

    out = Path(args.output_json)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    report = {
        "input": args.input_json,
        "output": args.output_json,
        "chapters": len(payload.get("chapters", [])),
        "changes": dict(changes.most_common()),
        "examples": examples,
    }
    report_path = Path(args.report) if args.report else out.with_suffix(".report.json")
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"chapters={report['chapters']}")
    print(f"change_kinds={len(report['changes'])}")
    for key, value in changes.most_common(20):
        print(f"{key}: {value}")
    print(f"json={out}")
    print(f"report={report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
