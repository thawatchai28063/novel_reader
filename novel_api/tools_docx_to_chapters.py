from __future__ import annotations

import argparse
import html
import json
import re
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DOCX = Path(r"C:\Users\it-ae\Documents\PDFgear\Lord of the Mysteries ราชันย์เร้นลับ 001-100 conv.docx")
DEFAULT_OUTPUT = ROOT / "ocr_work" / "lord_of_mysteries_001_100.json"


PHRASE_REPLACEMENTS = [
    ("ราชนย์เรนลบ", "ราชันย์เร้นลับ"),
    ("ราชนยเรนลบ", "ราชันย์เร้นลับ"),
    ("าชนย์เรนลบ", "ราชันย์เร้นลับ"),
    ("าชนยเรนลบ", "ราชันย์เร้นลับ"),
    ("โจวหมงรย", "โจวหมิงรุ่ย"),
    ("หมงรย", "หมิงรุ่ย"),
    ("ทำไม่มีัน", "ทำไมมัน"),
    ("ทเปยม", "ที่เปี่ยม"),
    ("เสยก", "เสียง"),
    ("เพรยก", "เพรียก"),
    ("วฏจกร", "วัฏจักร"),
    ("เจดจรส", "เจ็ดจรัส"),
    ("ทกงหลบกงตน", "ที่กึ่งหลับกึ่งตื่น"),
    ("ตงสต", "ตั้งสติ"),
    ("กำลง", "กำลัง"),
    ("ไคลน", "ไคลน์"),
    ("เมลสซา", "เมลิสซา"),
    ("เบนสน", "เบ็นสัน"),
    ("ออเดรย", "ออเดรย์"),
    ("มอเรตต", "มอเร็ตติ"),
    ("ลโอนารด", "ลีโอนาร์ด"),
    ("รอสแซลล", "รอสแซลล์"),
    ("เฮเนส", "เฮเนส"),
    ("ซล", "ซูล"),
    ("เพนน", "เพนนี"),
    ("ปอนด", "ปอนด์"),
    ("ราชนย์", "ราชันย์"),
    ("เรนลบ", "เร้นลับ"),
    ("ผวเศษ", "ผู้วิเศษ"),
    ("ลทธ", "ลัทธิ"),
    ("นกาย", "นิกาย"),
    ("โอสถ", "โอสถ"),
    ("สตว", "สัตว์"),
    ("วตถ", "วัตถุ"),
    ("วญญาณ", "วิญญาณ"),
    ("พธกรรม", "พิธีกรรม"),
    ("ปรศนา", "ปริศนา"),
    ("สโมสร", "สโมสร"),
    ("สถานการณ", "สถานการณ์"),
    ("หนวย", "หน่วย"),
    ("ปฏบต", "ปฏิบัติ"),
    ("พเศษ", "พิเศษ"),
    ("ตนกาเนด", "ต้นกำเนิด"),
    ("สาเหต", "สาเหตุ"),
    ("สนข", "สุนัข"),
    ("ไลจบ", "ไล่จับ"),
    ("ไล่จับหน", "ไล่จับหนู"),
    ("หน ", "หนู "),
    ("ปลองไฟแดง", "ปล่องไฟแดง"),
    ("ตความ", "ตีความ"),
    ("มสเตอร", "มิสเตอร์"),
    ("อะซก", "อะซิก"),
    ("เครองราง", "เครื่องราง"),
    ("รานสมนไพร", "ร้านสมุนไพร"),
    ("สมนไพร", "สมุนไพร"),
    ("บานเชา", "บ้านเช่า"),
    ("พอบาน", "พ่อบ้าน"),
    ("คาบเรยน", "คาบเรียน"),
    ("คำทำนายดวงชะตา", "ทำนายดวงชะตา"),
    ("ท านายดวงชะตา", "ทำนายดวงชะตา"),
]


