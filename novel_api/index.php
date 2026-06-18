<?php
declare(strict_types=1);

require_once __DIR__ . '/lib.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

$action = $_GET['action'] ?? 'status';

function audio_clip_key(int $first, int $last): string
{
    return $first . ':' . $last;
}

function default_audio_path(int $novelId, int $first, int $last): string
{
    return sprintf('audio/novel_%d/chapters_%04d_%04d.mp3', $novelId, $first, $last);
}

function local_media_path(string $relativePath): ?string
{
    $relativePath = str_replace('\\', '/', trim($relativePath));
    $relativePath = ltrim($relativePath, '/');
    if (
        $relativePath === ''
        || str_contains($relativePath, '..')
        || preg_match('/^[a-z]:/i', $relativePath) === 1
    ) {
        return null;
    }

    return __DIR__ . '/' . $relativePath;
}

function stream_audio_file(string $path): never
{
    $size = filesize($path);
    if ($size === false || $size <= 0) {
        json_response(['ok' => false, 'error' => 'Audio file is empty'], 404);
    }

    $handle = fopen($path, 'rb');
    if ($handle === false) {
        json_response(['ok' => false, 'error' => 'Cannot open audio file'], 500);
    }

    $start = 0;
    $end = $size - 1;
    $status = 200;
    $range = $_SERVER['HTTP_RANGE'] ?? '';

    if (is_string($range) && preg_match('/bytes=(\d*)-(\d*)/i', $range, $matches) === 1) {
        $status = 206;
        if ($matches[1] === '' && $matches[2] !== '') {
            $suffixLength = (int) $matches[2];
            $start = max(0, $size - $suffixLength);
        } else {
            $start = $matches[1] === '' ? 0 : (int) $matches[1];
            $end = $matches[2] === '' ? $end : (int) $matches[2];
        }

        if ($start > $end || $start >= $size) {
            http_response_code(416);
            header('Content-Range: bytes */' . $size);
            exit;
        }

        $end = min($end, $size - 1);
    }

    $length = $end - $start + 1;
    http_response_code($status);
    $extension = strtolower(pathinfo($path, PATHINFO_EXTENSION));
    $contentType = match ($extension) {
        'wav' => 'audio/wav',
        'm4a' => 'audio/mp4',
        default => 'audio/mpeg',
    };
    header('Content-Type: ' . $contentType);
    header('Content-Length: ' . $length);
    header('Accept-Ranges: bytes');
    header('Cache-Control: public, max-age=86400');
    if ($status === 206) {
        header(sprintf('Content-Range: bytes %d-%d/%d', $start, $end, $size));
    }

    fseek($handle, $start);
    $remaining = $length;
    while ($remaining > 0 && !feof($handle)) {
        $chunk = fread($handle, min(8192, $remaining));
        if ($chunk === false || $chunk === '') {
            break;
        }
        echo $chunk;
        $remaining -= strlen($chunk);
        flush();
    }
    fclose($handle);
    exit;
}

