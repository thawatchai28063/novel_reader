from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


READINGS = {
    "Three Great Civilized Lands": "ธรีเกรตซิวิไลซ์แลนด์ส",
    "Great Orient": "เกรตโอเรียนต์",
    "Qua-Toyne": "ควา-ทอยน์",
    "QuaToyne": "ควา-ทอยน์",
    "Qua Toyne": "ควา-ทอยน์",
    "JMSDF": "เจเอ็มเอสดีเอฟ",
    "JGSDF": "เจจีเอสดีเอฟ",
    "JASDF": "เจเอเอสดีเอฟ",
    "JSDF": "เจเอสดีเอฟ",
    "GSDF": "จีเอสดีเอฟ",
    "MSDF": "เอ็มเอสดีเอฟ",
    "SDF": "เอสดีเอฟ",
    "Mirishial": "มิริเชียล",
    "Mirishials": "มิริเชียลส์",
    "Valkan": "วัลกัน",
    "Valkans": "วัลกันส์",
    "Valkas": "วัลกัส",
    "Louria": "ลูเรีย",
    "Lourian": "ลูเรียน",
    "Parpaldia": "พาร์พัลเดีย",
    "Parpaldian": "พาร์พัลเดียน",
    "Parpaldians": "พาร์พัลเดียนส์",
    "Leifor": "ไลฟอร์",
    "Leiforia": "ไลฟอเรีย",
    "Leiforian": "ไลฟอเรียน",
    "Cartalpas": "คาร์ทัลพัส",
    "Rodenius": "โรเดเนียส",
    "Quila": "ควิลา",
    "Fenn": "เฟนน์",
    "Fennese": "เฟนเนส",
    "Topa": "โทปา",
    "Topan": "โทปัน",
    "Altaras": "อัลทารัส",
    "Altaran": "อัลทารัน",
    "Annonrial": "แอนนอนเรียล",
    "Annonrials": "แอนนอนเรียลส์",
    "Irnetia": "เออร์เนเทีย",
    "Irnetian": "เออร์เนเทียน",
    "Irnetians": "เออร์เนเทียนส์",
    "Ravernal": "ราเวอร์นัล",
    "Runepolis": "รูนโพลิส",
    "Mu": "มู",
    "Otaheit": "โอตาไฮต์",
    "Duro": "ดูโร",
    "Ethirant": "เอธีแรนต์",
    "Remille": "เรมีล",
    "Myrus": "ไมรัส",
    "Meteos": "เมเทออส",
    "Kaios": "ไคออส",
    "Kai": "ไค",
    "Kasami": "คาซามิ",
    "Zabir": "ซาบีร์",
    "Cey": "เซย์",
    "Mykal": "ไมคัล",
    "Galeos": "กาเลออส",
    "Kielcek": "คีลเช็ค",
    "Saffine": "แซฟฟีน",
    "Philades": "ฟิลาเดส",
    "Lumies": "ลูมีส",
    "Kenshiva": "เคนชิวา",
    "Grameus": "กราเมอุส",
    "Cielia": "ซีเลีย",
    "Atlasstar": "แอทลาสตาร์",
    "Atlastar": "แอทลาสตาร์",
    "Antares": "แอนทาเรส",
    "Alue": "อาลูเอ",
    "Ludius": "ลูเดียส",
    "Luxtal": "ลักซ์ทัล",
    "Daxild": "แด็กซิลด์",
    "Orlaxle": "ออร์แลกซ์",
    "Luca": "ลูกา",
    "Marin": "มาริน",
    "Arde": "อาร์เด",
    "Goruaus": "โกรูอัส",
    "Patagene": "พาทาจีน",
    "Dohbai": "โดห์ไบ",
    "Gim": "กิม",
    "Rettal": "เร็ตทัล",
    "Yagou": "ยาโก",
    "Justide": "จัสไทด์",
    "Ejei": "เอเจย์",
    "Sigrant": "ซิแกรนต์",
    "Kijje": "คิจเจ",
    "Eimor": "ไอมอร์",
    "Kasai": "คาซาอิ",
    "Liage": "ลีอาจ",
    "Minilar": "มินิลาร์",
    "Elpacio": "เอลปาซิโอ",
    "Magicaraich": "เมจิคาไรช์",
    "Kaonia": "คาโอเนีย",
    "Lydolka": "ลีดอลกา",
    "Zelim": "เซลิม",
    "Naguano": "นากัวโน",
    "Algethi": "อัลเกธี",
    "Cabal": "คาบาล",
    "Sius": "ไซอัส",
    "Adem": "อาเด็ม",
    "Nizuel": "นีซูเอล",
    "Paganda": "พากันดา",
    "Tormeus": "ทอร์เมอุส",
    "Nigrat": "นิกรัต",
    "Haag": "ฮาก",
    "Kooze": "คูเซ",
    "Riem": "รีเอม",
    "Arcaon": "อาร์คาออน",
    "Agartha": "อการ์ธา",
    "Mareja": "มาเรจา",
    "Ranzall": "รันซอล",
    "Aruni": "อารูนี",
    "Siwalf": "ซีวาล์ฟ",
    "Lyka": "ไลกา",
    "Gauguer": "เกาเกอร์",
    "Sharkun": "ชาร์คุน",
    "Lassan": "ลัสซัน",
    "Gralux": "กราลักซ์",
    "Magearchy": "เมจิอาร์คี",
    "Meisa": "เมซา",
    "Heiskanen": "ไฮสกาเนน",
    "Zamenhof": "ซาเมนฮอฟ",
    "Lilceide": "ลิลเซด",
    "Baltica": "บอลติกา",
    "Guradoah": "กูราโดอาห์",
    "Arneus": "อาร์เนอุส",
    "Phillame": "ฟิลลาเม",
    "Latan": "ลาทัน",
    "Colebrand": "โคลแบรนด์",
    "Ilkanresis": "อิลคานเรซิส",
    "Astalte": "แอสตัลเต",
    "Brias": "ไบรอัส",
    "Ryal": "ไรอัล",
    "Asada": "อาซาดะ",
    "Oka": "โอกะ",
    "Viri": "วิริ",
    "Valkyries": "วาลคิรีส์",
    "Wyvern": "ไวเวิร์น",
    "Wyverns": "ไวเวิร์นส์",
    "Chimera": "คิเมรา",
    "Nosgorath": "นอสโกราธ",
    "Malastras": "มาลาสตราส",
    "Ogre": "โอเกอร์",
    "Dragon": "ดรากอน",
    "Dragoon": "ดรากูน",
    "Demon": "ดีมอน",
    "Lord": "ลอร์ด",
    "Lords": "ลอร์ดส์",
    "God": "ก็อด",
    "Holy": "โฮลี",
    "Divine": "ดิไวน์",
    "Empire": "เอ็มไพร์",
    "Imperial": "อิมพีเรียล",
    "Kingdom": "คิงดอม",
    "Alliance": "อัลไลแอนซ์",
    "Civilization": "ซิวิไลเซชัน",
    "Navy": "เนวี",
    "Fleet": "ฟลีต",
    "Army": "อาร์มี",
    "Force": "ฟอร์ซ",
    "Defense": "ดีเฟนซ์",
    "Science": "ไซเอนซ์",
    "Magic": "เมจิก",
    "Magicaraich": "เมจิคาไรช์",
    "Summons": "ซัมมอนส์",
    "Japan": "เจแปน",
    "Nihonkoku": "นิฮงโคคุ",
    "Shoukan": "โชคัง",
}


def add_readings_to_content(text: str) -> str:
    seen: set[str] = set()
    items = sorted(READINGS.items(), key=lambda item: len(item[0]), reverse=True)

    for term, reading in items:
        pattern = re.compile(rf"(?<![A-Za-z]){re.escape(term)}(?![A-Za-z])")

        def replace(match: re.Match[str]) -> str:
            end = match.end()
            if text[end : end + 1] == "(":
                return match.group(0)
            key = term.lower()
            if key in seen:
                return match.group(0)
            seen.add(key)
            return f"{match.group(0)}({reading})"

        text = pattern.sub(replace, text)

    return text


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_json")
    parser.add_argument("output_json")
    args = parser.parse_args()

    payload: dict[str, Any] = json.loads(Path(args.input_json).read_text(encoding="utf-8"))
    changed = 0
    for chapter in payload.get("chapters", []):
        content = str(chapter.get("content", ""))
        updated = add_readings_to_content(content)
        if updated != content:
            chapter["content"] = updated
            changed += 1

    out = Path(args.output_json)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"chapters={len(payload.get('chapters', []))}")
    print(f"changed={changed}")
    print(f"json={out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
