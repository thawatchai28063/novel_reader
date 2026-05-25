from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path

from docx import Document


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DOCX = ROOT / "exports" / "เจ้าของร้านพิศวง_แก้คำ.docx"
DEFAULT_JSON = ROOT / "ocr_work" / "owner_store_from_docx.json"
IMPORT_PHP = ROOT / "novel_api" / "tools_import_chapters_json.php"
PHP_EXE = Path(r"C:\xampp\php\php.exe")
NOVEL_ID = 3


HEADING_RE = re.compile(r"^ตอนที่\s*(\d+)\s*:?\s*(.*)$")
META_RE = re.compile(r"^คำประมาณ\s+\d+\s+คำ$")


def count_words(text: str) -> int:
    return len(re.findall(r"[\w\u0E00-\u0E7F]+", text, flags=re.UNICODE))


def parse_docx(path: Path) -> list[dict[str, object]]:
    document = Document(path)
    chapters: list[dict[str, object]] = []
    current: dict[str, object] | None = None
    blocks: list[str] = []

    def flush() -> None:
        nonlocal current, blocks
        if current is None:
            return
        content = "\n\n".join(block for block in blocks if block.strip()).strip()
        current["content"] = content
        current["word_count"] = count_words(content)
        chapters.append(current)
        current = None
        blocks = []

    for paragraph in document.paragraphs:
        text = paragraph.text.strip()
        if not text:
            continue
        match = HEADING_RE.match(text)
        if match:
            flush()
            chapter_no = int(match.group(1))
            title = match.group(2).strip() or f"ตอนที่ {chapter_no}"
            current = {
                "chapter_no": chapter_no,
                "title": title[:255],
                "content": "",
                "word_count": 0,
            }
            continue
        if current is None or META_RE.match(text):
            continue
        blocks.append(text)

    flush()
    return chapters


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("docx", nargs="?", default=str(DEFAULT_DOCX))
    parser.add_argument("--json", default=str(DEFAULT_JSON))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    docx_path = Path(args.docx)
    json_path = Path(args.json)
    chapters = parse_docx(docx_path)
    payload = {
        "title": "เจ้าของร้านพิศวง",
        "source_name": docx_path.name + " edited Word import",
        "chapters": chapters,
    }
    json_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"parsed_chapters={len(chapters)} json={json_path}")
    if chapters:
        print(f"first={chapters[0]['chapter_no']} {chapters[0]['title']}")
        print(f"last={chapters[-1]['chapter_no']} {chapters[-1]['title']}")

    if args.dry_run:
        return 0

    subprocess.run(
        [str(PHP_EXE), str(IMPORT_PHP), str(json_path), str(NOVEL_ID)],
        check=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