COMMON_REPLACEMENTS = [
    ("ท า", "ทำ"),
    ("ก า", "กำ"),
    ("ค า", "คำ"),
    ("จ า", "จำ"),
    ("ด า", "ดำ"),
    ("ต า", "ตำ"),
    ("ส า", "สำ"),
    ("น า", "นำ"),
    ("ล า", "ลำ"),
    ("แหง", "แห่ง"),
    ("อยาง", "อย่าง"),
    ("ดวย", "ด้วย"),
    ("ตอง", "ต้อง"),
    ("ขน", "ขึ้น"),
    ("ครง", "ครั้ง"),
    ("นง", "นั่ง"),
    ("นอง", "น้อง"),
    ("เรม", "เริ่ม"),
    ("เหน", "เห็น"),
    ("เปน", "เป็น"),
    ("กบ", "กับ"),
    ("รบ", "รับ"),
    ("กลบ", "กลับ"),
    ("มน", "มัน"),
    ("ตว", "ตัว"),
    ("หว", "หัว"),
    ("เสยง", "เสียง"),
    ("เรยก", "เรียก"),
    ("เพยง", "เพียง"),
    ("เดยว", "เดียว"),
    ("เกา", "เก่า"),
    ("ใหม", "ใหม่"),
    ("ไมได", "ไม่ได้"),
    ("ไมใช", "ไม่ใช่"),
    ("ไมคอย", "ไม่ค่อย"),
    ("ไมร", "ไม่รู้"),
    ("ไดรบ", "ได้รับ"),
    ("ไปไมได", "ไปไม่ได้"),
    ("เมอ", "เมื่อ"),
    ("เพอ", "เพื่อ"),
    ("เรอง", "เรื่อง"),
    ("เชน", "เช่น"),
    ("สวน", "ส่วน"),
    ("ถง", "ถึง"),
    ("ถก", "ถูก"),
    ("อกครง", "อีกครั้ง"),
    ("ตอนน", "ตอนนี้"),
    ("วนน", "วันนี้"),
    ("คนน", "คืนนี้"),
    ("สง", "สิ่ง"),
    ("ตาง", "ต่าง"),
    ("รางกาย", "ร่างกาย"),
    ("ฝน", "ฝัน"),
    ("เจบ", "เจ็บ"),
    ("ปวดหว", "ปวดหัว"),
    ("โตะ", "โต๊ะ"),
    ("ขอความ", "ข้อความ"),
    ("สมด", "สมุด"),
    ("หนงสอ", "หนังสือ"),
    ("กระดาษ", "กระดาษ"),
    ("บรษ", "บุรุษ"),
    ("ผหญง", "ผู้หญิง"),
    ("ผชาย", "ผู้ชาย"),
    ("ผปกครอง", "ผู้ปกครอง"),
    ("ผเชยวชาญ", "ผู้เชี่ยวชาญ"),
    ("ผภาวนา", "ผู้ภาวนา"),
    ("ผชวย", "ผู้ช่วย"),
    ("ผสดบ", "ผู้สดับ"),
    ("เสนทาง", "เส้นทาง"),
    ("ตำตอบ", "คำตอบ"),
    ("คาตอบ", "คำตอบ"),
    ("คาถาม", "คำถาม"),
    ("สญลกษณ", "สัญลักษณ์"),
    ("ปญหา", "ปัญหา"),
    ("ปจจบน", "ปัจจุบัน"),
    ("ปรากฏการณ", "ปรากฏการณ์"),
    ("ภารกจ", "ภารกิจ"),
    ("บนทก", "บันทึก"),
]


CHAPTER_RE = re.compile(
    r"^(?:ร?าชนยเรนลบ|ร?าชนย์เรนลบ|ร?าชนเรนลบ|ราชันย์เร้นลับ)\s*(\d{1,3})\s*[:：—\-]?\s*(.*)$"
)


