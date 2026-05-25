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
        $stmt = pdo()->prepare(
            'SELECT id, novel_id, chapter_no, title, word_count
             FROM chapters
             WHERE novel_id = ?
             ORDER BY chapter_no ASC'
        );
        $stmt->execute([$novelId]);
        json_response(['ok' => true, 'data' => $stmt->fetchAll()]);
    }

    if ($action === 'chapter') {
        $id = (int) ($_GET['id'] ?? 0);
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
