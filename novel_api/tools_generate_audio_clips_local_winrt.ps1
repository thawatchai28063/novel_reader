param(
  [Parameter(Mandatory = $true)][string]$JsonPath,
  [Parameter(Mandatory = $true)][int]$NovelId,
  [int]$Start = 1,
  [int]$Groups = 1,
  [int]$ChaptersPerClip = 10,
  [int]$MaxChars = 48000,
  [int]$ChunkChars = 2800,
  [string]$Language = 'th-TH'
)

$ErrorActionPreference = 'Stop'

[Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType = WindowsRuntime] | Out-Null
Add-Type -AssemblyName System.Runtime.WindowsRuntime

function Await-WinRtOperation {
  param($Operation, [Type]$ResultType)

  $method = [System.WindowsRuntimeSystemExtensions].GetMethods() |
    Where-Object {
      $_.Name -eq 'AsTask' -and
      $_.IsGenericMethodDefinition -and
      $_.GetParameters().Count -eq 1 -and
      $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    } |
    Select-Object -First 1

  $task = $method.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
  $task.Wait()
  return $task.Result
}

function Normalize-TtsText {
  param([string]$Text, [int]$Limit)
  $normalized = $Text -replace "`r`n", "`n"
  $normalized = $normalized -replace "`r", "`n"
  $normalized = $normalized -replace "[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]", ""
  $normalized = $normalized -replace "[ `t]+", " "
  $normalized = $normalized -replace "`n{3,}", "`n`n"
  $normalized = $normalized.Trim()
  if ($normalized.Length -le $Limit) {
    return $normalized
  }
  return $normalized.Substring(0, $Limit).Trim()
}

function Split-TtsText {
  param([string]$Text, [int]$Limit)
  $chunks = [System.Collections.Generic.List[string]]::new()
  $current = ''
  $paragraphs = [regex]::Split($Text, "`n{2,}") | ForEach-Object { $_.Trim() } | Where-Object { $_ }

  foreach ($paragraph in $paragraphs) {
    $parts = @($paragraph)
    if ($paragraph.Length -gt $Limit) {
      $parts = for ($i = 0; $i -lt $paragraph.Length; $i += $Limit) {
        $paragraph.Substring($i, [Math]::Min($Limit, $paragraph.Length - $i))
      }
    }

    foreach ($part in $parts) {
      if (($current.Length + $part.Length + 2) -le $Limit) {
        $current = ($current + "`n`n" + $part).Trim()
      } else {
        if ($current.Trim()) {
          $chunks.Add($current.Trim())
        }
        $current = $part.Trim()
      }
    }
  }

  if ($current.Trim()) {
    $chunks.Add($current.Trim())
  }
  return $chunks
}

function Write-WinRtSpeechFile {
  param($Synth, [string]$Text, [string]$Path)

  $stream = Await-WinRtOperation $Synth.SynthesizeTextToStreamAsync($Text) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
  $reader = [Windows.Storage.Streams.DataReader]::new($stream)
  [void](Await-WinRtOperation $reader.LoadAsync([uint32]$stream.Size) ([uint32]))
  $bytes = New-Object byte[] ([int]$stream.Size)
  $reader.ReadBytes($bytes)
  [IO.File]::WriteAllBytes($Path, $bytes)
}

