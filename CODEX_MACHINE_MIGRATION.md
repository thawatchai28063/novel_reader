# Codex machine migration handoff

ไฟล์นี้ทำไว้ให้ Codex/ผู้พัฒนาย้ายโปรเจกต์ `novel_reader` ไปเครื่องใหม่ได้เร็ว โดยไม่ต้องไล่ความจำจากแชตเดิมทั้งหมด

อัปเดตล่าสุด: 2026-06-16

## Repo

- GitHub: `https://github.com/thawatchai28063/novel_reader.git`
- โฟลเดอร์เดิมบนเครื่องนี้: `C:\Users\it-ae\Documents\Codex\2026-05-24\files-mentioned-by-the-user-1`
- Flutter app: `novel_reader_app`
- PHP API: `novel_api`
- MySQL database: `novel_reader`
- XAMPP live API path: `C:\xampp\htdocs\novel_api`
- XAMPP live audio path: `C:\xampp\htdocs\novel_api\audio`

## สิ่งที่ต้องติดตั้งบนเครื่องใหม่

1. Git
2. Flutter/Dart
3. Android SDK + platform-tools
4. XAMPP หรือ Apache + PHP + MySQL/MariaDB
5. VS Code

ค่าปัจจุบันของเครื่องเดิม:

- Android SDK: `C:\Android`
- Flutter SDK: `C:\develop\flutter_windows_3.35.5-stable\flutter`
- Dart SDK constraint ในแอป: `^3.9.2`
- Flutter dependencies หลัก: `http`, `just_audio`

## Clone repo

```powershell
cd C:\Users\it-ae\Documents\Codex
git clone https://github.com/thawatchai28063/novel_reader.git
cd novel_reader
```

ถ้าใช้โฟลเดอร์อื่นได้ แต่ให้ปรับ path ในคำสั่งด้านล่างตามจริง

## Restore PHP API ไป XAMPP

คัดลอกโฟลเดอร์ API จาก repo ไปที่ htdocs:

```powershell
Copy-Item -LiteralPath .\novel_api -Destination C:\xampp\htdocs\novel_api -Recurse -Force
```

เปิด XAMPP:

```powershell
Start-Process -FilePath C:\xampp\xampp-control.exe
```

หรือเปิด Apache/MySQL ผ่าน XAMPP Control Panel

เช็ก API:

```powershell
Invoke-RestMethod "http://localhost/novel_api/index.php?action=novels"
```

## Restore MySQL database

สร้างฐานข้อมูล:

