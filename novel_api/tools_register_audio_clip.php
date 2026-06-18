<?php
declare(strict_types=1);

require __DIR__ . '/config.php';

if ($argc < 4) {
    fwrite(STDERR, "Usage: php tools_register_audio_clip.php <novel_id> <first_chapter_no> <last_chapter_no> [provider]\n");
    exit(1);
}

$novelId = (int) $argv[1];
$first = (int) $argv[2];
$last = (int) $argv[3];
$provider = $argv[4] ?? 'edge-tts';

if ($novelId <= 0 || $first < 0 || $last < $first) {
    fwrite(STDERR, "Invalid novel/chapter range\n");
    exit(1);
}

$relativePath = '';
$absolutePath = '';
foreach (['wav', 'mp3', 'm4a'] as $extension) {
    $candidateRelative = sprintf('audio/novel_%d/chapters_%04d_%04d.%s', $novelId, $first, $last, $extension);
    $candidateAbsolute = __DIR__ . '/' . $candidateRelative;
    if (is_file($candidateAbsolute)) {
        $relativePath = $candidateRelative;
        $absolutePath = $candidateAbsolute;
        break;
    }
}

if ($relativePath === '' || $absolutePath === '') {
    fwrite(STDERR, "Audio file not found for chapters {$first}-{$last}\n");
    exit(1);
}

$db = pdo();
$db->exec(
    'CREATE TABLE IF NOT EXISTS audio_clips (
      id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
      novel_id INT UNSIGNED NOT NULL,
      first_chapter_no INT UNSIGNED NOT NULL,
      last_chapter_no INT UNSIGNED NOT NULL,
      title VARCHAR(255) NOT NULL,
      audio_path VARCHAR(255) NOT NULL,
      provider VARCHAR(64) NULL,
      file_size BIGINT UNSIGNED NOT NULL DEFAULT 0,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uq_audio_clip (novel_id, first_chapter_no, last_chapter_no),
      CONSTRAINT fk_audio_clips_novel
        FOREIGN KEY (novel_id) REFERENCES novels(id)
        ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
);

$title = sprintf('เสียงตอน %d-%d', $first, $last);
$fileSize = filesize($absolutePath) ?: 0;

$stmt = $db->prepare(
    'INSERT INTO audio_clips
       (novel_id, first_chapter_no, last_chapter_no, title, audio_path, provider, file_size)
     VALUES (?, ?, ?, ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE
       title = VALUES(title),
       audio_path = VALUES(audio_path),
       provider = VALUES(provider),
       file_size = VALUES(file_size),
       updated_at = CURRENT_TIMESTAMP'
);
$stmt->execute([$novelId, $first, $last, $title, $relativePath, $provider, $fileSize]);

echo "Registered audio clip novel_id={$novelId}, chapters={$first}-{$last}, file_size={$fileSize}\n";
