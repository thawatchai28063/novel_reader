from __future__ import annotations

import argparse
import asyncio
import json
import re
import sys
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
PYDEPS_AUDIO = ROOT / "pydeps_audio"
PYDEPS_AUDIO_LOCAL = ROOT / "pydeps_audio_local"
PYDEPS_TTS_FRESH = ROOT / "pydeps_tts_fresh"
PYDEPS = ROOT / "pydeps"
PHP = Path("C:/xampp/php/php.exe")
EXPORT_SCRIPT = ROOT / "novel_api" / "tools_export_chapters_json.php"
AUDIO_ROOT = ROOT / "novel_api" / "audio"

if str(PYDEPS_TTS_FRESH) not in sys.path:
    sys.path.insert(0, str(PYDEPS_TTS_FRESH))


def clean_tts_text(text: str, max_chars: int) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]", "", text)
    text = text.replace("\ufeff", "")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = text.strip()
    if len(text) <= max_chars:
        return text
    return text[:max_chars].rsplit(" ", 1)[0].strip()


def clip_filename(novel_id: int, first: int, last: int) -> Path:
    return AUDIO_ROOT / f"novel_{novel_id}" / f"chapters_{first:04d}_{last:04d}.mp3"


def build_clip_text(chapters: list[dict[str, Any]], max_chars: int) -> str:
    blocks: list[str] = []
    for chapter in chapters:
        header = f"ตอนที่ {chapter['chapter_no']} {chapter['title']}"
        blocks.append(f"{header}\n\n{chapter['content']}")
    return clean_tts_text("\n\n".join(blocks), max_chars)


def split_text(text: str, chunk_chars: int) -> list[str]:
    paragraphs = [part.strip() for part in re.split(r"\n{2,}", text) if part.strip()]
    chunks: list[str] = []
    current = ""
    for paragraph in paragraphs:
        if len(paragraph) > chunk_chars:
            sentences = re.split(r"(?<=[.!?\u0e2f\u0e46])\s+", paragraph)
            for sentence in sentences:
                current = append_chunk(chunks, current, sentence, chunk_chars)
            continue
        current = append_chunk(chunks, current, paragraph, chunk_chars)
    if current.strip():
        chunks.append(current.strip())
    return chunks


def append_chunk(chunks: list[str], current: str, piece: str, chunk_chars: int) -> str:
    piece = piece.strip()
    if not piece:
        return current
    if len(piece) > chunk_chars:
        for start in range(0, len(piece), chunk_chars):
            current = append_chunk(chunks, current, piece[start : start + chunk_chars], chunk_chars)
        return current
    if len(current) + len(piece) + 2 <= chunk_chars:
        return f"{current}\n\n{piece}".strip()
    if current.strip():
        chunks.append(current.strip())
    return piece


async def write_audio_chunk(text: str, out_path: Path, voice: str, rate: str, retries: int) -> None:
    try:
        import edge_tts
    except ImportError as exc:
        raise RuntimeError(
            "edge-tts is not installed. Run: python -m pip install --target pydeps edge-tts"
        ) from exc

    last_error: Exception | None = None
    for attempt in range(retries + 1):
        try:
            communicate = edge_tts.Communicate(text=text, voice=voice, rate=rate)
            await communicate.save(str(out_path))
            if out_path.stat().st_size > 0:
                return
        except Exception as exc:  # edge-tts exposes multiple transient exceptions.
            last_error = exc
            if attempt < retries:
                await asyncio.sleep(2 + attempt)
    if last_error is not None:
        raise last_error
    raise RuntimeError("edge-tts wrote an empty audio chunk")


async def write_audio_chunk_resilient(
    text: str,
    out_path: Path,
    voice: str,
    rate: str,
    retries: int,
    min_chars: int = 450,
) -> int:
    original_error: Exception | None = None
    try:
        await write_audio_chunk(text, out_path, voice, rate, retries)
        return 1
    except Exception as exc:
        original_error = exc
        if len(text) <= min_chars:
            raise

    midpoint = len(text) // 2
    split_at = max(
        text.rfind("\n", 0, midpoint),
        text.rfind(" ", 0, midpoint),
        text.rfind("。", 0, midpoint),
        text.rfind("?", 0, midpoint),
        text.rfind("!", 0, midpoint),
    )
    if split_at < min_chars:
        split_at = midpoint

    left = text[:split_at].strip()
    right = text[split_at:].strip()
    if not left or not right:
        if original_error is not None:
            raise original_error
        raise RuntimeError("Cannot split TTS chunk")

    left_path = out_path.with_suffix(out_path.suffix + ".part1")
    right_path = out_path.with_suffix(out_path.suffix + ".part2")
    left_count = await write_audio_chunk_resilient(left, left_path, voice, rate, retries, min_chars)
    right_count = await write_audio_chunk_resilient(right, right_path, voice, rate, retries, min_chars)

    with out_path.open("wb") as output:
        output.write(left_path.read_bytes())
        output.write(right_path.read_bytes())
    left_path.unlink(missing_ok=True)
    right_path.unlink(missing_ok=True)
    return left_count + right_count


async def write_audio(text: str, out_path: Path, voice: str, rate: str, chunk_chars: int, retries: int) -> int:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    chunks = split_text(text, chunk_chars)
    temp_output_path = out_path.with_suffix(out_path.suffix + ".tmp")
    temp_output_path.unlink(missing_ok=True)
    with tempfile.TemporaryDirectory(prefix="novel_audio_") as temp_dir:
        temp_path = Path(temp_dir)
        with temp_output_path.open("wb") as output:
            for index, chunk in enumerate(chunks, start=1):
                chunk_path = temp_path / f"chunk_{index:04d}.mp3"
                print(f"tts chunk {index}/{len(chunks)} chars={len(chunk)}", flush=True)
                try:
                    await write_audio_chunk_resilient(chunk, chunk_path, voice, rate, retries)
                except Exception:
                    failed_path = out_path.with_suffix(f".failed_chunk_{index:04d}.txt")
                    failed_path.write_text(chunk, encoding="utf-8")
                    raise
                output.write(chunk_path.read_bytes())
                output.flush()
        temp_output_path.replace(out_path)
    return len(chunks)


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
    parser.add_argument("--voice", default="th-TH-PremwadeeNeural")
    parser.add_argument("--rate", default="+0%")
    parser.add_argument("--max-chars", type=int, default=48_000)
    parser.add_argument("--chunk-chars", type=int, default=3_500)
    parser.add_argument("--retries", type=int, default=2)
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
        chunk = chapters[
            group * args.chapters_per_clip : (group + 1) * args.chapters_per_clip
        ]
        if not chunk:
            break
        first = int(chunk[0]["chapter_no"])
        last = int(chunk[-1]["chapter_no"])
        out_path = clip_filename(args.novel_id, first, last)
        if out_path.exists() and not args.overwrite:
            results.append({"file": str(out_path), "status": "exists"})
            continue
        text = build_clip_text(chunk, args.max_chars)
        chunk_count = asyncio.run(
            write_audio(text, out_path, args.voice, args.rate, args.chunk_chars, args.retries)
        )
        results.append(
            {
                "file": str(out_path),
                "status": "written",
                "chapters": f"{first}-{last}",
                "characters": len(text),
                "audio_chunks": chunk_count,
            }
        )

    print(json.dumps(results, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
