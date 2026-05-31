from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from pypdf import PdfReader


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PDF = Path.home() / "Downloads" / "God and Devil World (เชือดซอมบี้พิชิตฮาเร็ม) 1 - 1217 end.pdf"

HEADING_RE = re.compile(r"^\s*บทที่\s*([0-9]{1,4})\s*[:：\-–—]?\s*(.*)$")
THAI_TOKEN_RE = re.compile(r"[\w\u0e00-\u0e7f]+", re.UNICODE)


def count_words(text: str) -> int:
    return len(THAI_TOKEN_RE.findall(text))


def normalize_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n").replace("\u00a0", " ")
    text = text.replace("ต ่า", "ต่ำ")
    text = text.replace("ต ้า", "ต้ำ")
    text = text.replace("ป่ า", "ป่า")
    text = text.replace("รึป่ าว", "รึป่าว")

    # PDF extraction splits sara am and some vowels from consonants.
    for _ in range(3):
        text = re.sub(r"([ก-ฮ])[ \t]+า", r"\1ำ", text)
        text = re.sub(r"([ก-ฮ])ำ[ \t]+([ก-ฮ])", r"\1ำ\2", text)
        text = re.sub(r"([เแโใไ])[ \t]+([ก-ฮ])", r"\1\2", text)
        text = re.sub(r"([ก-ฮ])[ \t]+([ิีึืุูั็่้๊๋์])", r"\1\2", text)
        text = re.sub(r"([ิีึืุูั็่้๊๋์])[ \t]+([ก-ฮ])", r"\1\2", text)

    replacements = {
        "เปิ ด": "เปิด",
        "เปื้ อน": "เปื้อน",
        "ล าบาก": "ลำบาก",
        "ส าหรับ": "สำหรับ",
        "จ านวน": "จำนวน",
        "จ าได้": "จำได้",
        "ก าแพง": "กำแพง",
        "ก าลัง": "กำลัง",
        "ด ารง": "ดำรง",
        "ด า": "ดำ",
        "ท า": "ทำ",
        "น า": "นำ",
        "ต ่า": "ต่ำ",
        "ฝ่ า": "ฝ่า",
        "กระเป๋ า": "กระเป๋า",
        "เสื อ": "เสื้อ",
        "นํ า": "น้ำ",
        "น้า": "น้ำ",
        "ประจ า": "ประจำ",
        "หน้ำ": "หน้า",
        "ศรีษะ": "ศีรษะ",
        "วิญญาน": "วิญญาณ",
        "อย่ามาก": "อย่างมาก",
        "สาวลุม": "สาวรุม",
        "โดนลุม": "โดนรุม",
        "สัปดาห์เหลือ": "สัปดาห์ เหลือ",
        "ซอมบี้! ": "ซอมบี้! ",
    }
    for wrong, right in replacements.items():
        text = text.replace(wrong, right)

    text = re.sub(r"[ \t]{2,}", " ", text)
    text = re.sub(r" *\n *", "\n", text)
    return text.strip()


def format_content(lines: list[str]) -> str:
    paragraphs: list[str] = []
    current: list[str] = []

    for raw in lines:
        line = normalize_text(raw).strip()
        if not line:
            if current:
                paragraphs.append(" ".join(current).strip())
                current = []
            continue
        current.append(line)

    if current:
        paragraphs.append(" ".join(current).strip())

    return "\n\n".join(paragraph for paragraph in paragraphs if paragraph).strip()


def extract(pdf_path: Path, max_chapter: int) -> dict:
    reader = PdfReader(str(pdf_path))
    chapters: list[dict[str, object]] = []
    current_no: int | None = None
    current_title = ""
    current_lines: list[str] = []
    current_page = 0

    def flush() -> None:
        nonlocal current_no, current_title, current_lines, current_page
        if current_no is None:
            return
        content = format_content(current_lines)
        if content:
            chapters.append(
                {
                    "chapter_no": current_no,
                    "title": current_title or f"บทที่ {current_no}",
                    "content": content,
                    "word_count": count_words(content),
                    "source_file": pdf_path.name,
                    "start_page": current_page,
                }
            )
        current_no = None
        current_title = ""
        current_lines = []

    for page_index, page in enumerate(reader.pages, start=1):
        text = normalize_text(page.extract_text() or "")
        for raw_line in text.splitlines():
            line = raw_line.strip()
            match = HEADING_RE.match(line)
            if match:
                chapter_no = int(match.group(1))
                if chapter_no > max_chapter:
                    flush()
                    return build_payload(pdf_path, chapters, max_chapter)
                if 1 <= chapter_no <= max_chapter:
                    flush()
                    current_no = chapter_no
                    current_title = match.group(2).strip(" :-–—") or f"บทที่ {chapter_no}"
                    current_page = page_index
                    current_lines = []
                    continue
            if current_no is not None:
                current_lines.append(line)

    flush()
    return build_payload(pdf_path, chapters, max_chapter)


def build_payload(pdf_path: Path, chapters: list[dict[str, object]], max_chapter: int) -> dict:
    found = {int(chapter["chapter_no"]) for chapter in chapters}
    return {
        "title": "God and Devil World (เชือดซอมบี้พิชิตฮาเร็ม)",
        "source_name": f"{pdf_path.name} chapters 1-{max_chapter}",
        "chapters": chapters,
        "missing_chapters": [number for number in range(1, max_chapter + 1) if number not in found],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pdf", default=str(DEFAULT_PDF))
    parser.add_argument("--out", default=str(ROOT / "ocr_work" / "god_devil_001_010.json"))
    parser.add_argument("--max-chapter", type=int, default=10)
    args = parser.parse_args()

    payload = extract(Path(args.pdf), args.max_chapter)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    chapters = payload["chapters"]
    print(f"chapters={len(chapters)}")
    print(f"missing={payload['missing_chapters']}")
    if chapters:
        print(f"first={chapters[0]['chapter_no']} {chapters[0]['title']}")
        print(f"last={chapters[-1]['chapter_no']} {chapters[-1]['title']}")
    print(f"json={out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
