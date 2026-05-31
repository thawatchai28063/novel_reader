from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path


def count_words(text: str) -> int:
    return len(re.findall(r"[\w\u0e00-\u0e7f]+", text, re.UNICODE))


PHRASE_REPLACEMENTS: list[tuple[str, str]] = [
    ("โดยInk Stone_Fantasy", ""),
    ("Ink Stone_Fantasy", ""),
    ("คํา", "คำ"),
    ("ทํา", "ทำ"),
    ("ตํา", "ตำ"),
    ("จํา", "จำ"),
    ("นํา", "นำ"),
    ("กํา", "กำ"),
    ("สํา", "สำ"),
    ("ดํา", "ดำ"),
    ("เรืองราว", "เรื่องราว"),
    ("เครือง", "เครื่อง"),
    ("เบือง", "เบื้อง"),
    ("เนือง", "เนื่อง"),
    ("ซึง", "ซึ่ง"),
    ("เพิม", "เพิ่ม"),
    ("เมือ", "เมื่อ"),
    ("เริม", "เริ่ม"),
    ("เรือย", "เรื่อย"),
    ("เกียว", "เกี่ยว"),
    ("ชือ", "ชื่อ"),
    ("ชื่อทีซ่อน", "ชื่อที่ซ่อน"),
    ("ทีซ่อน", "ที่ซ่อน"),
    ("เปลียน", "เปลี่ยน"),
    ("สิง", "สิ่ง"),
    ("สิ่งหาคม", "สิงหาคม"),
    ("เมื่อง", "เมือง"),
    ("เนือหา", "เนื้อหา"),
    ("ขันบันได", "ขั้นบันได"),
    ("เสียงชีวิต", "เสี่ยงชีวิต"),
    ("เสียงตาย", "เสี่ยงตาย"),
    ("ตังแต่", "ตั้งแต่"),
    ("ตังใจ", "ตั้งใจ"),
    ("ตังตัว", "ตั้งตัว"),
    ("พืน", "พื้น"),
    ("ขึน", "ขึ้น"),
    ("ยิม", "ยิ้ม"),
    ("ครึม", "ครึ้ม"),
    ("ปลัง", "ปลั่ง"),
    ("รำรวย", "ร่ำรวย"),
    ("ชีนำ", "ชี้นำ"),
    ("คำชีนำ", "คำชี้นำ"),
    ("คำชีแนะ", "คำชี้แนะ"),
    ("นำเสียง", "น้ำเสียง"),
    ("นำตา", "น้ำตา"),
    ("นำหนัก", "น้ำหนัก"),
    ("นำชา", "น้ำชา"),
    ("นำมัน", "น้ำมัน"),
    ("นำแข็ง", "น้ำแข็ง"),
    ("นำลาย", "น้ำลาย"),
]


REGEX_REPLACEMENTS: list[tuple[re.Pattern[str], str, str]] = [
    (re.compile(r"([ก-ฮ])ํา"), r"\1ำ", "nikhahit_sara_am"),
    (re.compile(r"([ก-ฮ])ี\s*ยงชีวิต"), r"\1ี่ยงชีวิต", "เสี่ยงชีวิต"),
    (re.compile(r"([ก-ฮ])ี\s*ยงตาย"), r"\1ี่ยงตาย", "เสี่ยงตาย"),
    (re.compile(r"เรื\s*อง"), "เรื่อง", "เรื่อง"),
    (re.compile(r"เครื\s*อง"), "เครื่อง", "เครื่อง"),
    (re.compile(r"เบื\s*อง"), "เบื้อง", "เบื้อง"),
    (re.compile(r"เนื\s*อง"), "เนื่อง", "เนื่อง"),
    (re.compile(r"ซึ\s*ง"), "ซึ่ง", "ซึ่ง"),
    (re.compile(r"(?<![ก-ฮ])ที(?=[\s,.;:!?\"'“”])"), "ที่", "ที->ที่"),
    (re.compile(r"ที(?=ไม่|เกิด|พบ|ถูก|ได้|จะ|มี|เป็น|อยู่|เห็น|ต้อง|สามารถ|สุด|แท้|เกี่ยว|เรียก|ผ่าน|น่า|ควร|เรา|เขา|มัน)"), "ที่", "ที->ที่ before common word"),
    (re.compile(r"ตั\s*ง(?=แต่|ใจ|ตัว|คำ|มั่น|อยู่|อยู|โต๊ะ|ขึ้น|ขึน|ฉาก|หลัก)"), "ตั้ง", "ตั้ง"),
    (re.compile(r"พื\s*น"), "พื้น", "พื้น"),
    (re.compile(r"ขึ\s*น"), "ขึ้น", "ขึ้น"),
    (re.compile(r"ยิ\s*ม"), "ยิ้ม", "ยิ้ม"),
    (re.compile(r"ครึ\s*ม"), "ครึ้ม", "ครึ้ม"),
    (re.compile(r"ชี\s*นำ"), "ชี้นำ", "ชี้นำ"),
    (re.compile(r"เพิ\s*ม"), "เพิ่ม", "เพิ่ม"),
    (re.compile(r"ร[ํำ]\s*า"), "ร่ำ", "ร่ำ"),
    (re.compile(r"\n{3,}"), "\n\n", "paragraph_breaks"),
    (re.compile(r"[ \t]{2,}"), " ", "spaces"),
]