def extract_docx_paragraphs(docx_path: Path) -> list[str]:
    with zipfile.ZipFile(docx_path) as archive:
        xml = archive.read("word/document.xml").decode("utf-8")

    paragraphs: list[str] = []
    for chunk in re.findall(r"<w:p\b.*?</w:p>", xml, flags=re.S):
        text = "".join(
            html.unescape(part)
            for part in re.findall(r"<w:t[^>]*>(.*?)</w:t>", chunk, flags=re.S)
        )
        text = normalize_spacing(text)
        if text:
            paragraphs.append(text)
    return paragraphs


def normalize_spacing(text: str) -> str:
    text = text.replace("\u00a0", " ")
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"\s+", " ", text)
    text = re.sub(r"\s+([,.;:!?])", r"\1", text)
    return text.strip()


def fix_text(text: str) -> str:
    fixed = normalize_spacing(text)
    for old, new in PHRASE_REPLACEMENTS:
        fixed = fixed.replace(old, new)
    for old, new in COMMON_REPLACEMENTS:
        fixed = fixed.replace(old, new)
    fixed = re.sub(r"([่้๊๋])\1+", r"\1", fixed)
    fixed = re.sub(r"\s+([”’])", r"\1", fixed)
    return fixed.strip()


def clean_heading_title(title: str, chapter_no: int) -> str:
    title = fix_text(title)
    duplicate = CHAPTER_RE.search(title)
    if duplicate and int(duplicate.group(1)) == chapter_no:
        title = fix_text(duplicate.group(2))
    if not title:
        title = f"ตอนที่ {chapter_no}"
    return title[:255]


def count_words(text: str) -> int:
    return len(re.findall(r"[\w\u0E00-\u0E7F]+", text, flags=re.UNICODE))


def split_chapters(paragraphs: list[str]) -> tuple[list[dict[str, object]], list[int]]:
    markers: list[tuple[int, int, str]] = []
    seen: set[int] = set()
    for index, paragraph in enumerate(paragraphs):
        match = CHAPTER_RE.match(paragraph)
        if not match:
            continue
        chapter_no = int(match.group(1))
        if chapter_no < 1 or chapter_no > 999 or chapter_no in seen:
            continue
        seen.add(chapter_no)
        markers.append((index, chapter_no, match.group(2)))

    markers.sort(key=lambda item: item[0])
    chapters: list[dict[str, object]] = []
    for marker_index, (start, chapter_no, raw_title) in enumerate(markers):
        end = markers[marker_index + 1][0] if marker_index + 1 < len(markers) else len(paragraphs)
        body_paragraphs = paragraphs[start + 1 : end]
        content = "\n\n".join(fix_text(paragraph) for paragraph in body_paragraphs if fix_text(paragraph))
        title = clean_heading_title(raw_title, chapter_no)
        chapters.append(
            {
                "chapter_no": chapter_no,
                "title": title,
                "content": content,
                "word_count": count_words(content),
            }
        )

    found = {int(chapter["chapter_no"]) for chapter in chapters}
    if found:
        expected = set(range(min(found), max(found) + 1))
        missing = sorted(expected - found)
    else:
        missing = []
    return chapters, missing


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", default=str(DEFAULT_DOCX))
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    args = parser.parse_args()

    docx_path = Path(args.input)
    output_path = Path(args.output)
    paragraphs = extract_docx_paragraphs(docx_path)
    chapters, missing = split_chapters(paragraphs)

    payload = {
        "title": "ราชันย์เร้นลับ",
        "source_name": docx_path.name + " + rule-based Thai cleanup",
        "chapters": chapters,
        "missing_chapters": missing,
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"wrote={output_path}")
    print(f"paragraphs={len(paragraphs)} chapters={len(chapters)} missing={missing}")
    if chapters:
        print(f"first={chapters[0]['chapter_no']} {chapters[0]['title']}")
        print(f"last={chapters[-1]['chapter_no']} {chapters[-1]['title']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
