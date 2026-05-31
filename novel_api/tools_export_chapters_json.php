<?php
declare(strict_types=1);

require_once __DIR__ . '/lib.php';

if (PHP_SAPI !== 'cli') {
    echo "CLI only\n";
    exit(1);
}

$novelId = isset($argv[1]) ? (int) $argv[1] : 0;
$outPath = $argv[2] ?? '';

if ($novelId <= 0 || $outPath === '') {
    echo "Usage: php tools_export_chapters_json.php <novel-id> <output-json>\n";
    exit(1);
}

$db = pdo();
$novelStmt = $db->prepare('SELECT id, title, source_name, cover_path FROM novels WHERE id = ?');
$novelStmt->execute([$novelId]);
$novel = $novelStmt->fetch();

if (!$novel) {
    echo "Novel not found: {$novelId}\n";
    exit(1);
}

$chapterStmt = $db->prepare(
    'SELECT chapter_no, title, content, word_count
     FROM chapters
     WHERE novel_id = ?
     ORDER BY chapter_no'
);
$chapterStmt->execute([$novelId]);

$payload = [
    'title' => (string) $novel['title'],
    'source_name' => (string) $novel['source_name'],
    'cover_path' => (string) ($novel['cover_path'] ?? ''),
    'chapters' => $chapterStmt->fetchAll(),
];

$dir = dirname($outPath);
if ($dir !== '.' && !is_dir($dir)) {
    mkdir($dir, 0777, true);
}

file_put_contents(
    $outPath,
    json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT)
);

echo "Exported novel_id={$novelId}, chapters=" . count($payload['chapters']) . ", json={$outPath}\n";
