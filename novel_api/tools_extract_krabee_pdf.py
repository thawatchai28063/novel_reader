from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from pypdf import PdfReader


ROOT = Path(__file__).resolve().parent.parent
TITLE = "กระบี่จงมา! ภาค 1 นกกระจอกในกรง"
COVER_PATH = "covers/krabee_jong_ma.jpg"
HEADING_RE = re.compile(r"^\s*บทที่\s*([0-9]{1,4})(?:\.([0-9]+))?\s+(.+)$")
THAI_TOKEN_RE = re.compile(r"[\w\u0e00-\u0e7f]+", re.UNICODE)


def part_sort_key(path: Path) -> tuple[int, str]:
    return (part_number_from_name(path.name) or 999, path.name)


def part_number_from_name(name: str) -> int | None:
    match = re.search(r"([0-9]+)", Path(name).stem)
    return int(match.group(1)) if match else None


def title_with_volume(source_file: object, title: object) -> str:
    volume_no = part_number_from_name(str(source_file))
    clean_title = str(title).strip()
    if volume_no is None:
        return clean_title
    return f"\u0e20\u0e32\u0e04 {volume_no} - {clean_title}"


def find_default_pdfs() -> list[Path]:
    downloads = Path.home() / "Downloads"
    pdfs = sorted(downloads.glob("กระบี่จงมา! ภาค *.pdf"), key=part_sort_key)
    if not pdfs:
        raise FileNotFoundError("Cannot find กระบี่จงมา! ภาค *.pdf in Downloads")
    return pdfs


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


def extract_parts(pdf_path: Path, max_chapter: int) -> list[dict[str, object]]:
    reader = PdfReader(str(pdf_path))
    parts: list[dict[str, object]] = []
    current_no: int | None = None
    current_part = ""
    current_title = ""
    current_lines: list[str] = []
    current_page = 0

    def flush() -> None:
        nonlocal current_no, current_part, current_title, current_lines, current_page
        if current_no is None:
            return
        content = format_content(current_lines)
        if content:
            parts.append(
                {
                    "chapter_no": current_no,
                    "chapter_part": current_part,
                    "title": current_title,
                    "content": content,
                    "word_count": count_words(content),
                    "source_file": pdf_path.name,
                    "start_page": current_page,
                }
            )
        current_no = None
        current_part = ""
        current_title = ""
        current_lines = []

    for page_index, page in enumerate(reader.pages, start=1):
        text = normalize_text(page.extract_text() or "")
        for raw_line in text.splitlines():
            line = raw_line.strip()
            match = HEADING_RE.match(line)
            if match:
                chapter_no = int(match.group(1))
                if max_chapter > 0 and chapter_no > max_chapter:
                    flush()
                    return parts
                if chapter_no >= 1 and (max_chapter <= 0 or chapter_no <= max_chapter):
                    flush()
                    current_no = chapter_no
                    current_part = match.group(2) or ""
                    current_title = match.group(3).strip()
                    current_page = page_index
                    current_lines = []
                    continue
            if current_no is not None:
                current_lines.append(line)

    flush()
    return parts


def merge_parts(parts: list[dict[str, object]]) -> list[dict[str, object]]:
    merged: dict[int, dict[str, object]] = {}
    part_counts: dict[int, int] = {}

    sorted_parts = sorted(
        parts,
        key=lambda item: (
            int(item["chapter_no"]),
            int(item["chapter_part"] or 0),
            int(item["start_page"]),
        ),
    )

    for part in sorted_parts:
        chapter_no = int(part["chapter_no"])
        part_counts[chapter_no] = part_counts.get(chapter_no, 0) + 1

        if chapter_no not in merged:
            merged[chapter_no] = {
                "chapter_no": chapter_no,
                "title": title_with_volume(part["source_file"], part["title"]),
                "content_parts": [],
                "word_count": 0,
                "source_file": part["source_file"],
                "start_page": part["start_page"],
            }

        item = merged[chapter_no]
        content = str(part["content"])
        chapter_part = str(part.get("chapter_part", ""))
        if chapter_part:
            label = f"บทที่ {chapter_no}.{chapter_part} {part['title']}"
            content = f"{label}\n\n{content}"

        item["content_parts"].append(content)
        item["word_count"] = int(item["word_count"]) + int(part["word_count"])

    chapters: list[dict[str, object]] = []
    for chapter_no in sorted(merged):
        item = merged[chapter_no]
        chapters.append(
            {
                "chapter_no": chapter_no,
                "title": item["title"],
                "content": "\n\n".join(str(part) for part in item["content_parts"]).strip(),
                "word_count": item["word_count"],
                "source_file": item["source_file"],
                "start_page": item["start_page"],
                "part_count": part_counts.get(chapter_no, 1),
            }
        )
    return chapters


def build_payload(pdf_paths: list[Path], chapters: list[dict[str, object]], max_chapter: int) -> dict:
    chapters_by_number = {int(chapter["chapter_no"]): chapter for chapter in chapters}
    found_numbers = sorted(chapters_by_number)
    last_chapter = max_chapter if max_chapter > 0 else (found_numbers[-1] if found_numbers else 0)
    missing = [number for number in range(1, last_chapter + 1) if number not in chapters_by_number]

    return {
        "title": TITLE,
        "source_name": (
            f"{pdf_paths[0].name} - {pdf_paths[-1].name} chapters {found_numbers[0]}-{found_numbers[-1]}"
            if found_numbers
            else ", ".join(path.name for path in pdf_paths)
        ),
        "cover_path": COVER_PATH,
        "chapters": [chapters_by_number[number] for number in found_numbers],
        "missing_chapters": missing,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pdf", action="append", default=[])
    parser.add_argument("--out", default=str(ROOT / "ocr_work" / "krabee_jong_ma_all.json"))
    parser.add_argument("--cover-out", default=str(ROOT / "novel_api" / COVER_PATH))
    parser.add_argument("--max-chapter", type=int, default=0)
    parser.add_argument("--skip-cover", action="store_true")
    args = parser.parse_args()

    pdf_paths = [Path(path) for path in args.pdf] if args.pdf else find_default_pdfs()
    parts: list[dict[str, object]] = []
    for pdf_path in pdf_paths:
        parts.extend(extract_parts(pdf_path, args.max_chapter))

    chapters = merge_parts(parts)
    payload = build_payload(pdf_paths, chapters, args.max_chapter)
    if not args.skip_cover:
        extract_cover(pdf_paths[0], Path(args.cover_out))

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"chapters={len(chapters)}")
    print(f"missing={payload['missing_chapters']}")
    print(f"pdfs={len(pdf_paths)}")
    if chapters:
        print(f"first={chapters[0]['chapter_no']} {chapters[0]['title']}")
        print(f"last={chapters[-1]['chapter_no']} {chapters[-1]['title']}")
    print(f"json={out}")
    print(f"cover={args.cover_out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
