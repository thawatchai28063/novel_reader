from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from pypdf import PdfReader


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PDF = Path.home() / "Downloads" / "God and Devil World (เชือดซอมบี้พิชิตฮาเร็ม) 1 - 1217 end.pdf"

HEADING_RES = [
    re.compile(r"^\s*บทที่\s*([0-9][0-9,]{0,4})\s*[:：\-–—]?\s*(.*)$"),
    re.compile(r"^\s*บทที\s*([0-9][0-9,]{0,4})\s*[:：\-–—]?\s*(.*)$"),
    re.compile(r"^\s*Chapter\s*([0-9][0-9,]{0,4})\s*[:：\-–—]?\s*(.*)$", re.IGNORECASE),
    re.compile(r"^\s*ตอนที่\s*([0-9][0-9,]{0,4})\s*[:：\-–—]?\s*(.*)$"),
    re.compile(r"^\s*ตอนที\s*([0-9][0-9,]{0,4})\s*[:：\-–—]?\s*(.*)$"),
    re.compile(r"^\s*อนที่\s*([0-9][0-9,]{0,4})\s*[:：\-–—]?\s*(.*)$"),
    re.compile(r"^\s*เชือด\s*(?:ซอมบี|ซอมบี่|ซอมบ)?\s*([0-9][0-9,]{0,4})\s*(?:-[0-9][0-9,]{0,4})?\s*[:：\-–—]?\s*(.*)$"),
    re.compile(r"^\s*เชือด\s*บทที่\s*([0-9][0-9,]{0,4})\s*[:：\-–—]?\s*(.*)$"),
]
PAGE_NUMBER_HEADING_RE = re.compile(r"^\s*([0-9][0-9,]{0,4})\s*(?:([:：\-–—])\s*(.*)|\s+(.*))?$")
WEIRD_FIVE_DIGIT_TON_RE = re.compile(r"^\s*ตอนที่\s*1([0-9]{4})\s*[:：\-–—]?\s*(.*)$")
THAI_TOKEN_RE = re.compile(r"[\w\u0e00-\u0e7f]+", re.UNICODE)


def count_words(text: str) -> int:
    return len(THAI_TOKEN_RE.findall(text))


def parse_chapter_no(value: str) -> int:
    return int(value.replace(",", ""))


def normalize_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n").replace("\u00a0", " ").replace("\x00", "")
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


def parse_heading(
    line: str,
    *,
    is_page_first_line: bool,
    current_no: int | None,
) -> tuple[int, str, str] | None:
    weird_ton = WEIRD_FIVE_DIGIT_TON_RE.match(line)
    if weird_ton and current_no is not None:
        chapter_no = int(weird_ton.group(1))
        if chapter_no == current_no + 1:
            return chapter_no, weird_ton.group(2).strip(" :-–—"), ""

    for heading_re in HEADING_RES:
        match = heading_re.match(line)
        if match:
            return parse_chapter_no(match.group(1)), match.group(2).strip(" :-–—"), ""

    # Some later chapters start a new PDF page with only "801" or
    # "801 <first sentence>" instead of a normal "บทที่" heading.
    if is_page_first_line:
        match = PAGE_NUMBER_HEADING_RE.match(line)
        if match:
            chapter_no = parse_chapter_no(match.group(1))
            if current_no is None or chapter_no == current_no + 1:
                separator = match.group(2)
                after_number = (match.group(3) or match.group(4) or "").strip()
                if separator or count_words(after_number) <= 8:
                    return chapter_no, after_number, ""
                return chapter_no, "", after_number

    return None


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
        raw_lines = text.splitlines()
        first_line_index = next((index for index, value in enumerate(raw_lines) if value.strip()), -1)
        skip_lines = 0
        for line_index, raw_line in enumerate(raw_lines):
            if skip_lines:
                skip_lines -= 1
                continue
            line = raw_line.strip()
            if re.fullmatch(r"บทที", line):
                next_line = raw_lines[line_index + 1].strip() if line_index + 1 < len(raw_lines) else ""
                if re.fullmatch(r"[0-9][0-9,]{0,4}", next_line):
                    chapter_no = parse_chapter_no(next_line)
                    title = ""
                    skip_lines = 1
                    maybe_separator = raw_lines[line_index + 2].strip() if line_index + 2 < len(raw_lines) else ""
                    maybe_title = raw_lines[line_index + 3].strip() if line_index + 3 < len(raw_lines) else ""
                    if maybe_separator in {":", "：", "-", "–", "—"} and maybe_title:
                        title = maybe_title
                        skip_lines = 3
                    heading = (chapter_no, title, "")
                else:
                    heading = None
            elif (
                re.fullmatch(r"[0-9][0-9,]{0,4}", line)
                and current_no is not None
                and parse_chapter_no(line) == current_no + 1
            ):
                heading = (parse_chapter_no(line), "", "")
            else:
                heading = None
            if heading is None:
                heading = parse_heading(
                    line,
                    is_page_first_line=line_index == first_line_index,
                    current_no=current_no,
                )
            if heading:
                chapter_no, title, first_content = heading
                if chapter_no > max_chapter:
                    flush()
                    return build_payload(pdf_path, chapters, max_chapter)
                if 1 <= chapter_no <= max_chapter:
                    flush()
                    current_no = chapter_no
                    current_title = title or f"บทที่ {chapter_no}"
                    current_page = page_index
                    current_lines = [first_content] if first_content else []
                    continue
            if current_no is not None:
                current_lines.append(line)

    flush()
    return build_payload(pdf_path, chapters, max_chapter)


def build_payload(pdf_path: Path, chapters: list[dict[str, object]], max_chapter: int) -> dict:
    chapters_by_number: dict[int, dict[str, object]] = {}
    for chapter in chapters:
        chapter_no = int(chapter["chapter_no"])
        existing = chapters_by_number.get(chapter_no)
        if existing is None or int(chapter["word_count"]) > int(existing["word_count"]):
            chapters_by_number[chapter_no] = chapter

    missing_chapters = [number for number in range(1, max_chapter + 1) if number not in chapters_by_number]
    for chapter_no in missing_chapters:
        content = (
            "ไม่พบเนื้อหาตอนนี้ในไฟล์ PDF ต้นฉบับ หรือหัวตอนในไฟล์เสียหายจนแยกออกมาไม่ได้"
        )
        chapters_by_number[chapter_no] = {
            "chapter_no": chapter_no,
            "title": f"บทที่ {chapter_no}",
            "content": content,
            "word_count": count_words(content),
            "source_file": pdf_path.name,
            "start_page": None,
        }

    return {
        "title": "God and Devil World (เชือดซอมบี้พิชิตฮาเร็ม)",
        "source_name": f"{pdf_path.name} chapters 1-{max_chapter}",
        "chapters": [chapters_by_number[number] for number in range(1, max_chapter + 1)],
        "missing_chapters": missing_chapters,
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
