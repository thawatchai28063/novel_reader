from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from pypdf import PdfReader


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PDF = ROOT / "source_novel.pdf"
DEFAULT_OUT = ROOT / "ocr_work"
GS = Path(r"C:\Program Files\PDF24\gs\bin\gswin64c.exe")
TESSERACT = Path(r"C:\Program Files\PDF24\tesseract\tesseract.exe")
TESSDATA = ROOT / "tessdata"

WATERMARK_RE = re.compile(r"(novelgu|https?://|^\s*re\s*\*)", re.I)
CHAPTER_RE = re.compile(r"^\s*(\d{1,4})\s*[:：]\s*(\S.*)$")
THAI_RE = re.compile(r"[\u0e00-\u0e7f]")


def page_count(pdf: Path) -> int:
    return len(PdfReader(str(pdf)).pages)


def extract_pdf_markers(pdf: Path, max_chapter: int) -> list[dict]:
    strict: list[dict] = []
    lax: list[dict] = []
    reader = PdfReader(str(pdf))
    order = 0
    for page_index, page in enumerate(reader.pages, start=1):
        text = page.extract_text() or ""
        for line in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
            clean = line.strip()
            order += 1
            if not clean:
                continue
            match = re.match(r"^(\d{1,4})\s*[:：]\s*(.+)$", clean)
            if match:
                strict.append(
                    {
                        "chapter_no": int(match.group(1)),
                        "title": match.group(2).strip(),
                        "page": page_index,
                        "order": order,
                    }
                )
                continue
            match = re.match(r"^(\d{1,4})\s+(\S.{2,})$", clean)
            if match:
                lax.append(
                    {
                        "chapter_no": int(match.group(1)),
                        "title": match.group(2).strip(),
                        "page": page_index,
                        "order": order,
                    }
                )

    markers: list[dict] = []
    seen: set[int] = set()
    last_no = 0
    for marker in strict:
        chapter_no = marker["chapter_no"]
        if chapter_no <= last_no or chapter_no > max_chapter:
            continue
        markers.append(marker)
        seen.add(chapter_no)
        last_no = chapter_no

    for marker in lax:
        chapter_no = marker["chapter_no"]
        if chapter_no in seen or chapter_no > max_chapter:
            continue
        for i in range(len(markers) - 1):
            before = markers[i]
            after = markers[i + 1]
            if (
                marker["order"] > before["order"]
                and marker["order"] < after["order"]
                and chapter_no > before["chapter_no"]
                and chapter_no < after["chapter_no"]
            ):
                markers.append(marker)
                seen.add(chapter_no)
                break

    return sorted(markers, key=lambda item: item["order"])


def clean_ocr_text(text: str) -> str:
    lines: list[str] = []
    for raw in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        line = raw.strip()
        if not line:
            lines.append("")
            continue
        if WATERMARK_RE.search(line):
            continue
        # Tesseract often emits tiny header fragments from page decoration.
        if not THAI_RE.search(line) and not CHAPTER_RE.match(line):
            if len(line) <= 8 or sum(ch.isalnum() for ch in line) < 3:
                continue
        lines.append(line)

    compact: list[str] = []
    blank = False
    for line in lines:
        if not line:
            if not blank:
                compact.append("")
            blank = True
        else:
            compact.append(line)
            blank = False

    return "\n".join(compact).strip()


