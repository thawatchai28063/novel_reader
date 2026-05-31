from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from pypdf import PdfReader


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SIZES = {6_342_907, 7_434_782, 6_661_717}
TITLE = "คนอื่นเขาฝึกยุทธกันแทบตาย แต่ฉันแค่ปลูกผักก็เก่งได้"
HEADING_RE = re.compile(r"^\s*บทที่\s*([0-9]{1,3})\s*[:：]?\s*(.*)$")
THAI_TOKEN_RE = re.compile(r"[\w\u0e00-\u0e7f]+", re.UNICODE)


def find_default_pdfs() -> list[Path]:
    downloads = Path.home() / "Downloads"
    pdf_paths = [
        pdf_path
        for pdf_path in downloads.glob("*.pdf")
        if pdf_path.stat().st_size in DEFAULT_SIZES
    ]
    if not pdf_paths:
        raise FileNotFoundError("Cannot find farming novel PDFs in Downloads")

    def sort_key(pdf_path: Path) -> int:
        match = re.search(r"Ep\.?\s*([0-9]{1,3})", pdf_path.name, re.IGNORECASE)
        return int(match.group(1)) if match else 9999

    return sorted(pdf_paths, key=sort_key)


def count_words(text: str) -> int:
    return len(THAI_TOKEN_RE.findall(text))


def normalize_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n").replace("\u00a0", " ")
    text = text.replace("ฟื ้ น", "ฟื้น")
    text = text.replace("ทําฟาร์ม", "ทำฟาร์ม")
    text = text.replace("ทํา", "ทำ")
    text = text.replace("น�า", "น้ำ")
    text = text.replace("ซ�า", "ซ้ำ")
    text = text.replace("ร�า", "ร่ำ")
    text = text.replace("กําลัง", "กำลัง")
    text = text.replace("ลําบาก", "ลำบาก")
    text = text.replace("ตํา", "ตำ")
    text = text.replace("สําหรับ", "สำหรับ")
    text = text.replace("สําเร็จ", "สำเร็จ")
    text = text.replace("จํา", "จำ")
    text = text.replace("กํา", "กำ")

    for _ in range(3):
        text = re.sub(r"([ก-ฮ])[ \t]+า", r"\1ำ", text)
        text = re.sub(r"([เแโใไ])[ \t]+([ก-ฮ])", r"\1\2", text)
        text = re.sub(r"([ก-ฮ])[ \t]+([ิีึืุูั็่้๊๋์])", r"\1\2", text)
        text = re.sub(r"([ิีึืุูั็่้๊๋์])[ \t]+([ก-ฮ])", r"\1\2", text)

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
                if 0 <= chapter_no <= max_chapter:
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


def build_payload(pdf_path: Path | list[Path], chapters: list[dict[str, object]], max_chapter: int) -> dict:
    chapters_by_number = {int(chapter["chapter_no"]): chapter for chapter in chapters}
    found_numbers = sorted(chapters_by_number)
    missing = [number for number in range(0, max_chapter + 1) if number not in chapters_by_number]
    pdf_paths = pdf_path if isinstance(pdf_path, list) else [pdf_path]
    source_name = ", ".join(path.name for path in pdf_paths)

    return {
        "title": TITLE,
        "source_name": f"{source_name} chapters {found_numbers[0]}-{found_numbers[-1]}" if found_numbers else source_name,
        "cover_path": "covers/farming_novel.jpg",
        "chapters": [chapters_by_number[number] for number in found_numbers],
        "missing_chapters": missing,
    }


def extract_many(pdf_paths: list[Path], max_chapter: int) -> dict:
    chapters_by_number: dict[int, dict[str, object]] = {}
    for pdf_path in pdf_paths:
        payload = extract(pdf_path, max_chapter)
        for chapter in payload["chapters"]:
            chapter_no = int(chapter["chapter_no"])
            existing = chapters_by_number.get(chapter_no)
            if existing is None or int(chapter["word_count"]) > int(existing["word_count"]):
                chapters_by_number[chapter_no] = chapter

    return build_payload(pdf_paths, list(chapters_by_number.values()), max_chapter)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pdf", action="append", default=[])
    parser.add_argument("--out", default=str(ROOT / "ocr_work" / "farming_000_200.json"))
    parser.add_argument("--max-chapter", type=int, default=600)
    args = parser.parse_args()

    pdf_paths = [Path(path) for path in args.pdf] if args.pdf else find_default_pdfs()
    payload = extract_many(pdf_paths, args.max_chapter)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    chapters = payload["chapters"]
    print(f"chapters={len(chapters)}")
    print(f"missing={payload['missing_chapters'][:60]}")
    print(f"missing_count={len(payload['missing_chapters'])}")
    if chapters:
        print(f"first={chapters[0]['chapter_no']} {chapters[0]['title']}")
        print(f"last={chapters[-1]['chapter_no']} {chapters[-1]['title']}")
    print(f"json={out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
