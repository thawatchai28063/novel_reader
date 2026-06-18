from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import Counter
from functools import lru_cache
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
PYDEPS = ROOT / "pydeps"
PYTHAINLP_DATA = ROOT / "pythainlp-data"

if str(PYDEPS) not in sys.path:
    sys.path.insert(0, str(PYDEPS))

os.environ.setdefault("PYTHAINLP_DATA", str(PYTHAINLP_DATA))

from pythainlp.tokenize import word_tokenize  # noqa: E402


THAI_CHARS = "\u0e00-\u0e7f"
THAI_BASE = "\u0e01-\u0e2e"
THAI_MARKS = "\u0e31-\u0e3a\u0e47-\u0e4e"
THAI_LEADS = "\u0e40-\u0e44"
THAI_AFTER_MARK = "\u0e30\u0e32\u0e33"

THAI_SPACE_RE = re.compile(rf"(?<=[{THAI_CHARS}])[ \t]+(?=[{THAI_CHARS}])")
REPEATED_SPACE_RE = re.compile(r"[ \t]{2,}")
THAI_MARK_GAP_RE = re.compile(
    rf"([{THAI_BASE}{THAI_LEADS}{THAI_MARKS}])[ \t]+"
    rf"([{THAI_MARKS}{THAI_AFTER_MARK}])"
)
THAI_LEAD_GAP_RE = re.compile(rf"([{THAI_LEADS}])[ \t]+([{THAI_BASE}])")
THAI_SPAN_RE = re.compile(rf"[{THAI_CHARS}][{THAI_CHARS} \t]*[{THAI_CHARS}]|[{THAI_CHARS}]")
WORD_RE = re.compile(rf"[{THAI_CHARS}]+|[A-Za-z0-9]+", re.UNICODE)
THAI_LEFT_RE = re.compile(rf"[{THAI_CHARS}]+$")
THAI_RIGHT_RE = re.compile(rf"[{THAI_CHARS}]+")
THAI_PUNCT = "\u0e2f\u0e46"
JOIN_RIGHT_WORDS = {
    "\u0e27\u0e48\u0e32",  # wa
    "\u0e44\u0e27\u0e49",  # wai
    "\u0e44\u0e14\u0e49",  # dai
    "\u0e2d\u0e22\u0e39\u0e48",  # yu
    "\u0e2d\u0e32\u0e28\u0e31\u0e22",  # asai
    "\u0e44\u0e1b",  # pai
    "\u0e21\u0e32",  # ma
    "\u0e02\u0e36\u0e49\u0e19",  # khuen
    "\u0e25\u0e07",  # long
    "\u0e40\u0e02\u0e49\u0e32",  # khao
    "\u0e2d\u0e2d\u0e01",  # ok
    "\u0e40\u0e2d\u0e32",  # ao
}


@lru_cache(maxsize=80_000)
def cached_word_tokenize(text: str, engine: str) -> tuple[str, ...]:
    return tuple(word_tokenize(text, engine=engine, keep_whitespace=False))


def count_reading_units(text: str, engine: str) -> int:
    total = 0
    for part in WORD_RE.findall(text):
        if re.search(rf"[{THAI_CHARS}]", part):
            total += len(cached_word_tokenize(part, engine))
        else:
            total += 1
    return total


def text_metrics(text: str) -> dict[str, int]:
    return {
        "characters": len(text),
        "thai_space_thai": len(THAI_SPACE_RE.findall(text)),
        "repeated_spaces": len(REPEATED_SPACE_RE.findall(text)),
        "thai_mark_gaps": len(THAI_MARK_GAP_RE.findall(text)) + len(THAI_LEAD_GAP_RE.findall(text)),
        "paragraphs": len([part for part in re.split(r"\n{2,}", text.strip()) if part.strip()]),
    }


