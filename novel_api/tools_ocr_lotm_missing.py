from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from pypdf import PdfReader
from PIL import Image

from tools_extract_lotm_pdf import (
    count_words,
    fix_thai_spacing,
    format_content,
)


ROOT = Path(__file__).resolve().parent.parent
DOWNLOADS = Path.home() / "Downloads"
GS = Path(r"C:\Program Files\PDF24\gs\bin\gswin64c.exe")
TESSERACT = Path(r"C:\Program Files\PDF24\tesseract\tesseract.exe")
TESSDATA_BEST = ROOT / "tessdata_best"

OCR_JOBS = [
    ("lotm_201_300", "Lord of the Mysteries ราชันย์เร้นลับ 201-300.pdf", 1019, None),
    ("lotm_301_310", "Lord of the Mysteries ราชันย์เร้นลับ 301-310.pdf", 1, None),
    ("lotm_311_320", "Lord of the Mysteries ราชันย์เร้นลับ 311-320.pdf", 1, None),
    ("lotm_321_330", "Lord of the Mysteries ราชันย์เร้นลับ 321-330.pdf", 1, None),
    ("lotm_331_340", "Lord of the Mysteries ราชันย์เร้นลับ 331-340.pdf", 1, None),
    ("lotm_341_350", "Lord of the Mysteries ราชันย์เร้นลับ 341-350.pdf", 1, None),
    ("lotm_351_360", "Lord of the Mysteries ราชันย์เร้นลับ 351-360.pdf", 1, None),
    ("lotm_361_370", "Lord of the Mysteries ราชันย์เร้นลับ 361-370.pdf", 1, None),
    ("lotm_371_380", "Lord of the Mysteries ราชันย์เร้นลับ 371-380.pdf", 1, None),
    ("lotm_381_390", "Lord of the Mysteries ราชันย์เร้นลับ 381-390.pdf", 1, None),
]

HEADING_RE = re.compile(
    r"^\s*(?:(?:[รธ]?า?ช?ขัน(?:ย์)?\s*เร[้็]?[นบ]?[ลส]ั?[บพ]|ร?าชัน(?:ย์)?\s*เร[้็]?[นบ]?[ลส]ั?[บพ])\s*|ตอนที่\s*)"
    r"([0-9]{1,4})\s*(?:[:：\-–—]\s*)?(.*)$"
)
LENIENT_HEADING_RE = re.compile(r"^\s*[^\d\n]{0,35}\s([0-9]{3})\s*(?:[:：\-–—]\s*)?(.*)$")


def clean_ocr_text(text: str) -> str:
    text = fix_thai_spacing(text)
    replacements = {
        "ราชันย์เร้บลับ": "ราชันย์เร้นลับ",
        "ราชันย์เร้บสับ": "ราชันย์เร้นลับ",
        "ไดลน์": "ไคลน์",
        "ใดลน์": "ไคลน์",
        "ใคลน์": "ไคลน์",
        "ขาย": "ชาย",
        "ตํา": "ดำ",
        "ดํา": "ดำ",
        "กําลัง": "กำลัง",
        "ทํา": "ทำ",
        "สํา": "สำ",
        "คํา": "คำ",
        "จํา": "จำ",
        "น้า": "น้ำ",
    }
    for wrong, right in replacements.items():
        text = text.replace(wrong, right)

    lines: list[str] = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            lines.append("")
            continue
        if re.fullmatch(r"[0-9 oO๐๑๒๓๔๕๖๗๘๙.,:;'\"]{1,12}", line):
            continue
        lines.append(line)
    return "\n".join(lines).strip()


def page_count(pdf: Path) -> int:
    return len(PdfReader(str(pdf)).pages)


def ensure_ascii_pdf(src: Path, out_dir: Path, job_name: str) -> Path:
    target = out_dir / "pdfs" / f"{job_name}.pdf"
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists() or target.stat().st_size != src.stat().st_size:
        shutil.copy2(src, target)
    return target


