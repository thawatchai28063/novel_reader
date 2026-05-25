<?php
declare(strict_types=1);

require_once __DIR__ . '/lib.php';

if (PHP_SAPI !== 'cli') {
    echo "CLI only\n";
    exit(1);
}

$jsonPath = $argv[1] ?? '';
$novelId = isset($argv[2]) ? (int) $argv[2] : 0;

if ($jsonPath === '' || !is_file($jsonPath)) {
    echo "Usage: php tools_import_chapters_json.php <chapters-json> [existing-novel-id]\n";
    exit(1);
}

$payload = json_decode((string) file_get_contents($jsonPath), true);
if (!is_array($payload) || !isset($payload['chapters']) || !is_array($payload['chapters'])) {
    echo "Invalid chapters JSON\n";
    exit(1);
}

$title = trim((string) ($payload['title'] ?? 'นิยายไม่มีชื่อ'));
$sourceName = trim((string) ($payload['source_name'] ?? basename($jsonPath)));
$chapters = $payload['chapters'];
$db = pdo();
$db->beginTransaction();

try {
    if ($novelId > 0) {
        $stmt = $db->prepare('UPDATE novels SET title = ?, source_name = ? WHERE id = ?');
        $stmt->execute([$title, $sourceName, $novelId]);
        $stmt = $db->prepare('DELETE FROM chapters WHERE novel_id = ?');
        $stmt->execute([$novelId]);
    } else {
        $stmt = $db->prepare('INSERT INTO novels (title, source_name) VALUES (?, ?)');
        $stmt->execute([$title, $sourceName]);
        $novelId = (int) $db->lastInsertId();
    }

    $stmt = $db->prepare(
        'INSERT INTO chapters (novel_id, chapter_no, title, content, word_count)
         VALUES (?, ?, ?, ?, ?)'
    );

    foreach ($chapters as $chapter) {
        $content = (string) ($chapter['content'] ?? '');
        $wordCount = (int) ($chapter['word_count'] ?? count_words($content));
        $stmt->execute([
            $novelId,
            (int) $chapter['chapter_no'],
            mb_substr((string) $chapter['title'], 0, 255, 'UTF-8'),
            $content,
            $wordCount,
        ]);
    }

    $db->commit();
    echo "Imported novel_id={$novelId}, chapters=" . count($chapters) . PHP_EOL;
    if (!empty($payload['missing_chapters'])) {
        echo "Missing chapters: " . implode(',', $payload['missing_chapters']) . PHP_EOL;
    }
} catch (Throwable $e) {
    $db->rollBack();
    fwrite(STDERR, 'Import failed: ' . $e->getMessage() . PHP_EOL);
    exit(1);
}
