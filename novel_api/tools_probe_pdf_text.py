from __future__ import annotations

import argparse
from pathlib import Path

from pypdf import PdfReader


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("pdf")
    parser.add_argument("needle")
    parser.add_argument("--limit", type=int, default=20)
    parser.add_argument("--head", type=int, default=16)
    args = parser.parse_args()

    reader = PdfReader(str(Path(args.pdf)))
    hits = 0
    for page_no, page in enumerate(reader.pages, start=1):
        text = page.extract_text() or ""
        if args.needle not in text:
            continue
        hits += 1
        print(f"PAGE {page_no}")
        print("\n".join(text.splitlines()[: args.head]).encode("unicode_escape").decode())
        if hits >= args.limit:
            break
    print(f"hits={hits}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
