param(
  [int[]]$NovelIds = @(),
  [int]$ChaptersPerClip = 10,
  [int]$MaxChars = 48000,
  [int]$ChunkChars = 2800,
  [string]$Provider = 'local-winrt',
  [string]$HtdocsApiRoot = 'C:\xampp\htdocs\novel_api',
  [string]$Php = 'C:\xampp\php\php.exe',
  [string]$Mysql = 'C:\xampp\mysql\bin\mysql.exe',
  [int]$MaxNewClips = 0
)

$ErrorActionPreference = 'Stop'

if ($ChaptersPerClip -ne 10) {
  throw "ChaptersPerClip must be 10 for this app audio format. Got: $ChaptersPerClip"
}
if ($MaxChars -lt 1000) {
  throw "MaxChars is too small for novel audio generation. Got: $MaxChars"
}
if ($ChunkChars -lt 500) {
  throw "ChunkChars is too small for novel audio generation. Got: $ChunkChars"
}

$apiRoot = $PSScriptRoot
$workspaceRoot = Split-Path -Parent $apiRoot
$exportScript = Join-Path $apiRoot 'tools_export_chapters_json.php'
$ttsScript = Join-Path $apiRoot 'tools_generate_audio_clips_local_winrt.ps1'
$registerScript = Join-Path $apiRoot 'tools_register_audio_clip.php'
$workspaceAudioRoot = Join-Path $apiRoot 'audio'
$htdocsAudioRoot = Join-Path $HtdocsApiRoot 'audio'
$exportsDir = Join-Path $apiRoot 'exports'

function Invoke-MysqlScalar {
  param([string]$Sql)
  $output = & $Mysql -u root -N -B novel_reader -e $Sql
  if ($LASTEXITCODE -ne 0) {
    throw "mysql failed: $Sql"
  }
  return ($output | Select-Object -First 1)
}

function Test-RegisteredClip {
  param([int]$NovelId, [int]$First, [int]$Last)
  $count = Invoke-MysqlScalar "SELECT COUNT(*) FROM audio_clips WHERE novel_id=$NovelId AND first_chapter_no=$First AND last_chapter_no=$Last"
  return [int]$count -gt 0
}

function Get-NovelRows {
  $idFilter = ''
  if ($NovelIds.Count -gt 0) {
    $idFilter = 'WHERE n.id IN (' + (($NovelIds | ForEach-Object { [int]$_ }) -join ',') + ')'
  }
  $sql = @"
SELECT n.id, n.title, COUNT(c.id) AS chapters
FROM novels n
LEFT JOIN chapters c ON c.novel_id=n.id
$idFilter
GROUP BY n.id,n.title
HAVING chapters > 0
ORDER BY n.id
"@
  $rows = & $Mysql -u root -N -B novel_reader -e $sql
  if ($LASTEXITCODE -ne 0) {
    throw 'mysql novel query failed'
  }
  foreach ($row in $rows) {
    $parts = $row -split "`t"
    [pscustomobject]@{
      id = [int]$parts[0]
      title = $parts[1]
      chapters = [int]$parts[2]
    }
  }
}

function Move-ClipToHtdocs {
  param([int]$NovelId, [int]$First, [int]$Last)
  $fileName = 'chapters_{0:0000}_{1:0000}.wav' -f $First, $Last
  $source = Join-Path (Join-Path $workspaceAudioRoot ("novel_{0}" -f $NovelId)) $fileName
  $destDir = Join-Path $htdocsAudioRoot ("novel_{0}" -f $NovelId)
  $dest = Join-Path $destDir $fileName
  if (-not (Test-Path -LiteralPath $source)) {
    throw "Generated file not found: $source"
  }
  [IO.Directory]::CreateDirectory($destDir) | Out-Null
  Move-Item -LiteralPath $source -Destination $dest -Force
  return $dest
}

function Get-ClipGroupsFromJson {
  param([string]$JsonPath, [int]$Size)
  $payload = Get-Content -LiteralPath $JsonPath -Encoding UTF8 -Raw | ConvertFrom-Json
  $chapters = @($payload.chapters | Sort-Object { [int]$_.chapter_no })
  for ($index = 0; $index -lt $chapters.Count; $index += $Size) {
    $group = @($chapters | Select-Object -Skip $index -First $Size)
    if ($group.Count -eq 0) {
      continue
    }
    [pscustomobject]@{
      first = [int]$group[0].chapter_no
      last = [int]$group[$group.Count - 1].chapter_no
      count = $group.Count
    }
  }
}

[IO.Directory]::CreateDirectory($exportsDir) | Out-Null

$novels = @(Get-NovelRows)
$createdClips = 0
foreach ($novel in $novels) {
  $novelId = [int]$novel.id
  $totalClips = [math]::Ceiling($novel.chapters / $ChaptersPerClip)
  Write-Host ("== novel_id={0} {1} chapters={2} clips={3} ==" -f $novelId, $novel.title, $novel.chapters, $totalClips)

  $jsonPath = Join-Path $exportsDir ("audio_novel_{0}_chapters.json" -f $novelId)
  & $Php $exportScript $novelId $jsonPath
  if ($LASTEXITCODE -ne 0) {
    throw "export failed novel_id=$novelId"
  }

  $clipGroups = @(Get-ClipGroupsFromJson $jsonPath $ChaptersPerClip)
  foreach ($clipGroup in $clipGroups) {
    $first = [int]$clipGroup.first
    $last = [int]$clipGroup.last
    $fileName = 'chapters_{0:0000}_{1:0000}.wav' -f $first, $last
    $htdocsPath = Join-Path (Join-Path $htdocsAudioRoot ("novel_{0}" -f $novelId)) $fileName
    if ((Test-RegisteredClip $novelId $first $last) -and (Test-Path -LiteralPath $htdocsPath)) {
      Write-Host ("skip registered {0}-{1}" -f $first, $last)
      continue
    }

    if ($MaxNewClips -gt 0 -and $createdClips -ge $MaxNewClips) {
      Write-Host ("max new clips reached: {0}" -f $MaxNewClips)
      exit 0
    }

    Write-Host ("generate novel_id={0} chapters={1}-{2}" -f $novelId, $first, $last)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ttsScript `
      -JsonPath $jsonPath `
      -NovelId $novelId `
      -Start $first `
      -Groups 1 `
      -ChaptersPerClip $ChaptersPerClip `
      -MaxChars $MaxChars `
      -ChunkChars $ChunkChars
    if ($LASTEXITCODE -ne 0) {
      throw "tts failed novel_id=$novelId chapters=$first-$last"
    }

    & $Php $registerScript $novelId $first $last $Provider
    if ($LASTEXITCODE -ne 0) {
      throw "register failed novel_id=$novelId chapters=$first-$last"
    }

    $dest = Move-ClipToHtdocs $novelId $first $last
    $createdClips++
    Write-Host ("ready {0}-{1} -> {2}" -f $first, $last, $dest)
  }
}

Write-Host 'all requested local audio clips are done'
