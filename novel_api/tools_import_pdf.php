<?php
declare(strict_types=1);

require_once __DIR__ . '/lib.php';

if (PHP_SAPI !== 'cli') {
    echo "CLI only\n";
    exit(1);
}

$pdfPath = $argv[1] ?? '';
$title = $argv[2] ?? pathinfo($pdfPath, PATHINFO_FILENAME);
$author = $argv[3] ?? null;

if ($pdfPath === '') {
    echo "Usage: php tools_import_pdf.php <pdf-path> [title] [author]\n";
    exit(1);
}

try {
    $result = extract_pdf_text($pdfPath);
    $chapters = split_chapters($result['text']);
    $novelId = import_chapters($title, $author, basename($pdfPath), $chapters);

    echo "Imported novel_id={$novelId}, chapters=" . count($chapters) . PHP_EOL;
    foreach ($result['warnings'] as $warning) {
        echo "Warning: {$warning}" . PHP_EOL;
    }
} catch (Throwable $e) {
    fwrite(STDERR, 'Import failed: ' . $e->getMessage() . PHP_EOL);
    exit(1);
}