try {
    if ($action === 'status') {
        $db = pdo();
        $db->query('SELECT 1');
        json_response([
            'ok' => true,
            'service' => 'novel_api',
            'pdftotext_found' => find_pdftotext() !== null,
        ]);
    }

    if ($action === 'novels') {
        $rows = pdo()->query(
            'SELECT n.id, n.title, n.author, n.source_name, n.cover_path, n.created_at, COUNT(c.id) AS chapter_count
             FROM novels n
             LEFT JOIN chapters c ON c.novel_id = n.id
             GROUP BY n.id
             ORDER BY n.created_at DESC'
        )->fetchAll();
        foreach ($rows as &$row) {
            $row['cover_url'] = cover_url($row['cover_path'] ?? null);
        }
        unset($row);
        json_response(['ok' => true, 'data' => $rows]);
    }

    if ($action === 'chapters') {
        $novelId = (int) ($_GET['novel_id'] ?? 0);
        if ($novelId <= 0) {
            json_response(['ok' => false, 'error' => 'novel_id is required'], 400);
        }
        $stmt = pdo()->prepare(
            'SELECT id, novel_id, chapter_no, title, word_count
             FROM chapters
             WHERE novel_id = ?
             ORDER BY chapter_no ASC'
        );
        $stmt->execute([$novelId]);
        json_response(['ok' => true, 'data' => $stmt->fetchAll()]);
    }

    if ($action === 'audio_clips') {
        $novelId = (int) ($_GET['novel_id'] ?? 0);
        if ($novelId <= 0) {
            json_response(['ok' => false, 'error' => 'novel_id is required'], 400);
        }

        $db = pdo();
        $stmt = $db->prepare(
            'SELECT chapter_no, title
             FROM chapters
             WHERE novel_id = ?
             ORDER BY chapter_no ASC'
        );
        $stmt->execute([$novelId]);
        $chapters = $stmt->fetchAll();
        $audioStmt = $db->prepare(
            'SELECT first_chapter_no, last_chapter_no, title, audio_path, provider, file_size
             FROM audio_clips
             WHERE novel_id = ?'
        );
        $audioStmt->execute([$novelId]);
        $registeredClips = [];
        foreach ($audioStmt->fetchAll() as $registeredClip) {
            $registeredClips[audio_clip_key((int) $registeredClip['first_chapter_no'], (int) $registeredClip['last_chapter_no'])] = $registeredClip;
        }

        $groups = array_chunk($chapters, 10);
        $clips = [];
        foreach ($groups as $index => $group) {
            if (count($group) === 0) {
                continue;
            }
            $first = (int) $group[0]['chapter_no'];
            $last = (int) $group[count($group) - 1]['chapter_no'];
            $registeredClip = $registeredClips[audio_clip_key($first, $last)] ?? null;
            $relativePath = default_audio_path($novelId, $first, $last);
            if ($registeredClip && is_string($registeredClip['audio_path']) && $registeredClip['audio_path'] !== '') {
                $relativePath = $registeredClip['audio_path'];
            }
            $absolutePath = local_media_path($relativePath);
            $exists = $absolutePath !== null && is_file($absolutePath);
            $fileSize = $exists ? (filesize($absolutePath) ?: 0) : 0;
            $audioUrl = api_base_url() . '/index.php?' . http_build_query([
                'action' => 'audio_file',
                'novel_id' => $novelId,
                'first' => $first,
                'last' => $last,
            ]);
            $clips[] = [
                'index' => $index + 1,
                'title' => sprintf('เสียงตอน %d-%d', $first, $last),
                'first_chapter' => $first,
                'last_chapter' => $last,
                'chapter_count' => count($group),
                'exists' => $exists,
                'audio_url' => $exists ? $audioUrl : null,
                'provider' => $registeredClip['provider'] ?? null,
                'file_size' => $registeredClip['file_size'] ?? $fileSize,
            ];
        }

        json_response(['ok' => true, 'data' => $clips]);
    }

    if ($action === 'audio_file') {
        $novelId = (int) ($_GET['novel_id'] ?? 0);
        $first = (int) ($_GET['first'] ?? 0);
        $last = (int) ($_GET['last'] ?? 0);
        if ($novelId <= 0 || $first <= 0 || $last < $first) {
            json_response(['ok' => false, 'error' => 'Audio file not found'], 404);
        }

        $relativePath = default_audio_path($novelId, $first, $last);
        $stmt = pdo()->prepare(
            'SELECT audio_path
             FROM audio_clips
             WHERE novel_id = ? AND first_chapter_no = ? AND last_chapter_no = ?
             LIMIT 1'
        );
        $stmt->execute([$novelId, $first, $last]);
        $registeredClip = $stmt->fetch();
        if ($registeredClip && is_string($registeredClip['audio_path']) && $registeredClip['audio_path'] !== '') {
            $relativePath = $registeredClip['audio_path'];
        }

        $path = local_media_path($relativePath);
        if ($path === null || !is_file($path)) {
            json_response(['ok' => false, 'error' => 'Audio file not found'], 404);
        }
        stream_audio_file($path);
    }

    if ($action === 'chapter') {
        $id = (int) ($_GET['id'] ?? 0);
        if ($id <= 0) {
            json_response(['ok' => false, 'error' => 'id is required'], 400);
        }
        $stmt = pdo()->prepare(
            'SELECT id, novel_id, chapter_no, title, content, word_count
             FROM chapters
             WHERE id = ?'
        );
        $stmt->execute([$id]);
        $row = $stmt->fetch();
        if (!$row) {
            json_response(['ok' => false, 'error' => 'Chapter not found'], 404);
        }
        json_response(['ok' => true, 'data' => $row]);
    }

    if ($action === 'import_text' && $_SERVER['REQUEST_METHOD'] === 'POST') {
        $body = read_json_body();
        $title = trim((string) ($body['title'] ?? 'นิยายไม่มีชื่อ'));
        $author = isset($body['author']) ? trim((string) $body['author']) : null;
        $text = (string) ($body['text'] ?? '');
        if (trim($text) === '') {
            json_response(['ok' => false, 'error' => 'text is required'], 400);
        }

        $warnings = detect_text_warnings($text);
        $chapters = split_chapters($text);
        $novelId = import_chapters($title, $author, 'text import', $chapters);
        json_response([
            'ok' => true,
            'novel_id' => $novelId,
            'chapter_count' => count($chapters),
            'warnings' => $warnings,
        ]);
    }

    if ($action === 'import_pdf_path' && $_SERVER['REQUEST_METHOD'] === 'POST') {
        $body = read_json_body();
        $pdfPath = trim((string) ($body['pdf_path'] ?? ''));
        $title = trim((string) ($body['title'] ?? pathinfo($pdfPath, PATHINFO_FILENAME)));
        $author = isset($body['author']) ? trim((string) $body['author']) : null;
        if ($pdfPath === '') {
            json_response(['ok' => false, 'error' => 'pdf_path is required'], 400);
        }

        $result = extract_pdf_text($pdfPath);
        $chapters = split_chapters($result['text']);
        $novelId = import_chapters($title, $author, basename($pdfPath), $chapters);
        json_response([
            'ok' => true,
            'novel_id' => $novelId,
            'chapter_count' => count($chapters),
            'warnings' => $result['warnings'],
        ]);
    }

    if ($action === 'import_pdf_upload' && $_SERVER['REQUEST_METHOD'] === 'POST') {
        if (!isset($_FILES['pdf']) || $_FILES['pdf']['error'] !== UPLOAD_ERR_OK) {
            json_response(['ok' => false, 'error' => 'pdf upload is required'], 400);
        }

        $title = trim((string) ($_POST['title'] ?? pathinfo($_FILES['pdf']['name'], PATHINFO_FILENAME)));
        $author = isset($_POST['author']) ? trim((string) $_POST['author']) : null;
        $result = extract_pdf_text($_FILES['pdf']['tmp_name']);
        $chapters = split_chapters($result['text']);
        $novelId = import_chapters($title, $author, $_FILES['pdf']['name'], $chapters);
        json_response([
            'ok' => true,
            'novel_id' => $novelId,
            'chapter_count' => count($chapters),
            'warnings' => $result['warnings'],
        ]);
    }

    json_response(['ok' => false, 'error' => 'Unknown action'], 404);
} catch (Throwable $e) {
    json_response(['ok' => false, 'error' => $e->getMessage()], 500);
}