def normalize_thai_span_join_all(match: re.Match[str], engine: str, changes: Counter[str]) -> str:
    span = match.group(0)
    if " " not in span and "\t" not in span:
        return span

    compact = re.sub(r"[ \t]+", "", span)
    if compact == span:
        return span

    # Tokenize the compact span so PyThaiNLP is part of the normalization path.
    # The final text keeps Thai prose continuous, which is the normal reading style.
    tokens = cached_word_tokenize(compact, engine)
    rebuilt = "".join(tokens)
    if rebuilt != span:
        changes["thai_internal_spaces_removed"] += 1
    return rebuilt


def should_remove_thai_gap(
    text: str, start: int, end: int, engine: str, token_gap_check: bool
) -> bool:
    right_text = text[end : end + 32]
    if not right_text:
        return False
    if right_text[0] in THAI_PUNCT:
        return False

    if any(right_text.startswith(word) for word in JOIN_RIGHT_WORDS):
        return True

    if not token_gap_check:
        return False

    left_match = THAI_LEFT_RE.search(text[:start])
    right_match = THAI_RIGHT_RE.match(text[end:])
    if not left_match or not right_match:
        return False

    left_text = left_match.group(0)[-32:]
    right_text = right_match.group(0)[:32]

    left_tokens = cached_word_tokenize(left_text, engine)
    right_tokens = cached_word_tokenize(right_text, engine)
    if not left_tokens or not right_tokens:
        return False

    candidate = left_tokens[-1] + right_tokens[0]
    candidate_tokens = cached_word_tokenize(candidate, engine)
    return len(candidate_tokens) == 1 and candidate_tokens[0] == candidate


def normalize_thai_gaps_conservative(
    text: str, engine: str, token_gap_check: bool, changes: Counter[str]
) -> str:
    def replace_gap(match: re.Match[str]) -> str:
        if should_remove_thai_gap(text, match.start(), match.end(), engine, token_gap_check):
            changes["thai_word_internal_spaces_removed"] += 1
            return ""
        return " "

    return THAI_SPACE_RE.sub(replace_gap, text)


def normalize_block(
    text: str, engine: str, strategy: str, token_gap_check: bool, changes: Counter[str]
) -> str:
    original = text
    text = text.replace("\r\n", "\n").replace("\r", "\n").replace("\u00a0", " ")
    text = text.replace("\ufeff", "")

    for _ in range(4):
        next_text = THAI_MARK_GAP_RE.sub(r"\1\2", text)
        next_text = THAI_LEAD_GAP_RE.sub(r"\1\2", next_text)
        next_text = re.sub(rf"([{THAI_MARKS}])[ \t]+([{THAI_MARKS}{THAI_AFTER_MARK}])", r"\1\2", next_text)
        if next_text == text:
            break
        text = next_text
        changes["thai_mark_spacing_fixed"] += 1

    text = re.sub(r"[ \t]*\n[ \t]*", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)

    paragraphs: list[str] = []
    for paragraph in re.split(r"\n{2,}", text):
        paragraph = paragraph.strip()
        if not paragraph:
            continue
        paragraph = re.sub(r"[ \t]*\n[ \t]*", " ", paragraph)
        paragraph = REPEATED_SPACE_RE.sub(" ", paragraph)
        if strategy == "join-all":
            paragraph = THAI_SPAN_RE.sub(
                lambda match: normalize_thai_span_join_all(match, engine, changes),
                paragraph,
            )
        else:
            paragraph = normalize_thai_gaps_conservative(
                paragraph, engine, token_gap_check, changes
            )
        paragraph = re.sub(r"\s+([,.;:!?%\]\)\}\u0e2f\u0e46\u201d\u2019])", r"\1", paragraph)
        paragraph = re.sub(r"([\[\(\{\u201c\u2018])\s+", r"\1", paragraph)
        paragraph = re.sub(rf"(?<=[{THAI_CHARS}])[ \t]+(?=[,.;:!?%\]\)\}}\u0e2f\u0e46])", "", paragraph)
        paragraph = REPEATED_SPACE_RE.sub(" ", paragraph).strip()
        paragraphs.append(paragraph)

    text = "\n\n".join(paragraphs).strip()
    if text != original:
        changes["changed_blocks"] += 1
    return text