def run_page(args: tuple[int, str, str, str, str, int, bool]) -> tuple[int, bool, str]:
    page, pdf, out_dir, gs, tesseract, dpi, force = args
    out = Path(out_dir)
    txt_path = out / "pages" / f"page_{page:04d}.txt"
    if txt_path.exists() and txt_path.stat().st_size > 0 and not force:
        return page, False, "cached"

    txt_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=f"ocr_page_{page}_", dir=out) as tmp:
        image = Path(tmp) / f"page_{page:04d}.png"
        gs_cmd = [
            gs,
            "-dSAFER",
            "-dBATCH",
            "-dNOPAUSE",
            "-sDEVICE=pnggray",
            f"-r{dpi}",
            f"-dFirstPage={page}",
            f"-dLastPage={page}",
            f"-sOutputFile={image}",
            pdf,
        ]
        gs_result = subprocess.run(
            gs_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        if gs_result.returncode != 0:
            return page, True, f"ghostscript failed: {gs_result.stdout[-500:]}"

        tess_cmd = [
            tesseract,
            str(image),
            "stdout",
            "--tessdata-dir",
            str(TESSDATA),
            "-l",
            "tha+eng",
            "--psm",
            "4",
        ]
        tess_result = subprocess.run(
            tess_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        if tess_result.returncode != 0:
            return page, True, f"tesseract failed: {tess_result.stderr[-500:]}"

        txt_path.write_text(clean_ocr_text(tess_result.stdout), encoding="utf-8")
        return page, True, "ok"


def iter_page_lines(out_dir: Path, start_page: int, end_page: int):
    global_index = 0
    for page in range(start_page, end_page + 1):
        txt_path = out_dir / "pages" / f"page_{page:04d}.txt"
        text = txt_path.read_text(encoding="utf-8") if txt_path.exists() else ""
        nonempty_index = 0
        for line in text.splitlines():
            if line.strip():
                nonempty_index += 1
            yield {
                "index": global_index,
                "page": page,
                "nonempty_index": nonempty_index,
                "line": line,
            }
            global_index += 1
        yield {"index": global_index, "page": page, "nonempty_index": 0, "line": ""}
        global_index += 1


def first_title_on_page(rows: list[dict], page: int, chapter_no: int) -> str:
    for row in rows:
        if row["page"] != page or row["nonempty_index"] > 10:
            continue
        line = row["line"].strip()
        match = CHAPTER_RE.match(line)
        if match and int(match.group(1)) == chapter_no:
            return match.group(2).strip()[:255]
    for row in rows:
        if row["page"] == page and 0 < row["nonempty_index"] <= 10:
            line = row["line"].strip()
            if THAI_RE.search(line) and "ตอนที่" not in line:
                return re.sub(r"^\d+\s*[:：]?\s*", "", line)[:255]
    return f"ตอนที่ {chapter_no}"


def first_marker_index_on_page(rows: list[dict], page: int, chapter_no: int) -> int | None:
    fallback: int | None = None
    for row in rows:
        if row["page"] != page:
            continue
        fallback = row["index"] if fallback is None else fallback
        if row["nonempty_index"] > 12:
            continue
        match = CHAPTER_RE.match(row["line"].strip())
        if match and int(match.group(1)) == chapter_no:
            return row["index"]
    return fallback - 1 if fallback is not None else None


def format_content(lines: list[str]) -> str:
    paragraphs: list[str] = []
    current: list[str] = []

    for raw in lines:
        line = raw.strip()
        if not line:
            if current:
                paragraphs.append("".join(current))
                current = []
            continue
        current.append(line)

    if current:
        paragraphs.append("".join(current))

    return "\n\n".join(paragraphs).strip()


def assemble(pdf: Path, out_dir: Path, start_page: int, end_page: int, max_chapter: int) -> dict:
    rows = list(iter_page_lines(out_dir, start_page, end_page))
    page_has_text = {
        page
        for page in range(start_page, end_page + 1)
        if (out_dir / "pages" / f"page_{page:04d}.txt").exists()
        and (out_dir / "pages" / f"page_{page:04d}.txt").stat().st_size > 0
    }
    page_first_index: dict[int, int] = {}
    for row in rows:
        if row["page"] in page_has_text:
            page_first_index.setdefault(row["page"], row["index"])

    ocr_markers: dict[int, dict] = {}

    for row in rows:
        match = CHAPTER_RE.match(row["line"].strip())
        if not match:
            continue
        chapter_no = int(match.group(1))
        title = match.group(2).strip()
        if chapter_no < 1 or chapter_no > max_chapter or chapter_no in ocr_markers:
            continue
        if row["nonempty_index"] > 8:
            continue
        if chapter_no in ocr_markers:
            continue
        ocr_markers[chapter_no] = {
            "chapter_no": chapter_no,
            "title": title[:255] if title else f"ตอนที่ {chapter_no}",
            "index": row["index"],
            "page": row["page"],
        }

    markers_by_no: dict[int, dict] = {}
    for marker in extract_pdf_markers(pdf, max_chapter):
        chapter_no = marker["chapter_no"]
        page = marker["page"]
        if page not in page_first_index:
            continue
        marker_index = first_marker_index_on_page(rows, page, chapter_no)
        if marker_index is None:
            continue
        markers_by_no[chapter_no] = {
            "chapter_no": chapter_no,
            "title": first_title_on_page(rows, page, chapter_no),
            "index": marker_index,
            "page": page,
        }

    for chapter_no, marker in ocr_markers.items():
        if chapter_no in markers_by_no:
            continue
        lower = [item for item in markers_by_no.values() if item["chapter_no"] < chapter_no]
        upper = [item for item in markers_by_no.values() if item["chapter_no"] > chapter_no]
        if not lower or not upper:
            continue
        before = max(lower, key=lambda item: item["chapter_no"])
        after = min(upper, key=lambda item: item["chapter_no"])
        if before["index"] < marker["index"] < after["index"]:
            markers_by_no[chapter_no] = marker

    markers = sorted(markers_by_no.values(), key=lambda item: item["index"])
    filtered: list[dict] = []
    last_no = 0
    for marker in markers:
        if marker["chapter_no"] <= last_no:
            continue
        filtered.append(marker)
        last_no = marker["chapter_no"]
    markers = filtered

    chapters: list[dict] = []
    for i, marker in enumerate(markers):
        start = marker["index"] + 1
        end = markers[i + 1]["index"] if i + 1 < len(markers) else rows[-1]["index"] + 1
        content_lines = [
            row["line"]
            for row in rows
            if start <= row["index"] < end
        ]
        content = format_content(content_lines)
        chapters.append(
            {
                "chapter_no": marker["chapter_no"],
                "title": marker["title"],
                "content": content,
                "word_count": len(re.findall(r"[\w\u0e00-\u0e7f]+", content, re.UNICODE)),
                "start_page": marker["page"],
            }
        )

    chapter_nos = {chapter["chapter_no"] for chapter in chapters}
    missing = [n for n in range(1, max_chapter + 1) if n not in chapter_nos]
    return {
        "title": "เจ้าของร้านพิศวง",
        "source_name": "เจ้าของร้านพิศวง 1-456.pdf OCR",
        "chapters": chapters,
        "missing_chapters": missing,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pdf", default=str(DEFAULT_PDF))
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--start-page", type=int, default=6)
    parser.add_argument("--end-page", type=int)
    parser.add_argument("--dpi", type=int, default=150)
    parser.add_argument("--workers", type=int, default=max(1, min((os.cpu_count() or 2) - 1, 6)))
    parser.add_argument("--max-chapter", type=int, default=456)
    parser.add_argument("--page-limit", type=int, help="OCR only this many missing pages, then assemble.")
    parser.add_argument("--skip-assemble", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--assemble-only", action="store_true")
    args = parser.parse_args()

    pdf = Path(args.pdf).resolve()
    out_dir = Path(args.out).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    end_page = args.end_page or page_count(pdf)

    if not args.assemble_only:
        pages = list(range(args.start_page, end_page + 1))
        if not args.force:
            pages = [
                page
                for page in pages
                if not (out_dir / "pages" / f"page_{page:04d}.txt").exists()
                or (out_dir / "pages" / f"page_{page:04d}.txt").stat().st_size == 0
            ]
        if args.page_limit:
            pages = pages[: args.page_limit]
        jobs = [
            (page, str(pdf), str(out_dir), str(GS), str(TESSERACT), args.dpi, args.force)
            for page in pages
        ]
        done = 0
        rendered = 0
        if jobs:
            with concurrent.futures.ProcessPoolExecutor(max_workers=args.workers) as pool:
                for page, did_work, message in pool.map(run_page, jobs, chunksize=1):
                    done += 1
                    rendered += 1 if did_work and message == "ok" else 0
                    if message not in {"ok", "cached"}:
                        print(f"[page {page}] {message}", flush=True)
                    if done % 20 == 0 or done == len(jobs):
                        print(
                            f"progress {done}/{len(jobs)} pages, newly_ocr={rendered}",
                            flush=True,
                        )
        else:
            print("progress 0/0 pages, all cached", flush=True)

    if args.skip_assemble:
        return 0

    result = assemble(pdf, out_dir, args.start_page, end_page, args.max_chapter)
    json_path = out_dir / "chapters_ocr.json"
    json_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(
        f"assembled chapters={len(result['chapters'])}, missing={result['missing_chapters']}",
        flush=True,
    )
    print(f"json={json_path}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