```powershell
C:\xampp\mysql\bin\mysql.exe -u root -e "CREATE DATABASE IF NOT EXISTS novel_reader CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

import schema:

```powershell
C:\xampp\mysql\bin\mysql.exe -u root novel_reader < .\novel_api\schema.sql
```

ถ้ามีไฟล์ dump เต็ม เช่น `novel_reader_full.sql` ให้ import ทับ:

```powershell
C:\xampp\mysql\bin\mysql.exe --default-character-set=utf8mb4 -u root novel_reader < C:\path\to\novel_reader_full.sql
```

export DB จากเครื่องเดิมก่อนย้าย:

```powershell
C:\xampp\mysql\bin\mysqldump.exe --default-character-set=utf8mb4 -u root novel_reader > C:\Users\it-ae\Documents\Codex\novel_reader_full.sql
```

หมายเหตุ: ตอนสร้างไฟล์นี้ MySQL บนเครื่องเดิมไม่ได้เปิดอยู่ จึง query สถานะล่าสุดสด ๆ ไม่ได้

## Backup/restore ไฟล์เสียง

ไฟล์เสียงมีขนาดใหญ่ จึงไม่ควรใส่ git ให้ backup แยกจาก repo

ตำแหน่งใช้งานจริง:

```text
C:\xampp\htdocs\novel_api\audio
```

สถานะขนาดไฟล์เสียงที่พบล่าสุดบนเครื่องเดิม:

```text
novel_3  47 files  5.33 GB
novel_4   1 file   0.01 GB
novel_5   1 file   0.01 GB
novel_6   1 file   0.01 GB
novel_7   1 file   0.01 GB
novel_8  36 files  3.57 GB
```

backup ไป external drive:

```powershell
robocopy C:\xampp\htdocs\novel_api\audio D:\novel_reader_backup\audio /E
```

restore กลับเครื่องใหม่:

```powershell
robocopy D:\novel_reader_backup\audio C:\xampp\htdocs\novel_api\audio /E
```

## Flutter app setup

```powershell
cd .\novel_reader_app
flutter pub get
flutter analyze
flutter build apk
```

APK หลัง build:

```text
novel_reader_app\build\app\outputs\flutter-apk\app-release.apk
```

copy APK ไป Downloads:

```powershell
Copy-Item -LiteralPath .\build\app\outputs\flutter-apk\app-release.apk -Destination C:\Users\it-ae\Downloads\novel_reader_app-release.apk -Force
```

ติดตั้งบนมือถือที่เสียบ USB:

```powershell
flutter devices
flutter install -d <device-id>
```

หรือใช้ ADB:

```powershell
C:\Android\platform-tools\adb.exe install -r -d .\build\app\outputs\flutter-apk\app-release.apk
```

device เดิมที่เคยใช้:

```text
2407FPN8EG / UWY9BMVWPZDMHEMR / Android 16
```

ถ้าเจอ `INSTALL_FAILED_USER_RESTRICTED` ให้กดอนุญาตติดตั้งผ่าน USB บนมือถือก่อน

## API base URL ของแอป

ใน `novel_reader_app/lib/main.dart` มีค่า default:

```text
http://172.24.13.204/novel_api/index.php
```

บนเครื่องใหม่ IP อาจเปลี่ยน ให้ build แบบกำหนด API เอง:

```powershell
flutter build apk --dart-define=API_BASE_URL=http://<PC-IP>/novel_api/index.php
```

ตัวอย่าง:

```powershell
flutter build apk --dart-define=API_BASE_URL=http://192.168.1.20/novel_api/index.php
```

มือถือและ PC ต้องอยู่ network เดียวกัน และ Windows Firewall ต้องอนุญาต Apache

## เรื่อง/ข้อมูลสำคัญที่เคยทำ

- `กระบี่จงมา! ภาค 1 นกกระจอกในกรง` มีเสียงครบ 36 คลิป
- `เจ้าของร้านพิศวง` มีเสียงครบ 46 คลิปตอนที่หยุดงาน
- `ราชันย์เร้นลับ` ในฐานข้อมูลเดิมเคยพบว่ามีตอนหาย 49 ตอน:
  - `305`
  - `313-317`
  - `319`
  - `341-345`
  - `349-384`
  - `603`
- ไฟล์เสียง local TTS เป็น WAV ขนาดใหญ่ ถ้าจะทำต่อควรแปลงเป็น MP3 หรือใช้ pipeline ที่บีบอัดก่อนนำเข้า

## ไฟล์/โฟลเดอร์ที่ไม่ควรใส่ git

- `C:\xampp\htdocs\novel_api\audio`
- ไฟล์ DB dump ขนาดใหญ่
- ไฟล์ PDF ต้นฉบับนิยาย
- OCR temp/output
- Flutter build output
- Gradle cache
- Python dependency folders เช่น `pydeps*`

## Checklist ให้ Codex เครื่องใหม่เริ่มงาน

1. อ่านไฟล์นี้ก่อน
2. `git status`
3. เปิด XAMPP Apache/MySQL
4. import DB schema/dump
5. restore `audio`
6. เช็ก `http://localhost/novel_api/index.php?action=novels`
7. ตั้ง `API_BASE_URL` ให้ตรง IP เครื่องใหม่
8. `flutter pub get`
9. `flutter analyze`
10. `flutter build apk`
11. ติดตั้ง APK ลงมือถือ

## คำเตือน

- อย่าลบไฟล์เสียงใน XAMPP ถ้ายังต้องใช้ฟังในแอป
- อย่า commit ไฟล์เสียงหรือ PDF ขนาดใหญ่ขึ้น GitHub
- ถ้า build ติด Gradle download ให้เช็ก `novel_reader_app/android/gradle/wrapper/gradle-wrapper.properties`
- ถ้า API ในมือถือโหลดไม่ขึ้น ให้เช็ก IP, Apache, Firewall, และว่ามือถืออยู่ Wi-Fi เดียวกับ PC
