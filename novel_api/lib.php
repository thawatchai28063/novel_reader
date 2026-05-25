<?php
declare(strict_types=1);

require_once __DIR__ . '/config.php';

function json_response(array $data, int $status = 200): never
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function read_json_body(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') {
        return [];
    }

    $data = json_decode($raw, true);
    if (!is_array($data)) {
        json_response(['ok' => false, 'error' => 'Invalid JSON body'], 400);
    }

    return $data;
}

function api_base_url(): string
{
    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
    $scriptDir = str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? '/novel_api/index.php'));
    $scriptDir = rtrim($scriptDir, '/');

    return $scheme . '://' . $host . ($scriptDir === '' ? '' : $scriptDir);
}

function cover_url(?string $coverPath): ?string
{
    $coverPath = trim((string) $coverPath);
    if ($coverPath === '') {
        return null;
    }
    if (preg_match('/^https?:\/\//i', $coverPath) === 1) {
        return $coverPath;
    }

    return api_base_url() . '/' . ltrim($coverPath, '/');
}

function find_pdftotext(): ?string
{
    foreach (PDFTOTEXT_PATHS as $path) {
        if ($path === 'pdftotext' || is_file($path)) {
            return $path;
        }
    }

    return null;
}

function extract_pdf_text(string $pdfPath): array
{
    if (!is_file($pdfPath)) {
        throw new RuntimeException('PDF file not found: ' . $pdfPath);
    }

    $tool = find_pdftotext();
    if ($tool === null) {
        throw new RuntimeException('pdftotext.exe not found. Install Poppler/Xpdf or Git for Windows.');
    }

    $temp = tempnam(sys_get_temp_dir(), 'novel_pdf_');
    if ($temp === false) {
        throw new RuntimeException('Cannot create temp file.');
    }

    $cmd = escapeshellarg($tool)
        . ' -layout -enc UTF-8 '
        . escapeshellarg($pdfPath)
        . ' '
        . escapeshellarg($temp);

    exec($cmd . ' 2>&1', $output, $exitCode);
    $text = is_file($temp) ? (string) file_get_contents($temp) : '';
    @unlink($temp);

    if ($exitCode !== 0 || trim($text) === '') {
        throw new RuntimeException('pdftotext failed: ' . implode("\n", $output));
    }

    return [
        'text' => normalize_text($text),
        'warnings' => detect_text_warnings($text),
    ];
}

function normalize_text(string $text): string
{
    $text = str_replace("\r\n", "\n", $text);
    $text = str_replace("\r", "\n", $text);
    $text = str_replace("\f", "\n", $text);
    $text = preg_replace('/[ \t]+\n/u', "\n", $text) ?? $text;
    $text = preg_replace('/\n{4,}/u', "\n\n\n", $text) ?? $text;

    return trim($text);
}

function detect_text_warnings(string $text): array
{
    $sample = mb_substr($text, 0, 5000, 'UTF-8');
    preg_match_all('/[\x{0E00}-\x{0E7F}]/u', $sample, $thai);
    preg_match_all('/[�\x{FFFD}]/u', $sample, $bad);

    $warnings = [];
    if (count($thai[0]) < 20) {
        $warnings[] = 'ไม่พบตัวอักษรไทยมากพอหลังถอด PDF ไฟล์นี้อาจใช้ฟอนต์เข้ารหัสพิเศษ ต้องใช้ OCR หรือไฟล์ข้อความต้นฉบับ';
    }
    if (count($bad[0]) > 5) {
        $warnings[] = 'พบอักขระเสียจำนวนมากจาก PDF';
    }

    return $warnings;
}