def run_page(args: tuple[str, str, int, str, str, str, int, int, bool]) -> tuple[str, int, bool, str]:
    job_name, pdf, page, out_dir, gs, tesseract, dpi, psm, force = args
    out = Path(out_dir)
    txt_path = out / "pages" / job_name / f"page_{page:04d}.txt"
    if txt_path.exists() and txt_path.stat().st_size > 0 and not force:
        return job_name, page, False, "cached"

    txt_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=f"{job_name}_{page}_", dir=out) as tmp:
        image = Path(tmp) / f"page_{page:04d}.png"
        gs_result = subprocess.run(
            [
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
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        if gs_result.returncode != 0:
            return job_name, page, True, f"ghostscript failed: {gs_result.stdout[-300:]}"

        try:
            with Image.open(image) as img:
                width, height = img.size
                if height > 3600:
                    parts: list[str] = []
                    top = 0
                    tile_height = 3000
                    overlap = 160
                    index = 0
                    while top < height:
                        bottom = min(height, top + tile_height)
                        crop = img.crop((0, top, width, bottom))
                        crop_path = Path(tmp) / f"page_{page:04d}_{index:02d}.png"
                        crop.save(crop_path)
                        tess_result = subprocess.run(
                            [
                                tesseract,
                                str(crop_path),
                                "stdout",
                                "--tessdata-dir",
                                str(TESSDATA_BEST),
                                "-l",
                                "tha+eng",
                                "--psm",
                                str(psm),
                            ],
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE,
                            text=True,
                            encoding="utf-8",
                            errors="replace",
                        )
                        if tess_result.returncode == 0:
                            parts.append(tess_result.stdout)
                        elif "Image too large" in tess_result.stderr:
                            return job_name, page, True, f"tesseract failed: {tess_result.stderr[-300:]}"
                        top = bottom - overlap
                        if top <= 0 or bottom == height:
                            break
                        index += 1
                    text = "\n".join(parts)
                else:
                    tess_result = subprocess.run(
                        [
                            tesseract,
                            str(image),
                            "stdout",
                            "--tessdata-dir",
                            str(TESSDATA_BEST),
                            "-l",
                            "tha+eng",
                            "--psm",
                            str(psm),
                        ],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        text=True,
                        encoding="utf-8",
                        errors="replace",
                    )
                    if tess_result.returncode != 0:
                        return job_name, page, True, f"tesseract failed: {tess_result.stderr[-300:]}"
                    text = tess_result.stdout
        except Exception as exc:
            return job_name, page, True, f"ocr failed: {exc}"

        txt_path.write_text(clean_ocr_text(text), encoding="utf-8")
        return job_name, page, True, "ok"


def split_ocr_chapters(out_dir: Path, jobs: list[tuple[str, Path, int, int]]) -> list[dict]:
    chapters: list[dict] = []
    current_no: int | None = None
    current_title = ""
    current_lines: list[str] = []
    current_source = ""
    current_page = 0

    def flush() -> None:
        nonlocal current_no, current_title, current_lines, current_source, current_page
        if current_no is None:
            return
        content = format_content(current_lines)
        if content:
            chapters.append(
                {
                    "chapter_no": current_no,
                    "title": current_title or f"ตอนที่ {current_no}",
                    "content": content,
                    "word_count": count_words(content),
                    "source_file": current_source,
                    "start_page": current_page,
                    "ocr": True,
                }
            )
        current_no = None
        current_title = ""
        current_lines = []

    for job_name, _pdf, start_page, end_page in jobs:
        for page in range(start_page, end_page + 1):
            txt_path = out_dir / "pages" / job_name / f"page_{page:04d}.txt"
            text = txt_path.read_text(encoding="utf-8") if txt_path.exists() else ""
            for line in text.splitlines():
                clean = line.strip()
                match = HEADING_RE.match(clean)
                if not match and ("เร" in clean or "ขัน" in clean or "ชัน" in clean):
                    match = LENIENT_HEADING_RE.match(clean)
                if match:
                    chapter_no = int(match.group(1))
                    if 1 <= chapter_no <= 850:
                        flush()
                        current_no = chapter_no
                        title = match.group(2).strip(" :-–—")
                        current_title = title[:255] if title else f"ตอนที่ {chapter_no}"
                        current_source = job_name
                        current_page = page
                        current_lines = []
                        continue
                if current_no is not None:
                    current_lines.append(clean)
            if current_no is not None:
                current_lines.append("")
    flush()
    return chapters


def merge(base_json: Path, ocr_chapters: list[dict], out_json: Path) -> dict:
    base = json.loads(base_json.read_text(encoding="utf-8"))
    by_no = {int(chapter["chapter_no"]): chapter for chapter in base["chapters"]}
    added: list[int] = []
    for chapter in ocr_chapters:
        chapter_no = int(chapter["chapter_no"])
        if chapter_no not in by_no:
            by_no[chapter_no] = chapter
            added.append(chapter_no)

    chapters = [by_no[number] for number in sorted(by_no)]
    missing = [number for number in range(1, 851) if number not in by_no]
    result = {
        "title": "ราชันย์เร้นลับ",
        "source_name": "Lord of the Mysteries ราชันย์เร้นลับ PDF text + detailed OCR",
        "chapters": chapters,
        "missing_chapters": missing,
        "ocr_added_chapters": sorted(added),
    }
    out_json.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default=str(ROOT / "ocr_work" / "lotm_missing_ocr"))
    parser.add_argument("--base-json", default=str(ROOT / "ocr_work" / "lord_of_mysteries_pdf_text.json"))
    parser.add_argument("--merged-json", default=str(ROOT / "ocr_work" / "lord_of_mysteries_merged.json"))
    parser.add_argument("--dpi", type=int, default=220)
    parser.add_argument("--psm", type=int, default=6)
    parser.add_argument("--workers", type=int, default=max(1, min((os.cpu_count() or 2) - 1, 4)))
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--assemble-only", action="store_true")
    args = parser.parse_args()

    out_dir = Path(args.out).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    jobs: list[tuple[str, Path, int, int]] = []
    for job_name, filename, start_page, end_page in OCR_JOBS:
        src = DOWNLOADS / filename
        if not src.exists():
            print(f"missing pdf: {src}")
            continue
        pdf = ensure_ascii_pdf(src, out_dir, job_name)
        last_page = end_page or page_count(pdf)
        jobs.append((job_name, pdf, start_page, last_page))

    if not args.assemble_only:
        tasks = []
        for job_name, pdf, start_page, end_page in jobs:
            for page in range(start_page, end_page + 1):
                tasks.append(
                    (
                        job_name,
                        str(pdf),
                        page,
                        str(out_dir),
                        str(GS),
                        str(TESSERACT),
                        args.dpi,
                        args.psm,
                        args.force,
                    )
                )

        done = 0
        rendered = 0
        with concurrent.futures.ProcessPoolExecutor(max_workers=args.workers) as pool:
            for job_name, page, did_work, message in pool.map(run_page, tasks, chunksize=1):
                done += 1
                if did_work and message == "ok":
                    rendered += 1
                if message not in {"ok", "cached"}:
                    print(f"[{job_name} page {page}] {message}", flush=True)
                if done % 10 == 0 or done == len(tasks):
                    print(f"progress {done}/{len(tasks)} pages, newly_ocr={rendered}", flush=True)

    ocr_chapters = split_ocr_chapters(out_dir, jobs)
    result = merge(Path(args.base_json), ocr_chapters, Path(args.merged_json))
    print(f"ocr_chapters={len(ocr_chapters)}")
    print(f"merged_chapters={len(result['chapters'])}")
    print(f"ocr_added={result['ocr_added_chapters'][:120]}")
    print(f"missing={result['missing_chapters']}")
    print(f"json={args.merged_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
