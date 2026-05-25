from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from pypdf import PdfReader


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DOWNLOADS = Path.home() / "Downloads"

PDF_ORDER = [
    "Lord of the Mysteries ราชันย์เร้นลับ 001-100.pdf",
    "Lord of the Mysteries ราชันย์เร้นลับ 101-200.pdf",
    "Lord of the Mysteries ราชันย์เร้นลับ 201-300.pdf",
    "Lord of the Mysteries ราชันย์เร้นลับ 301-310.pdf",
    "Lord of the Mysteries ราชันย์เร้นลับ 311-320.pdf",
    "Lord of the Mysteries ราชันย์เร้นลับ 321-330.pdf",
    "Lord of the Mysteries ราชันย์เร้นลับ 331-340.pdf",
    "Lord of the Mysteries ราชันย์เร้นลับ 341-350.pdf",
    "Lord of the Mysteries ราชันย์เร้นลับ 351-360.pdf",
    "Lord of the Mysteries ราชันย์เร้นลับ 361-370.pdf",
    "Lord of the Mysteries ราชันย์เร้นลับ 371-380.pdf",
    "Lord of the Mysteries ราชันย์เร้นลับ 381-390.pdf",
    "Lord of the Mysteries ราชันย์เร้นลับ 391-400.pdf",
    "Lord of the Mysteries ราชันย์เร้นลับ  385-850.pdf",
]

THAI_TOKEN_RE = re.compile(r"[\w\u0e00-\u0e7f]+", re.UNICODE)
HEADING_RE = re.compile(
    r"^\s*(?:(?:ร?าชัน(?:ย์)?\s*เร้นลับ)\s*|ตอนที่\s*)"
    r"([0-9]{1,4})\s*(?:[:：\-–—]\s*)?(.*)$"
)
TITLE_ONLY_RE = re.compile(r"^\s*ร?าชัน(?:ย์)?\s*เร้นลับ\s*$")
NUMBER_AFTER_TITLE_RE = re.compile(r"^\s*([0-9]{1,4})\s*(?:[:：\-–—]\s*)?(.*)$")
PAGE_NO_RE = re.compile(r"^\s*\d{1,4}\s*$")


def pdf_paths(downloads: Path) -> list[Path]:
    paths: list[Path] = []
    for name in PDF_ORDER:
        path = downloads / name
        if path.exists():
            paths.append(path)
    if paths:
        return paths

    return sorted(downloads.glob("Lord of the Mysteries ราชันย์เร้นลับ*.pdf"))


