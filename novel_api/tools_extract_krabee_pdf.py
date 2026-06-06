from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from pypdf import PdfReader


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SIZE = 6_431_606
TITLE = "กระบี่จงมา! ภาค 1 นกกระจอกในกรง"
COVER_PATH = "covers/krabee_jong_ma.jpg"
HEADING_RE = re.compile(r"^\s*บทที่\s*([0-9]{1,3})\s+(.+)$")
THAI_TOKEN_RE = re.compile(r"[\w\u0e00-\u0e7f]+", re.UNICODE)


def find_default_pdf() -> Path:
    downloads = Path.home() / "Downloads"
    for pdf_path in downloads.glob("*.pdf"):
        if pdf_path.stat().st_size == DEFAULT_SIZE:
            return pdf_path
    raise FileNotFoundError("Cannot find กระบี่จงมา PDF in Downloads")


def count_words(text: str) -> int:
    return len(THAI_TOKEN_RE.findall(text))


def normalize_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n").replace("\u00a0", " ")
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


def extract_cover(pdf_path: Path, cover_path: Path) -> None:
    reader = PdfReader(str(pdf_path))
    images = list(reader.pages[0].images)
    if not images:
        raise RuntimeError("No images found on first PDF page")
    portrait_images = [
        image
        for image in images
        if getattr(getattr(image, "image", None), "size", (0, 0))[1]
        >= getattr(getattr(image, "image", None), "size", (0, 0))[0]
    ]
    image = max(portrait_images or images, key=lambda item: len(item.data))
    cover_path.parent.mkdir(parents=True, exist_ok=True)
    cover_path.write_bytes(image.data)


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
                    "title": current_title,
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
                    current_title = match.group(2).strip()
                    current_page = page_index
                    current_lines = []
                    continue
            if current_no is not None:
                current_lines.append(line)

    flush()
    return build_payload(pdf_path, chapters, max_chapter)


def build_payload(pdf_path: Path, chapters: list[dict[str, object]], max_chapter: int) -> dict:
    chapters_by_number = {int(chapter["chapter_no"]): chapter for chapter in chapters}
    found_numbers = sorted(chapters_by_number)
    missing = [number for number in range(1, max_chapter + 1) if number not in chapters_by_number]

    return {
        "title": TITLE,
        "source_name": f"{pdf_path.name} chapters {found_numbers[0]}-{found_numbers[-1]}" if found_numbers else pdf_path.name,
        "cover_path": COVER_PATH,
        "chapters": [chapters_by_number[number] for number in found_numbers],
        "missing_chapters": missing,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pdf", default="")
    parser.add_argument("--out", default=str(ROOT / "ocr_work" / "krabee_jong_ma_001_084.json"))
    parser.add_argument("--cover-out", default=str(ROOT / "novel_api" / COVER_PATH))
    parser.add_argument("--max-chapter", type=int, default=84)
    parser.add_argument("--skip-cover", action="store_true")
    args = parser.parse_args()

    pdf_path = Path(args.pdf) if args.pdf else find_default_pdf()
    payload = extract(pdf_path, args.max_chapter)
    if not args.skip_cover:
        extract_cover(pdf_path, Path(args.cover_out))

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
    print(f"cover={args.cover_out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