function split_chapters(string $text): array
{
    $text = normalize_text($text);
    $lines = explode("\n", $text);
    $markers = [];

    foreach ($lines as $index => $line) {
        $clean = trim($line);
        if ($clean === '') {
            continue;
        }

        if (preg_match('/^(?:ตอน(?:ที่)?|บท(?:ที่)?|chapter)\s*([0-9]{1,4})\s*[:：.\-]?\s*(.*)$/iu', $clean, $m)) {
            $markers[] = ['line' => $index, 'no' => (int) $m[1], 'title' => trim($m[2]), 'strict' => true];
            continue;
        }

        if (preg_match('/^([0-9]{1,4})\s*[:：]\s*(.+)$/u', $clean, $m)) {
            $markers[] = ['line' => $index, 'no' => (int) $m[1], 'title' => trim($m[2]), 'strict' => true];
            continue;
        }

        if (preg_match('/^([0-9]{1,4})\s+(\S.{2,})$/u', $clean, $m)) {
            $markers[] = ['line' => $index, 'no' => (int) $m[1], 'title' => trim($m[2]), 'strict' => false];
        }
    }

    $strictMarkers = array_values(array_filter($markers, fn (array $marker): bool => $marker['strict']));
    $laxMarkers = array_values(array_filter($markers, fn (array $marker): bool => !$marker['strict']));
    $existingNos = [];
    $deduped = [];
    $lastNo = 0;
    foreach ($strictMarkers as $marker) {
        if ($marker['no'] <= $lastNo || $marker['no'] > 9999) {
            continue;
        }
        $deduped[] = $marker;
        $existingNos[$marker['no']] = true;
        $lastNo = $marker['no'];
    }

    foreach ($laxMarkers as $marker) {
        if (isset($existingNos[$marker['no']])) {
            continue;
        }

        for ($i = 0; $i + 1 < count($deduped); $i++) {
            $before = $deduped[$i];
            $after = $deduped[$i + 1];
            if (
                $marker['line'] > $before['line']
                && $marker['line'] < $after['line']
                && $marker['no'] > $before['no']
                && $marker['no'] < $after['no']
            ) {
                $deduped[] = $marker;
                $existingNos[$marker['no']] = true;
                break;
            }
        }
    }

    usort($deduped, fn (array $a, array $b): int => $a['line'] <=> $b['line']);

    if (count($deduped) < 2) {
        return [[
            'chapter_no' => 1,
            'title' => 'ตอนที่ 1',
            'content' => $text,
            'word_count' => count_words($text),
        ]];
    }

    $chapters = [];
    $count = count($deduped);
    for ($i = 0; $i < $count; $i++) {
        $start = $deduped[$i]['line'];
        $end = $i + 1 < $count ? $deduped[$i + 1]['line'] : count($lines);
        $chunk = trim(implode("\n", array_slice($lines, $start, $end - $start)));
        $no = $deduped[$i]['no'];
        $title = $deduped[$i]['title'] !== '' ? $deduped[$i]['title'] : 'ตอนที่ ' . $no;

        $chapters[] = [
            'chapter_no' => $no,
            'title' => mb_substr($title, 0, 255, 'UTF-8'),
            'content' => $chunk,
            'word_count' => count_words($chunk),
        ];
    }

    return $chapters;
}

function count_words(string $text): int
{
    preg_match_all('/[\p{L}\p{N}]+/u', $text, $matches);
    return count($matches[0]);
}

function import_chapters(string $title, ?string $author, ?string $sourceName, array $chapters, ?string $coverPath = null): int
{
    $db = pdo();
    $db->beginTransaction();

    try {
        $stmt = $db->prepare('INSERT INTO novels (title, author, source_name, cover_path) VALUES (?, ?, ?, ?)');
        $stmt->execute([$title, $author, $sourceName, $coverPath]);
        $novelId = (int) $db->lastInsertId();

        $chapterStmt = $db->prepare(
            'INSERT INTO chapters (novel_id, chapter_no, title, content, word_count)
             VALUES (?, ?, ?, ?, ?)'
        );

        foreach ($chapters as $chapter) {
            $chapterStmt->execute([
                $novelId,
                $chapter['chapter_no'],
                $chapter['title'],
                $chapter['content'],
                $chapter['word_count'],
            ]);
        }

        $db->commit();
        return $novelId;
    } catch (Throwable $e) {
        $db->rollBack();
        throw $e;
    }
}