def normalize_payload(
    payload: dict[str, Any],
    engine: str,
    strategy: str,
    sample_limit: int,
    recount_word_count: bool,
    token_gap_check: bool,
) -> tuple[dict[str, Any], dict[str, Any]]:
    changes: Counter[str] = Counter()
    examples: list[dict[str, Any]] = []
    before_totals: Counter[str] = Counter()
    after_totals: Counter[str] = Counter()

    for chapter in payload.get("chapters", []):
        if not isinstance(chapter, dict):
            continue

        old_title = str(chapter.get("title", ""))
        old_content = str(chapter.get("content", ""))
        before_title_metrics = text_metrics(old_title)
        before_content_metrics = text_metrics(old_content)

        new_title = normalize_block(old_title, engine, strategy, token_gap_check, changes)
        new_content = normalize_block(old_content, engine, strategy, token_gap_check, changes)

        chapter["title"] = new_title
        chapter["content"] = new_content
        if recount_word_count:
            chapter["word_count"] = count_reading_units(new_content, engine)

        after_title_metrics = text_metrics(new_title)
        after_content_metrics = text_metrics(new_content)
        before_totals.update(before_title_metrics)
        before_totals.update(before_content_metrics)
        after_totals.update(after_title_metrics)
        after_totals.update(after_content_metrics)

        if (old_title, old_content) != (new_title, new_content) and len(examples) < sample_limit:
            examples.append(
                {
                    "chapter_no": chapter.get("chapter_no"),
                    "old_title": old_title,
                    "new_title": new_title,
                    "old_sample": old_content[:360],
                    "new_sample": new_content[:360],
                    "before_metrics": before_content_metrics,
                    "after_metrics": after_content_metrics,
                }
            )

    report = {
        "engine": engine,
        "strategy": strategy,
        "recount_word_count": recount_word_count,
        "token_gap_check": token_gap_check,
        "chapters": len(payload.get("chapters", [])),
        "changes": dict(changes.most_common()),
        "before_totals": dict(before_totals),
        "after_totals": dict(after_totals),
        "examples": examples,
    }
    return payload, report


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Normalize Thai novel spacing in exported chapters JSON."
    )
    parser.add_argument("input_json")
    parser.add_argument("output_json")
    parser.add_argument("--report", default="")
    parser.add_argument("--engine", default="newmm", help="PyThaiNLP word_tokenize engine")
    parser.add_argument(
        "--strategy",
        choices=["conservative", "join-all"],
        default="conservative",
        help="Spacing strategy. conservative keeps likely sentence gaps; join-all removes all Thai-Thai gaps.",
    )
    parser.add_argument(
        "--recount-word-count",
        action="store_true",
        help="Recalculate word_count with PyThaiNLP. Slower; off by default.",
    )
    parser.add_argument(
        "--token-gap-check",
        action="store_true",
        help="Use PyThaiNLP to inspect unresolved Thai-Thai gaps. Slower; off by default.",
    )
    parser.add_argument("--sample-limit", type=int, default=30)
    args = parser.parse_args()

    input_path = Path(args.input_json)
    output_path = Path(args.output_json)
    report_path = Path(args.report) if args.report else output_path.with_suffix(".spacing-report.json")

    payload = json.loads(input_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict) or not isinstance(payload.get("chapters"), list):
        raise ValueError("Input JSON must contain a chapters array.")

    payload, report = normalize_payload(
        payload,
        args.engine,
        args.strategy,
        args.sample_limit,
        args.recount_word_count,
        args.token_gap_check,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"chapters={report['chapters']}")
    print(f"engine={args.engine}")
    print(f"strategy={args.strategy}")
    print(f"before_thai_space_thai={report['before_totals'].get('thai_space_thai', 0)}")
    print(f"after_thai_space_thai={report['after_totals'].get('thai_space_thai', 0)}")
    print(f"examples={len(report['examples'])}")
    print(f"json={output_path}")
    print(f"report={report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