def fix_thai_spacing(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n").replace("\f", "\n")
    text = text.replace("\u00a0", " ")
    text = text.translate(
        str.maketrans(
            {
                "\uf70a": "่",
                "\uf70b": "้",
                "\uf70c": "๊",
                "\uf70d": "๋",
                "\uf70e": "์",
                "\uf70f": "ํ",
                "\uf712": "็",
            }
        )
    )

    # PDF text extraction sometimes inserts spaces between Thai consonants and marks.
    for _ in range(4):
        text = re.sub(r"([ก-ฮ])\s+([ัิีึืุู็่้๊๋์])", r"\1\2", text)
        text = re.sub(r"([เแโใไ])\s+([ก-ฮ])", r"\1\2", text)
        text = re.sub(r"([ก-ฮ])\s+ำ", r"\1ำ", text)
        text = re.sub(r"([ัิีึืุู็่้๊๋์])\s+([่้๊๋์])", r"\1\2", text)
        text = re.sub(r"([ัิีึืุู็่้๊๋์])\s+([ก-ฮ])", r"\1\2", text)

    phrase_fixes = {
        "ก า": "กำ",
        "ข า": "ขำ",
        "ค า": "คำ",
        "จ า": "จำ",
        "ช า": "ชำ",
        "ด า": "ดำ",
        "ต า": "ตำ",
        "ท า": "ทำ",
        "น า": "นำ",
        "บ า": "บำ",
        "ป า": "ปำ",
        "ผ า": "ผำ",
        "ฝ า": "ฝำ",
        "พ า": "พำ",
        "ฟ า": "ฟำ",
        "ภ า": "ภำ",
        "ม า": "มำ",
        "ย า": "ยำ",
        "ร า": "รำ",
        "ล า": "ลำ",
        "ว า": "วำ",
        "ส า": "สำ",
        "ห า": "หำ",
        "อ า": "อำ",
        "ฮ า": "ฮำ",
        "เป ็ น": "เป็น",
        "เป ่า": "เป่า",
        "เป ี่ ยม": "เปี่ยม",
        "เส ียง": "เสียง",
        "เร ียบ": "เรียบ",
        "เร ื่อง": "เรื่อง",
        "เด ียว": "เดียว",
        "เก ี่ ยว": "เกี่ยว",
        "เคร ื่อง": "เครื่อง",
        "ฝ ื น": "ฝืน",
        "พ ื้น": "พื้น",
        "ม ือ": "มือ",
        "ร ู้": "รู้",
        "อย ู่": "อยู่",
        "หน ึ่ง": "หนึ่ง",
    }
    for wrong, right in phrase_fixes.items():
        text = text.replace(wrong, right)

    text = re.sub(r"[ \t]{2,}", " ", text)
    text = re.sub(r" *\n *", "\n", text)
    return text.strip()


def cleanup_line(line: str) -> str:
    line = fix_thai_spacing(line).strip()
    if not line:
        return ""
    if PAGE_NO_RE.match(line):
        return ""
    if "novel" in line.lower() and len(line) < 80:
        return ""
    return line


def count_words(text: str) -> int:
    return len(THAI_TOKEN_RE.findall(text))


def format_content(lines: list[str]) -> str:
    paragraphs: list[str] = []
    current: list[str] = []

    for line in lines:
        clean = cleanup_line(line)
        if not clean:
            if current:
                paragraphs.append("".join(current).strip())
                current = []
            continue
        current.append(clean)

    if current:
        paragraphs.append("".join(current).strip())

    return "\n\n".join(paragraph for paragraph in paragraphs if paragraph).strip()


def iter_pdf_lines(path: Path):
    reader = PdfReader(str(path))
    for page_no, page in enumerate(reader.pages, start=1):
        text = page.extract_text() or ""
        for line in fix_thai_spacing(text).splitlines():
            yield page_no, line


def extract(downloads: Path, max_chapter: int) -> dict:
    chapters_by_no: dict[int, dict] = {}
    duplicates: list[int] = []

    current_no: int | None = None
    current_title = ""
    current_lines: list[str] = []
    current_source = ""
    current_page = 0
    pending_title_only = False

    def flush() -> None:
        nonlocal current_no, current_title, current_lines, current_source, current_page
        if current_no is None:
            return
        content = format_content(current_lines)
        if not content:
            current_no = None
            current_title = ""
            current_lines = []
            return
        chapter = {
            "chapter_no": current_no,
            "title": current_title or f"ตอนที่ {current_no}",
            "content": content,
            "word_count": count_words(content),
            "source_file": current_source,
            "start_page": current_page,
        }
        if current_no in chapters_by_no:
            duplicates.append(current_no)
        else:
            chapters_by_no[current_no] = chapter
        current_no = None
        current_title = ""
        current_lines = []

    for path in pdf_paths(downloads):
        for page_no, raw_line in iter_pdf_lines(path):
            line = cleanup_line(raw_line)
            if not line:
                current_lines.append("")
                continue

            if TITLE_ONLY_RE.match(line):
                pending_title_only = True
                continue

            match = HEADING_RE.match(line)
            if pending_title_only and not match:
                match = NUMBER_AFTER_TITLE_RE.match(line)
            if match:
                chapter_no = int(match.group(1))
                if 1 <= chapter_no <= max_chapter:
                    flush()
                    current_no = chapter_no
                    current_title = (match.group(2).strip(" :-–—") or f"ตอนที่ {chapter_no}")[:255]
                    current_source = path.name
                    current_page = page_no
                    current_lines = []
                    pending_title_only = False
                    continue
            pending_title_only = False

            if current_no is not None:
                current_lines.append(line)

        flush()

    chapters = [chapters_by_no[key] for key in sorted(chapters_by_no)]
    found = {chapter["chapter_no"] for chapter in chapters}
    missing = [no for no in range(1, max_chapter + 1) if no not in found]

    return {
        "title": "ราชันย์เร้นลับ",
        "source_name": "Lord of the Mysteries ราชันย์เร้นลับ PDF text layer",
        "chapters": chapters,
        "missing_chapters": missing,
        "duplicate_chapters": sorted(set(duplicates)),
        "pdf_files": [path.name for path in pdf_paths(downloads)],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--downloads", default=str(DEFAULT_DOWNLOADS))
    parser.add_argument("--out", default=str(ROOT / "ocr_work" / "lord_of_mysteries_pdf_text.json"))
    parser.add_argument("--max-chapter", type=int, default=850)
    args = parser.parse_args()

    result = extract(Path(args.downloads), args.max_chapter)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")

    chapters = result["chapters"]
    print(f"files={len(result['pdf_files'])}")
    print(f"chapters={len(chapters)}")
    print(f"first={chapters[0]['chapter_no'] if chapters else '-'}")
    print(f"last={chapters[-1]['chapter_no'] if chapters else '-'}")
    print(f"missing={result['missing_chapters'][:50]}")
    print(f"duplicates={result['duplicate_chapters'][:50]}")
    print(f"json={out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