function Join-WavFiles {
  param([string[]]$InputPaths, [string]$OutputPath)

  if ($InputPaths.Count -eq 0) {
    throw 'No WAV chunks to join'
  }

  $first = [IO.File]::ReadAllBytes($InputPaths[0])
  $formatOffset = -1
  $dataOffset = -1
  $dataSize = 0
  for ($i = 12; $i -lt $first.Length - 8; ) {
    $chunkId = [Text.Encoding]::ASCII.GetString($first, $i, 4)
    $chunkSize = [BitConverter]::ToInt32($first, $i + 4)
    if ($chunkId -eq 'fmt ') {
      $formatOffset = $i + 8
    } elseif ($chunkId -eq 'data') {
      $dataOffset = $i + 8
      $dataSize = $chunkSize
      break
    }
    $i += 8 + $chunkSize + ($chunkSize % 2)
  }

  if ($formatOffset -lt 0 -or $dataOffset -lt 0) {
    throw 'Unsupported WAV chunk format'
  }

  $fmtSize = [BitConverter]::ToInt32($first, $formatOffset - 4)
  $formatBytes = New-Object byte[] $fmtSize
  [Array]::Copy($first, $formatOffset, $formatBytes, 0, $fmtSize)

  $allData = [System.Collections.Generic.List[byte[]]]::new()
  $totalDataSize = 0
  foreach ($path in $InputPaths) {
    $bytes = [IO.File]::ReadAllBytes($path)
    $chunkDataOffset = -1
    $chunkDataSize = 0
    for ($i = 12; $i -lt $bytes.Length - 8; ) {
      $chunkId = [Text.Encoding]::ASCII.GetString($bytes, $i, 4)
      $chunkSize = [BitConverter]::ToInt32($bytes, $i + 4)
      if ($chunkId -eq 'data') {
        $chunkDataOffset = $i + 8
        $chunkDataSize = $chunkSize
        break
      }
      $i += 8 + $chunkSize + ($chunkSize % 2)
    }
    if ($chunkDataOffset -lt 0) {
      throw "Missing data chunk: $path"
    }
    $data = New-Object byte[] $chunkDataSize
    [Array]::Copy($bytes, $chunkDataOffset, $data, 0, $chunkDataSize)
    $allData.Add($data)
    $totalDataSize += $chunkDataSize
  }

  $stream = [IO.File]::Open($OutputPath, [IO.FileMode]::Create, [IO.FileAccess]::Write)
  $writer = [IO.BinaryWriter]::new($stream)
  try {
    $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
    $writer.Write([int](4 + 8 + $fmtSize + 8 + $totalDataSize))
    $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVE'))
    $writer.Write([Text.Encoding]::ASCII.GetBytes('fmt '))
    $writer.Write([int]$fmtSize)
    $writer.Write($formatBytes)
    $writer.Write([Text.Encoding]::ASCII.GetBytes('data'))
    $writer.Write([int]$totalDataSize)
    foreach ($data in $allData) {
      $writer.Write($data)
    }
  } finally {
    $writer.Dispose()
    $stream.Dispose()
  }
}

$resolvedJson = Resolve-Path -LiteralPath $JsonPath
$payload = Get-Content -LiteralPath $resolvedJson -Encoding UTF8 -Raw | ConvertFrom-Json
$chapters = @($payload.chapters | Where-Object { [int]$_.chapter_no -ge $Start } | Sort-Object { [int]$_.chapter_no })

$voice = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices |
  Where-Object { $_.Language -eq $Language } |
  Select-Object -First 1

if (-not $voice) {
  throw "No Windows TTS voice found for language $Language"
}

$synth = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::new()
$synth.Voice = $voice

$audioRoot = Join-Path $PSScriptRoot 'audio'
$novelAudioDir = Join-Path $audioRoot ("novel_{0}" -f $NovelId)
[IO.Directory]::CreateDirectory($novelAudioDir) | Out-Null

$results = [System.Collections.Generic.List[object]]::new()
for ($group = 0; $group -lt $Groups; $group++) {
  $clipChapters = @($chapters | Select-Object -Skip ($group * $ChaptersPerClip) -First $ChaptersPerClip)
  if ($clipChapters.Count -eq 0) {
    break
  }

  $first = [int]$clipChapters[0].chapter_no
  $last = [int]$clipChapters[$clipChapters.Count - 1].chapter_no
  $outPath = Join-Path $novelAudioDir ("chapters_{0:0000}_{1:0000}.wav" -f $first, $last)
  if (Test-Path -LiteralPath $outPath) {
    $results.Add([pscustomobject]@{ file = $outPath; status = 'exists'; chapters = "$first-$last" })
    continue
  }

  $blocks = foreach ($chapter in $clipChapters) {
    "ตอนที่ $($chapter.chapter_no) $($chapter.title)`n`n$($chapter.content)"
  }
  $text = Normalize-TtsText ($blocks -join "`n`n") $MaxChars
  $chunks = @(Split-TtsText $text $ChunkChars)
  $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("novel_local_tts_{0}_{1}_{2}" -f $NovelId, $first, [guid]::NewGuid().ToString('N'))
  [IO.Directory]::CreateDirectory($tempDir) | Out-Null

  try {
    $chunkFiles = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $chunks.Count; $i++) {
      $chunkPath = Join-Path $tempDir ("chunk_{0:0000}.wav" -f ($i + 1))
      Write-Host ("local tts chunk {0}/{1} chars={2}" -f ($i + 1), $chunks.Count, $chunks[$i].Length)
      Write-WinRtSpeechFile $synth $chunks[$i] $chunkPath
      $chunkFiles.Add($chunkPath)
    }

    Join-WavFiles ([string[]]$chunkFiles.ToArray()) $outPath
  } finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  $results.Add([pscustomobject]@{
    file = $outPath
    status = 'written'
    chapters = "$first-$last"
    characters = $text.Length
    audio_chunks = $chunks.Count
    voice = $voice.DisplayName
  })
}

$results | ConvertTo-Json -Depth 4
