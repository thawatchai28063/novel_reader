<?php
declare(strict_types=1);

const DB_HOST = '127.0.0.1';
const DB_NAME = 'novel_reader';
const DB_USER = 'root';
const DB_PASS = '';
const DB_CHARSET = 'utf8mb4';

// XAMPP + Git for Windows common paths.
const PDFTOTEXT_PATHS = [
    'C:\\Program Files\\Git\\mingw64\\bin\\pdftotext.exe',
    'C:\\Program Files\\Git\\usr\\bin\\pdftotext.exe',
    'pdftotext',
];

function pdo(): PDO
{
    static $pdo = null;

    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $dsn = 'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=' . DB_CHARSET;
    $pdo = new PDO($dsn, DB_USER, DB_PASS, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);

    return $pdo;
}