def fix_lotm_text(text: str, changes: Counter[str]) -> str:
    fixed = text.replace("\r\n", "\n").replace("\r", "\n").replace(chr(0), "")

    for wrong, right in PHRASE_REPLACEMENTS:
        if wrong in fixed:
            count = fixed.count(wrong)
            fixed = fixed.replace(wrong, right)
            changes[f"{wrong}->{right}"] += count

    for pattern, replacement, label in REGEX_REPLACEMENTS:
        fixed, count = pattern.subn(replacement, fixed)
        if count:
            changes[label] += count

    fixed, count = re.subn(r"(?m)^\s*โดย\s*$", "", fixed)
    if count:
        changes["standalone_byline_removed"] += count
    fixed = re.sub(r"\n{3,}", "\n\n", fixed)
    return fixed.strip()


def promote_embedded_title(chapter_no: int, title: str, content: str) -> tuple[str, str]:
    if title != f"ตอนที่ {chapter_no}":
        return title, content

    parts = [part.strip() for part in content.split("\n\n") if part.strip()]
    if len(parts) < 2:
        return title, content

    candidate = parts[0]
    if len(candidate) > 80 or re.search(r"[.!?。！？]$", candidate):
        return title, content
    if len(re.findall(r"[ก-ฮ]", candidate)) < 3:
        return title, content

    return candidate, "\n\n".join(parts[1:]).strip()


def prepare(first_json: Path, source_json: Path, out_json: Path, report_json: Path) -> int:
    first = json.loads(first_json.read_text(encoding="utf-8"))
    source = json.loads(source_json.read_text(encoding="utf-8"))
    by_no: dict[int, dict] = {}
    changes: Counter[str] = Counter()
    examples: list[dict[str, object]] = []

    for chapter in source.get("chapters", []):
        chapter_no = int(chapter.get("chapter_no", 0))
        if chapter_no <= 0:
            continue
        new_chapter = dict(chapter)
        old_title = str(new_chapter.get("title", ""))
        old_content = str(new_chapter.get("content", ""))
        new_title = fix_lotm_text(old_title, changes)
        new_content = fix_lotm_text(old_content, changes)
        promoted_title, promoted_content = promote_embedded_title(chapter_no, new_title or f"ตอนที่ {chapter_no}", new_content)
        if promoted_title != new_title:
            changes["embedded_title_promoted"] += 1
            new_title = promoted_title
            new_content = promoted_content
        if new_title.endswith("โดย"):
            new_title = new_title[:-3].strip()
            changes["title_trailing_byline_removed"] += 1
        new_chapter["title"] = new_title or f"ตอนที่ {chapter_no}"
        new_chapter["content"] = new_content
        new_chapter["word_count"] = count_words(new_content)
        by_no[chapter_no] = new_chapter
        if (old_title, old_content) != (new_title, new_content) and len(examples) < 40:
            examples.append(
                {
                    "chapter_no": chapter_no,
                    "old_title": old_title,
                    "new_title": new_title,
                    "old_sample": old_content[:220],
                    "new_sample": new_content[:220],
                }
            )

    # Keep the already-reviewed first 100 chapters from the database export.
    for chapter in first.get("chapters", []):
        chapter_no = int(chapter.get("chapter_no", 0))
        if 1 <= chapter_no <= 100:
            by_no[chapter_no] = dict(chapter)

    chapters = [by_no[number] for number in sorted(by_no)]
    missing = [number for number in range(1, 851) if number not in by_no]
    payload = {
        "title": first.get("title") or source.get("title") or "ราชันย์เร้นลับ",
        "source_name": "Lord of the Mysteries PDF text + OCR, chapters 1-850",
        "chapters": chapters,
        "missing_chapters": missing,
    }
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    report = {
        "first_json": str(first_json),
        "source_json": str(source_json),
        "output_json": str(out_json),
        "chapters": len(chapters),
        "missing_chapters": missing,
        "changes": dict(changes.most_common()),
        "examples": examples,
    }
    report_json.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"chapters={len(chapters)}")
    print(f"missing_count={len(missing)}")
    print(f"missing={missing}")
    for key, value in changes.most_common(25):
        print(f"{key}: {value}")
    print(f"json={out_json}")
    print(f"report={report_json}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--first-json", default="ocr_work/db_lotm_refined.json")
    parser.add_argument("--source-json", default="ocr_work/lord_of_mysteries_merged.json")
    parser.add_argument("--out", default="ocr_work/lotm_001_850_prepared.json")
    parser.add_argument("--report", default="ocr_work/lotm_001_850_prepared.report.json")
    args = parser.parse_args()

    return prepare(
        Path(args.first_json),
        Path(args.source_json),
        Path(args.out),
        Path(args.report),
    )


if __name__ == "__main__":
    raise SystemExit(main())
