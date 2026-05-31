from __future__ import annotations

import argparse
import hashlib
import json
import re
import time
from pathlib import Path
from typing import Any

from deep_translator import GoogleTranslator
from pypdf import PdfReader


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SOURCE = Path.home() / "Downloads" / "Nihonkoku shoukan"
TITLE = "Nihonkoku Shoukan อัญเชิญญี่ปุ่นไปต่างโลก"
COVER_PATH = "covers/nihonkoku_shoukan.jpg"
TOKEN_RE = re.compile(r"[\w\u0e00-\u0e7f]+", re.UNICODE)


def count_words(text: str) -> int:
    return len(TOKEN_RE.findall(text))


def normalize_english(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n").replace("\u00a0", " ")
    text = re.sub(r"([A-Za-z])-\n([A-Za-z])", r"\1\2", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r" *\n *", "\n", text)
    return text.strip()


def page_paragraphs(text: str) -> list[str]:
    text = normalize_english(text)
    if not text:
        return []

    paragraphs: list[str] = []
    current: list[str] = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            if current:
                paragraphs.append(" ".join(current).strip())
                current = []
            continue
        current.append(line)

    if current:
        paragraphs.append(" ".join(current).strip())

    return [paragraph for paragraph in paragraphs if paragraph]


def volume_label(path: Path) -> str:
    name = path.stem
    gaiden = re.search(r"Gaiden[_\s-]*([0-9]+)", name, re.IGNORECASE)
    if gaiden:
        return f"ภาคเสริม {int(gaiden.group(1))}"

    volume = re.search(r"_([0-9]+)$", name)
    if volume:
        return f"เล่ม {int(volume.group(1))}"

    return name


def source_pdfs(source_dir: Path) -> list[Path]:
    return sorted(
        source_dir.glob("*.pdf"),
        key=lambda path: (
            1 if "Gaiden" in path.name else 0,
            path.name,
        ),
    )


def split_into_source_chapters(pdf_paths: list[Path], pages_per_chapter: int) -> list[dict[str, Any]]:
    chapters: list[dict[str, Any]] = []
    chapter_no = 1

    for pdf_path in pdf_paths:
        reader = PdfReader(str(pdf_path))
        label = volume_label(pdf_path)
        bucket: list[str] = []
        start_page: int | None = None
        last_page = 0
        text_page_count = 0
        part_no = 1

        def flush() -> None:
            nonlocal chapter_no, part_no, bucket, start_page, last_page, text_page_count
            if not bucket or start_page is None:
                return
            source_text = "\n\n".join(bucket).strip()
            chapters.append(
                {
                    "chapter_no": chapter_no,
                    "title": f"{label} ส่วนที่ {part_no:02d}",
                    "source_text": source_text,
                    "source_file": pdf_path.name,
                    "start_page": start_page,
                    "end_page": last_page,
                }
            )
            chapter_no += 1
            part_no += 1
            bucket = []
            start_page = None
            text_page_count = 0

        for page_index, page in enumerate(reader.pages, start=1):
            paragraphs = page_paragraphs(page.extract_text() or "")
            if not paragraphs:
                continue
            if start_page is None:
                start_page = page_index
            bucket.extend(paragraphs)
            last_page = page_index
            text_page_count += 1
            if text_page_count >= pages_per_chapter:
                flush()

        flush()

    return chapters


def split_for_translation(text: str, max_chars: int = 4300) -> list[str]:
    chunks: list[str] = []
    current = ""
    for paragraph in text.split("\n\n"):
        paragraph = paragraph.strip()
        if not paragraph:
            continue
        if len(paragraph) > max_chars:
            sentences = re.split(r"(?<=[.!?])\s+", paragraph)
            for sentence in sentences:
                if len(current) + len(sentence) + 1 > max_chars and current:
                    chunks.append(current.strip())
                    current = ""
                current += ("\n" if current else "") + sentence
            continue

        if len(current) + len(paragraph) + 2 > max_chars and current:
            chunks.append(current.strip())
            current = ""
        current += ("\n\n" if current else "") + paragraph

    if current:
        chunks.append(current.strip())
    return chunks


def load_cache(path: Path) -> dict[str, str]:
    if not path.is_file():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def save_cache(path: Path, cache: dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")


def translate_chunk(translator: GoogleTranslator, text: str, cache: dict[str, str], cache_path: Path) -> str:
    key = hashlib.sha256(text.encode("utf-8")).hexdigest()
    if key in cache:
        return cache[key]

    last_error: Exception | None = None
    for attempt in range(1, 5):
        try:
            translated = translator.translate(text)
            cache[key] = translated
            if len(cache) % 10 == 0:
                save_cache(cache_path, cache)
            time.sleep(0.15)
            return translated
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            time.sleep(2 * attempt)

    raise RuntimeError(f"Translation failed after retries: {last_error}")


def translate_chapters(
    chapters: list[dict[str, Any]],
    cache_path: Path,
    limit: int | None = None,
    cache_only: bool = False,
) -> list[dict[str, Any]]:
    cache = load_cache(cache_path)
    translator = GoogleTranslator(source="en", target="th")
    translated_chapters: list[dict[str, Any]] = []
    selected = chapters if limit is None else chapters[:limit]

    for index, chapter in enumerate(selected, start=1):
        source_text = str(chapter["source_text"])
        chunks = split_for_translation(source_text)
        translated_parts: list[str] = []
        print(
            f"[{index}/{len(selected)}] {chapter['title']} pages {chapter['start_page']}-{chapter['end_page']} chunks={len(chunks)}",
            flush=True,
        )
        for chunk_index, chunk in enumerate(chunks, start=1):
            key = hashlib.sha256(chunk.encode("utf-8")).hexdigest()
            if cache_only and key not in cache:
                print(f"  cache miss at chunk {chunk_index}/{len(chunks)}; stopping", flush=True)
                save_cache(cache_path, cache)
                return translated_chapters
            translated_parts.append(translate_chunk(translator, chunk, cache, cache_path))
            print(f"  chunk {chunk_index}/{len(chunks)}", flush=True)
        translated = "\n\n".join(translated_parts).strip()
        translated_chapters.append(
            {
                "chapter_no": chapter["chapter_no"],
                "title": chapter["title"],
                "content": translated,
                "word_count": count_words(translated),
                "source_file": chapter["source_file"],
                "start_page": chapter["start_page"],
                "end_page": chapter["end_page"],
            }
        )
        save_cache(cache_path, cache)

    return translated_chapters


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default=str(DEFAULT_SOURCE))
    parser.add_argument("--out", default=str(ROOT / "ocr_work" / "nihonkoku_th.json"))
    parser.add_argument("--cache", default=str(ROOT / "ocr_work" / "nihonkoku_translate_cache.json"))
    parser.add_argument("--pages-per-chapter", type=int, default=10)
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--extract-only", action="store_true")
    parser.add_argument("--cache-only", action="store_true")
    args = parser.parse_args()

    pdf_paths = source_pdfs(Path(args.source))
    if not pdf_paths:
        raise FileNotFoundError(f"No PDFs found in {args.source}")

    chapters = split_into_source_chapters(pdf_paths, args.pages_per_chapter)
    limit = args.limit if args.limit > 0 else None

    if args.extract_only:
        translated_chapters = [
            {
                "chapter_no": chapter["chapter_no"],
                "title": chapter["title"],
                "content": chapter["source_text"],
                "word_count": count_words(chapter["source_text"]),
                "source_file": chapter["source_file"],
                "start_page": chapter["start_page"],
                "end_page": chapter["end_page"],
            }
            for chapter in (chapters if limit is None else chapters[:limit])
        ]
    else:
        translated_chapters = translate_chapters(chapters, Path(args.cache), limit, args.cache_only)

    payload = {
        "title": TITLE,
        "source_name": f"Nihonkoku shoukan PDFs ({len(pdf_paths)} files), translated en-th",
        "cover_path": COVER_PATH,
        "chapters": translated_chapters,
        "missing_chapters": [],
    }

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"chapters={len(translated_chapters)}")
    if translated_chapters:
        print(f"first={translated_chapters[0]['chapter_no']} {translated_chapters[0]['title']}")
        print(f"last={translated_chapters[-1]['chapter_no']} {translated_chapters[-1]['title']}")
    print(f"json={out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
