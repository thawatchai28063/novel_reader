from __future__ import annotations

import argparse
import io
import json
import re
import sys
import time
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
PYDEPS_AUDIO_LOCAL = ROOT / "pydeps_audio_local"
AUDIO_ROOT = ROOT / "novel_api" / "audio"

if str(PYDEPS_AUDIO_LOCAL) not in sys.path:
    sys.path.insert(0, str(PYDEPS_AUDIO_LOCAL))


def clean_tts_text(text: str, max_chars: int) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]", "", text)
    text = text.replace("\ufeff", "")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = text.strip()
    if len(text) <= max_chars:
        return text
    return text[:max_chars].strip()


def clip_filename(novel_id: int, first: int, last: int) -> Path:
    return AUDIO_ROOT / f"novel_{novel_id}" / f"chapters_{first:04d}_{last:04d}.mp3"


def build_clip_text(chapters: list[dict[str, Any]], max_chars: int) -> str:
    blocks: list[str] = []
    for chapter in chapters:
        header = f"ตอนที่ {chapter['chapter_no']} {chapter['title']}"
        blocks.append(f"{header}\n\n{chapter['content']}")
    return clean_tts_text("\n\n".join(blocks), max_chars)


def split_blocks(text: str, block_chars: int) -> list[str]:
    blocks: list[str] = []
    current = ""
    for paragraph in [part.strip() for part in re.split(r"\n{2,}", text) if part.strip()]:
        if len(paragraph) > block_chars:
            for start in range(0, len(paragraph), block_chars):
                current = append_block(blocks, current, paragraph[start : start + block_chars], block_chars)
            continue
        current = append_block(blocks, current, paragraph, block_chars)
    if current.strip():
        blocks.append(current.strip())
    return blocks


def append_block(blocks: list[str], current: str, piece: str, block_chars: int) -> str:
    piece = piece.strip()
    if not piece:
        return current
    if len(current) + len(piece) + 2 <= block_chars:
        return f"{current}\n\n{piece}".strip()
    if current.strip():
        blocks.append(current.strip())
    return piece


def write_gtts_block(
    text: str,
    out_buffer: io.BytesIO,
    lang: str,
    tld: str,
    retries: int,
    rate_limit_sleep: int,
) -> None:
    from gtts import gTTS

    last_error: Exception | None = None
    for attempt in range(retries + 1):
        try:
            gTTS(text=text, lang=lang, tld=tld, slow=False).write_to_fp(out_buffer)
            return
        except Exception as exc:
            last_error = exc
            if attempt < retries:
                message = str(exc)
                delay = rate_limit_sleep if "429" in message or "Too Many Requests" in message else 2 + attempt
                print(f"gtts retry {attempt + 1}/{retries} after {delay}s: {message}", flush=True)
                time.sleep(delay)
    if last_error is not None:
        raise last_error


def write_audio(
    text: str,
    out_path: Path,
    lang: str,
    tld: str,
    block_chars: int,
    retries: int,
    block_delay: float,
    rate_limit_sleep: int,
) -> int:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    blocks = split_blocks(text, block_chars)
    temp_path = out_path.with_suffix(out_path.suffix + ".tmp")
    with temp_path.open("wb") as output:
        for index, block in enumerate(blocks, start=1):
            print(f"gtts block {index}/{len(blocks)} chars={len(block)}", flush=True)
            buffer = io.BytesIO()
            write_gtts_block(block, buffer, lang, tld, retries, rate_limit_sleep)
            output.write(buffer.getvalue())
            if block_delay > 0:
                time.sleep(block_delay)
    temp_path.replace(out_path)
    return len(blocks)


def load_exported_json(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict) or not isinstance(payload.get("chapters"), list):
        raise ValueError("Invalid exported chapters JSON")
    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("json_path")
    parser.add_argument("--novel-id", type=int, required=True)
    parser.add_argument("--start", type=int, default=1)
    parser.add_argument("--groups", type=int, default=1)
    parser.add_argument("--chapters-per-clip", type=int, default=10)
    parser.add_argument("--lang", default="th")
    parser.add_argument("--tld", default="co.th")
    parser.add_argument("--max-chars", type=int, default=48_000)
    parser.add_argument("--block-chars", type=int, default=4_500)
    parser.add_argument("--retries", type=int, default=2)
    parser.add_argument("--block-delay", type=float, default=0.0)
    parser.add_argument("--rate-limit-sleep", type=int, default=120)
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()

    payload = load_exported_json(Path(args.json_path))
    chapters = [
        chapter
        for chapter in payload["chapters"]
        if int(chapter.get("chapter_no", 0)) >= args.start
    ]

    results: list[dict[str, Any]] = []
    for group in range(args.groups):
        chunk = chapters[group * args.chapters_per_clip : (group + 1) * args.chapters_per_clip]
        if not chunk:
            break
        first = int(chunk[0]["chapter_no"])
        last = int(chunk[-1]["chapter_no"])
        out_path = clip_filename(args.novel_id, first, last)
        if out_path.exists() and not args.overwrite:
            results.append({"file": str(out_path), "status": "exists", "chapters": f"{first}-{last}"})
            continue
        text = build_clip_text(chunk, args.max_chars)
        block_count = write_audio(
            text,
            out_path,
            args.lang,
            args.tld,
            args.block_chars,
            args.retries,
            args.block_delay,
            args.rate_limit_sleep,
        )
        results.append(
            {
                "file": str(out_path),
                "status": "written",
                "chapters": f"{first}-{last}",
                "characters": len(text),
                "audio_blocks": block_count,
            }
        )

    print(json.dumps(results, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
