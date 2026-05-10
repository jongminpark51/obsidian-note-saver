param(
    [switch]$NoGui,
    [switch]$InboxOnly,
    [switch]$SelfTest,
    [switch]$UiSelfTest,
    [ValidateSet('refine', 'raw')]
    [string]$SaveMode = 'refine',
    [ValidateSet('codex', 'gemini')]
    [string]$Provider = 'codex',
    [ValidateSet('auto', 'quick', 'meeting', 'reference', 'project', 'project-doc')]
    [string]$Type = 'auto',
    [string]$Title = '',
    [string]$Text = '',
    [string]$TextFile = ''
)

$ErrorActionPreference = 'Stop'

$Script:Vault = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$Script:PromptPath = Join-Path $Script:Vault '30 Resources\Prompt\2026-05-07_Obsidian_문서_저장_프롬프트.md'
$Script:InboxFolder = Join-Path $Script:Vault '00 Inbox'
$Script:AssetsFolder = Join-Path $PSScriptRoot 'Assets'
$Script:TempFolder = Join-Path $PSScriptRoot '.tmp'
$Script:LogoPngPath = Join-Path $Script:AssetsFolder 'obsidian-note-saver-penguin.png'
$Script:LogoIconPath = Join-Path $Script:AssetsFolder 'obsidian-note-saver-penguin.ico'
$Script:SchemaPath = Join-Path $PSScriptRoot 'classification.schema.json'
$Script:RefineSchemaPath = Join-Path $PSScriptRoot 'refine.schema.json'
$Script:LastSavedPaths = @()

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [AllowEmptyString()][string]$Content
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    if ($null -eq $Content) {
        $Content = ''
    }
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function New-RoundedRectanglePath {
    param(
        [float]$X,
        [float]$Y,
        [float]$Width,
        [float]$Height,
        [float]$Radius
    )

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = $Radius * 2
    $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
    $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
    $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Ensure-AppAssets {
    if (-not (Test-Path -LiteralPath $Script:AssetsFolder)) {
        New-Item -ItemType Directory -Force -Path $Script:AssetsFolder | Out-Null
    }

    if ((Test-Path -LiteralPath $Script:LogoPngPath) -and (Test-Path -LiteralPath $Script:LogoIconPath)) {
        return
    }

    Add-Type -AssemblyName System.Drawing
    $size = 256
    $bitmap = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::Transparent)

    $backgroundPath = New-RoundedRectanglePath 18 18 220 220 54
    $backgroundBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Rectangle(18, 18, 220, 220)),
        [System.Drawing.ColorTranslator]::FromHtml('#2F80FF'),
        [System.Drawing.ColorTranslator]::FromHtml('#66A3FF'),
        45
    )
    $graphics.FillPath($backgroundBrush, $backgroundPath)

    $shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(36, 8, 30, 80))
    $shadowPath = New-RoundedRectanglePath 74 69 116 136 24
    $graphics.FillPath($shadowBrush, $shadowPath)

    $paperPath = New-RoundedRectanglePath 66 58 120 138 24
    $paperBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(248, 255, 255, 255))
    $graphics.FillPath($paperBrush, $paperPath)

    $linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(78, 47, 128, 255), 10)
    $linePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $linePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawLine($linePen, 94, 102, 154, 102)
    $graphics.DrawLine($linePen, 94, 132, 142, 132)

    $checkPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 47, 128, 255), 15)
    $checkPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $checkPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawLines($checkPen, @(
        (New-Object System.Drawing.Point(93, 163)),
        (New-Object System.Drawing.Point(119, 184)),
        (New-Object System.Drawing.Point(166, 139))
    ))

    $shineBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 255, 255, 255))
    $graphics.FillEllipse($shineBrush, 58, 44, 52, 52)

    $bitmap.Save($Script:LogoPngPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon())
    $stream = [System.IO.File]::Create($Script:LogoIconPath)
    $icon.Save($stream)
    $stream.Close()

    $icon.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
    $backgroundBrush.Dispose()
    $paperBrush.Dispose()
    $shadowBrush.Dispose()
    $linePen.Dispose()
    $checkPen.Dispose()
    $shineBrush.Dispose()
    $backgroundPath.Dispose()
    $shadowPath.Dispose()
    $paperPath.Dispose()
}

function Update-DesktopShortcutIcon {
    $desktop = Join-Path $env:USERPROFILE 'OneDrive\Desktop'
    $shortcutPath = Join-Path $desktop 'Obsidian Note Saver.lnk'
    if (-not (Test-Path -LiteralPath $shortcutPath)) {
        return
    }

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.IconLocation = $Script:LogoIconPath
    $shortcut.Save()
}

function Get-SafeNoteName {
    param([string]$Value)

    $name = if ([string]::IsNullOrWhiteSpace($Value)) { '빠른_메모' } else { $Value.Trim() }
    $name = $name -replace '[\\/:*?"<>|]', ''
    $name = $name -replace '\s+', '_'
    $name = $name.Trim(' ', '.', '_')
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = '빠른_메모'
    }
    if ($name.Length -gt 80) {
        $name = $name.Substring(0, 80).Trim('_')
    }
    return $name
}

function Resolve-InVaultPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $relative = $RelativePath.Trim()
    $relative = $relative -replace '/', '\'
    $relative = $relative.TrimStart('\')
    if (-not $relative.EndsWith('.md', [System.StringComparison]::OrdinalIgnoreCase)) {
        $relative = $relative + '.md'
    }

    $full = [System.IO.Path]::GetFullPath((Join-Path $Script:Vault $relative))
    $vaultPrefix = $Script:Vault.TrimEnd('\') + '\'
    if (-not $full.StartsWith($vaultPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Vault 밖의 경로는 사용할 수 없습니다: $RelativePath"
    }
    return $full
}

function Get-UniquePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $Path
    }

    $dir = Split-Path -Parent $Path
    $name = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $ext = [System.IO.Path]::GetExtension($Path)
    $stamp = Get-Date -Format 'HHmmss'
    return (Join-Path $dir "${name}_${stamp}${ext}")
}

function Format-YamlScalar {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }
    $escaped = $Value.Trim() -replace '"', '\"'
    return '"' + $escaped + '"'
}

function Format-YamlList {
    param([object]$Tags)

    $items = @()
    if ($Tags -is [System.Array]) {
        $items = $Tags
    }
    elseif ($Tags) {
        $items = @($Tags)
    }

    if ($items.Count -eq 0) {
        return "tags:`r`n"
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('tags:')
    foreach ($tag in $items) {
        if (-not [string]::IsNullOrWhiteSpace([string]$tag)) {
            $lines.Add('  - ' + ([string]$tag).Trim())
        }
    }
    return ($lines -join "`r`n")
}

function New-FrontMatter {
    param([object]$Plan)

    $date = Get-Date -Format 'yyyy-MM-dd'
    $typeValue = if (-not [string]::IsNullOrWhiteSpace([string]$Plan.type)) { [string]$Plan.type } else { 'quick' }
    $statusValue = if (-not [string]::IsNullOrWhiteSpace([string]$Plan.status)) { [string]$Plan.status } else { 'inbox' }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('---')
    $lines.Add('type: ' + $typeValue)
    $lines.Add('status: ' + $statusValue)
    $lines.Add('created: "' + $date + '"')
    $lines.Add('updated: "' + $date + '"')
    $lines.Add('area: ' + (Format-YamlScalar ([string]$Plan.area)))
    $lines.Add('project: ' + (Format-YamlScalar ([string]$Plan.project)))
    $lines.Add('source: ' + (Format-YamlScalar ([string]$Plan.source)))
    $lines.Add((Format-YamlList $Plan.tags))
    $lines.Add('---')
    return ($lines -join "`r`n")
}

function Repair-AiPlan {
    param(
        [object]$Plan,
        [string]$FallbackTitle,
        [string]$FallbackType = 'quick',
        [string]$FallbackStatus = 'inbox'
    )

    $date = Get-Date -Format 'yyyy-MM-dd'
    $title = if (-not [string]::IsNullOrWhiteSpace([string]$Plan.title)) { [string]$Plan.title } else { $FallbackTitle }
    if ([string]::IsNullOrWhiteSpace($title)) {
        $title = '빠른 메모'
    }

    if ([string]::IsNullOrWhiteSpace([string]$Plan.relative_path)) {
        $safeTitle = Get-SafeNoteName $title
        $Plan | Add-Member -NotePropertyName relative_path -NotePropertyValue "00 Inbox/$date`_$safeTitle.md" -Force
    }
    if ([string]::IsNullOrWhiteSpace([string]$Plan.title)) {
        $Plan | Add-Member -NotePropertyName title -NotePropertyValue $title -Force
    }
    if ([string]::IsNullOrWhiteSpace([string]$Plan.type)) {
        $Plan | Add-Member -NotePropertyName type -NotePropertyValue $FallbackType -Force
    }
    if ([string]::IsNullOrWhiteSpace([string]$Plan.status)) {
        $Plan | Add-Member -NotePropertyName status -NotePropertyValue $FallbackStatus -Force
    }
    if ($null -eq $Plan.tags) {
        $Plan | Add-Member -NotePropertyName tags -NotePropertyValue @('inbox') -Force
    }
    foreach ($name in @('area', 'project', 'source', 'moc_relative_path', 'reason', 'body')) {
        if ($null -eq $Plan.$name) {
            $Plan | Add-Member -NotePropertyName $name -NotePropertyValue '' -Force
        }
    }
    return $Plan
}

function New-InboxNote {
    param(
        [string]$NoteTitle,
        [Parameter(Mandatory = $true)][string]$Body
    )

    if (-not (Test-Path -LiteralPath $Script:InboxFolder)) {
        New-Item -ItemType Directory -Force -Path $Script:InboxFolder | Out-Null
    }

    $date = Get-Date -Format 'yyyy-MM-dd'
    $safeTitle = Get-SafeNoteName $NoteTitle
    $path = Join-Path $Script:InboxFolder "${date}_${safeTitle}.md"
    $path = Get-UniquePath $path

    $displayTitle = if ([string]::IsNullOrWhiteSpace($NoteTitle)) { $safeTitle -replace '_', ' ' } else { $NoteTitle.Trim() }
    $content = @"
---
type: quick
status: inbox
created: "$date"
updated: "$date"
area:
project:
source:
tags:
  - inbox
---
# $displayTitle

## 메모
$Body

## 분류 판단
- 추천 위치:
- 연결 문서:
- 다음 액션:
"@

    Write-Utf8NoBom -Path $path -Content ($content.TrimEnd() + [Environment]::NewLine)
    return $path
}

function Join-ProcessArguments {
    param([string[]]$Items)

    return (($Items | ForEach-Object {
        if ($null -eq $_) {
            '""'
        }
        elseif ($_ -match '[\s"]') {
            '"' + ($_ -replace '"', '\"') + '"'
        }
        else {
            $_
        }
    }) -join ' ')
}

function New-TempTextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Prefix,
        [AllowEmptyString()][string]$Content
    )

    if (-not (Test-Path -LiteralPath $Script:TempFolder)) {
        New-Item -ItemType Directory -Force -Path $Script:TempFolder | Out-Null
    }

    if ($null -eq $Content) {
        $Content = ''
    }

    $path = Join-Path $Script:TempFolder ($Prefix + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.txt')
    Write-Utf8NoBom -Path $path -Content $Content
    return $path
}

function Invoke-CommandCapture {
    param(
        [Parameter(Mandatory = $true)][string]$FileName,
        [string]$Arguments = '',
        [string]$WorkingDirectory = $Script:Vault,
        [string]$ErrorPrefix = 'CLI 실행 실패'
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FileName
    $psi.Arguments = $Arguments
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $process = [System.Diagnostics.Process]::Start($psi)
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()

    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result

    if ($process.ExitCode -ne 0) {
        $message = if ([string]::IsNullOrWhiteSpace($stderr)) { $stdout } else { $stderr }
        throw "$ErrorPrefix(exit $($process.ExitCode))`r`n$message"
    }

    if (-not [string]::IsNullOrWhiteSpace($stdout)) {
        return $stdout.Trim()
    }
    return $stderr.Trim()
}

function Invoke-CodexProcess {
    param(
        [Parameter(Mandatory = $true)][string]$PromptText,
        [ValidateSet('read-only', 'workspace-write')]
        [string]$Sandbox = 'workspace-write',
        [string]$OutputSchema = '',
        [string]$OutputFile = ''
    )

    $codex = Get-Command codex.cmd -ErrorAction SilentlyContinue
    if (-not $codex) {
        throw "codex.cmd를 찾을 수 없습니다. Codex CLI 설치 또는 PATH 설정을 확인하세요."
    }

    $args = New-Object System.Collections.Generic.List[string]
    $args.Add('exec')
    $args.Add('-C')
    $args.Add($Script:Vault)
    $args.Add('--skip-git-repo-check')
    $args.Add('--color')
    $args.Add('never')
    $args.Add('-s')
    $args.Add($Sandbox)

    if (-not [string]::IsNullOrWhiteSpace($OutputSchema)) {
        $args.Add('--output-schema')
        $args.Add($OutputSchema)
    }
    if (-not [string]::IsNullOrWhiteSpace($OutputFile)) {
        $args.Add('-o')
        $args.Add($OutputFile)
    }

    $args.Add('-')

    $promptFile = New-TempTextFile -Prefix 'codex-prompt' -Content $PromptText
    $command = '""' + $codex.Source + '" ' + (Join-ProcessArguments $args.ToArray()) + ' < "' + $promptFile + '""'
    return Invoke-CommandCapture -FileName 'cmd.exe' -Arguments ('/d /s /c ' + $command) -ErrorPrefix 'Codex 실행 실패'
}

function Invoke-GeminiProcess {
    param([Parameter(Mandatory = $true)][string]$PromptText)

    $gemini = Get-Command gemini.cmd -ErrorAction SilentlyContinue
    if (-not $gemini) {
        $gemini = Get-Command gemini -ErrorAction SilentlyContinue
    }
    if (-not $gemini) {
        throw "Gemini CLI를 찾을 수 없습니다. 설치 후 새 터미널에서 다시 실행하세요.`r`n설치 예: npm.cmd install -g @google/gemini-cli"
    }

    $promptFile = New-TempTextFile -Prefix 'gemini-prompt' -Content $PromptText
    $args = Join-ProcessArguments @('-p', 'Follow the instructions from stdin and return only the requested final answer.', '--output-format', 'text')
    $command = '""' + $gemini.Source + '" ' + $args + ' < "' + $promptFile + '""'
    return Invoke-CommandCapture -FileName 'cmd.exe' -Arguments ('/d /s /c ' + $command) -ErrorPrefix 'Gemini 실행 실패'
}

function Invoke-AiJson {
    param(
        [ValidateSet('codex', 'gemini')]
        [string]$AiProvider,
        [Parameter(Mandatory = $true)][string]$PromptText,
        [Parameter(Mandatory = $true)][string]$SchemaPath,
        [string]$OutputPrefix = 'ai-json'
    )

    if ($AiProvider -eq 'codex') {
        $outputFile = Join-Path $Script:TempFolder ($OutputPrefix + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.json')
        $fallback = Invoke-CodexProcess -PromptText $PromptText -Sandbox 'read-only' -OutputSchema $SchemaPath -OutputFile $outputFile
        $jsonText = if (Test-Path -LiteralPath $outputFile) {
            Get-Content -LiteralPath $outputFile -Raw -Encoding UTF8
        }
        else {
            $fallback
        }
        return (Get-JsonFromText $jsonText | ConvertFrom-Json)
    }

    $schema = Get-Content -LiteralPath $SchemaPath -Raw -Encoding UTF8
    $geminiInput = @"
$PromptText

반드시 아래 JSON Schema를 만족하는 JSON 객체만 출력한다.
마크다운 코드블록, 설명, 주석은 출력하지 않는다.

JSON Schema:
$schema
"@
    $jsonText = Invoke-GeminiProcess -PromptText $geminiInput
    $cleanJson = Get-JsonFromText $jsonText
    try {
        return ($cleanJson | ConvertFrom-Json)
    }
    catch {
        $rawPath = New-TempTextFile -Prefix ($OutputPrefix + '-bad-json') -Content $jsonText
        $preview = if ($jsonText) { $jsonText.Substring(0, [Math]::Min(300, $jsonText.Length)) } else { '(empty)' }
        throw "AI가 JSON 대신 다른 응답을 반환했습니다. 저장을 다시 시도하세요.`r`n응답 미리보기: $preview`r`n원본 응답: $rawPath"
    }
}

function Get-JsonFromText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    $trimmed = $Text.Trim()
    if ($trimmed.StartsWith('```')) {
        $trimmed = $trimmed -replace '^```(?:json)?\s*', ''
        $trimmed = $trimmed -replace '\s*```$', ''
    }

    $firstBrace = $trimmed.IndexOf('{')
    $lastBrace = $trimmed.LastIndexOf('}')
    if ($firstBrace -ge 0 -and $lastBrace -gt $firstBrace) {
        return $trimmed.Substring($firstBrace, $lastBrace - $firstBrace + 1)
    }

    return $trimmed
}

function Invoke-CodexClassify {
    param(
        [ValidateSet('codex', 'gemini')]
        [string]$AiProvider = 'codex',
        [string]$RequestType,
        [string]$NoteTitle,
        [Parameter(Mandatory = $true)][string]$Body
    )

    if (-not (Test-Path -LiteralPath $Script:SchemaPath)) {
        throw "분류 JSON 스키마를 찾을 수 없습니다: $Script:SchemaPath"
    }
    if (-not (Test-Path -LiteralPath $Script:TempFolder)) {
        New-Item -ItemType Directory -Force -Path $Script:TempFolder | Out-Null
    }

    $date = Get-Date -Format 'yyyy-MM-dd'
    $promptText = @"
너는 Obsidian Vault 분류기다. 파일을 만들거나 수정하지 말고, 읽기만 해서 JSON 분류 계획만 반환한다.

Vault 구조와 규칙:
- 00 Inbox: 성격이 불명확한 빠른 메모
- 10 Projects: 목표/마감/산출물이 있는 프로젝트
- 20 Areas: 지속적인 책임 영역과 팀 운영 문서
- 30 Resources: 참고 자료, 프롬프트, 쿼리, 데일리 노트, 학습 자료
- 40 Archives: 완료/비활성 자료
- 파일명은 날짜성 문서에 `YYYY-MM-DD_핵심_제목.md`를 사용한다.
- 기존 파일명과 충돌하지 않는 상대 경로를 제안한다.

요청 유형 힌트: $RequestType
제목 힌트: $NoteTitle
작업일: $date

반드시 JSON 스키마에 맞춰 반환한다.
relative_path는 Vault 기준 상대 경로여야 하며 .md로 끝나야 한다.
원문 유지 모드이므로 body는 절대 요약/수정하지 않는다.
moc_relative_path는 적합한 MOC가 명확히 존재할 때만 채운다.

입력 내용:
$Body
"@

    return Invoke-AiJson -AiProvider $AiProvider -PromptText $promptText -SchemaPath $Script:SchemaPath -OutputPrefix 'classification'
}

function Save-RawClassifiedNote {
    param(
        [ValidateSet('codex', 'gemini')]
        [string]$AiProvider = 'codex',
        [string]$RequestType,
        [string]$NoteTitle,
        [Parameter(Mandatory = $true)][string]$Body
    )

    $plan = Invoke-CodexClassify -AiProvider $AiProvider -RequestType $RequestType -NoteTitle $NoteTitle -Body $Body
    $plan = Repair-AiPlan -Plan $plan -FallbackTitle $NoteTitle -FallbackType 'quick' -FallbackStatus 'inbox'
    $path = Resolve-InVaultPath ([string]$plan.relative_path)
    $path = Get-UniquePath $path
    $dir = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $frontMatter = New-FrontMatter $plan
    $content = $frontMatter + "`r`n" + $Body
    Write-Utf8NoBom -Path $path -Content $content

    if ($plan.moc_relative_path) {
        try {
            Update-MocLink -MocRelativePath ([string]$plan.moc_relative_path) -SavedPath $path
        }
        catch {
            # MOC update is helpful but should not block the saved note.
        }
    }

    return $path
}

function Update-MocLink {
    param(
        [Parameter(Mandatory = $true)][string]$MocRelativePath,
        [Parameter(Mandatory = $true)][string]$SavedPath
    )

    $mocPath = Resolve-InVaultPath $MocRelativePath
    if (-not (Test-Path -LiteralPath $mocPath)) {
        return
    }

    $title = [System.IO.Path]::GetFileNameWithoutExtension($SavedPath)
    $link = "- [[$title]]"
    $moc = Get-Content -LiteralPath $mocPath -Raw -Encoding UTF8
    if ($moc -like "*[[$title]]*") {
        return
    }

    Write-Utf8NoBom -Path $mocPath -Content ($moc.TrimEnd() + "`r`n" + $link + "`r`n")
}

function Find-SavedPathsFromText {
    param([string]$Text)

    $paths = New-Object System.Collections.Generic.List[string]
    $escapedVault = [regex]::Escape($Script:Vault.TrimEnd('\'))
    $absolutePattern = $escapedVault + '[^\r\n`"]+?\.md'
    foreach ($match in [regex]::Matches($Text, $absolutePattern)) {
        $candidate = $match.Value.Trim()
        if ((Test-Path -LiteralPath $candidate) -and -not $paths.Contains($candidate)) {
            $paths.Add($candidate)
        }
    }

    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -match 'SAVED_PATH:\s*(.+?\.md)\s*$') {
            $candidate = $Matches[1].Trim()
            if (-not [System.IO.Path]::IsPathRooted($candidate)) {
                $candidate = Resolve-InVaultPath $candidate
            }
            if ((Test-Path -LiteralPath $candidate) -and -not $paths.Contains($candidate)) {
                $paths.Add($candidate)
            }
        }
    }

    return $paths.ToArray()
}

function Invoke-CodexRefineSave {
    param(
        [string]$RequestType,
        [string]$NoteTitle,
        [Parameter(Mandatory = $true)][string]$Body
    )

    if (-not (Test-Path -LiteralPath $Script:PromptPath)) {
        throw "저장 프롬프트를 찾을 수 없습니다: $Script:PromptPath"
    }

    $date = Get-Date -Format 'yyyy-MM-dd'
    $promptText = @"
30 Resources/Prompt/2026-05-07_Obsidian_문서_저장_프롬프트.md 규칙을 읽고, 아래 입력을 적절한 Obsidian 문서로 저장해.

저장 모드: 내용 다듬기
요청 유형: $RequestType
제목 힌트: $NoteTitle
작업일: $date

중요 규칙:
- 기존 파일은 덮어쓰지 않는다.
- 문장을 정리하고 구조화하되, 원문의 의미와 사실관계를 바꾸지 않는다.
- 새 문서는 적절한 템플릿 구조와 properties를 적용한다.
- 성격이 불명확하면 00 Inbox에 저장한다.
- 적합한 MOC가 이미 있으면 새 문서 링크만 추가한다.
- 완료 후 생성/수정한 파일 경로를 짧게 보고한다.
- 마지막에는 생성한 대표 문서 경로를 `SAVED_PATH: 절대경로` 형식으로 한 줄에 적는다.

입력 내용:
$Body
"@

    $message = Invoke-CodexProcess -PromptText $promptText -Sandbox 'workspace-write'
    $paths = Find-SavedPathsFromText $message
    return [pscustomobject]@{
        Message = $message
        Paths = $paths
    }
}

function Invoke-AiRefinePlan {
    param(
        [ValidateSet('codex', 'gemini')]
        [string]$AiProvider = 'codex',
        [string]$RequestType,
        [string]$NoteTitle,
        [Parameter(Mandatory = $true)][string]$Body
    )

    if (-not (Test-Path -LiteralPath $Script:RefineSchemaPath)) {
        throw "정리 저장 JSON 스키마를 찾을 수 없습니다: $Script:RefineSchemaPath"
    }

    $date = Get-Date -Format 'yyyy-MM-dd'
    $promptText = @"
너는 Obsidian 문서 정리기다. 파일을 만들거나 수정하지 말고, 아래 입력을 정리한 Markdown 문서 계획을 JSON으로만 반환한다.

Vault 구조와 규칙:
- 00 Inbox: 성격이 불명확한 빠른 메모
- 10 Projects: 목표/마감/산출물이 있는 프로젝트
- 20 Areas: 지속적인 책임 영역과 팀 운영 문서
- 30 Resources: 참고 자료, 프롬프트, 쿼리, 데일리 노트, 학습 자료
- 40 Archives: 완료/비활성 자료
- 파일명은 날짜성 문서에 `YYYY-MM-DD_핵심_제목.md`를 사용한다.
- 기존 파일명과 충돌하지 않는 상대 경로를 제안한다.

요청 유형 힌트: $RequestType
제목 힌트: $NoteTitle
작업일: $date

정리 규칙:
- 문장을 읽기 좋게 다듬고, 적절한 Markdown 섹션으로 구조화한다.
- 원문의 의미, 숫자, 고유명사, 결정 사항은 바꾸지 않는다.
- body에는 YAML front matter를 넣지 않는다. 본문 Markdown만 넣는다.
- relative_path는 Vault 기준 상대 경로여야 하며 .md로 끝나야 한다.
- moc_relative_path는 적합한 MOC가 명확히 존재할 때만 채운다.

입력 내용:
$Body
"@

    return Invoke-AiJson -AiProvider $AiProvider -PromptText $promptText -SchemaPath $Script:RefineSchemaPath -OutputPrefix 'refine'
}

function Save-RefinedClassifiedNote {
    param(
        [ValidateSet('codex', 'gemini')]
        [string]$AiProvider = 'codex',
        [string]$RequestType,
        [string]$NoteTitle,
        [Parameter(Mandatory = $true)][string]$Body
    )

    $plan = Invoke-AiRefinePlan -AiProvider $AiProvider -RequestType $RequestType -NoteTitle $NoteTitle -Body $Body
    $plan = Repair-AiPlan -Plan $plan -FallbackTitle $NoteTitle -FallbackType 'quick' -FallbackStatus 'inbox'
    $path = Resolve-InVaultPath ([string]$plan.relative_path)
    $path = Get-UniquePath $path
    $dir = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $frontMatter = New-FrontMatter $plan
    $bodyText = if ($plan.body) { [string]$plan.body } else { $Body }
    $content = $frontMatter + "`r`n" + $bodyText.Trim() + "`r`n"
    Write-Utf8NoBom -Path $path -Content $content

    if ($plan.moc_relative_path) {
        try {
            Update-MocLink -MocRelativePath ([string]$plan.moc_relative_path) -SavedPath $path
        }
        catch {
            # MOC update is helpful but should not block the saved note.
        }
    }

    return [pscustomobject]@{
        Path = $path
        Reason = [string]$plan.reason
    }
}

function Get-InputText {
    param([string]$DirectText, [string]$Path)

    if (-not [string]::IsNullOrWhiteSpace($DirectText)) {
        return $DirectText
    }
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        return Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    }
    if ([Console]::IsInputRedirected) {
        return [Console]::In.ReadToEnd()
    }
    return ''
}

function ConvertTo-ObsidianUri {
    param([Parameter(Mandatory = $true)][string]$Path)

    $full = [System.IO.Path]::GetFullPath($Path)
    $vaultPrefix = $Script:Vault.TrimEnd('\') + '\'
    if (-not $full.StartsWith($vaultPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Vault 내부 파일만 Obsidian으로 열 수 있습니다."
    }

    $relative = $full.Substring($vaultPrefix.Length) -replace '\\', '/'
    $vaultName = Split-Path $Script:Vault -Leaf
    $encodedVault = [System.Uri]::EscapeDataString($vaultName)
    $encodedFile = (($relative -split '/') | ForEach-Object { [System.Uri]::EscapeDataString($_) }) -join '/'
    return "obsidian://open?vault=$encodedVault&file=$encodedFile"
}

function Open-InObsidian {
    param([Parameter(Mandatory = $true)][string]$Path)

    $uri = ConvertTo-ObsidianUri $Path
    Start-Process $uri
}

function Test-Setup {
    $checks = New-Object System.Collections.Generic.List[string]
    $checks.Add("Vault: $Script:Vault")
    $checks.Add("Prompt: " + (Test-Path -LiteralPath $Script:PromptPath))
    $checks.Add("Inbox: " + (Test-Path -LiteralPath $Script:InboxFolder))
    $checks.Add("Assets: " + ((Test-Path -LiteralPath $Script:LogoPngPath) -and (Test-Path -LiteralPath $Script:LogoIconPath)))
    $checks.Add("Schema: " + (Test-Path -LiteralPath $Script:SchemaPath))
    $checks.Add("Refine schema: " + (Test-Path -LiteralPath $Script:RefineSchemaPath))
    $checks.Add("codex.cmd: " + [bool](Get-Command codex.cmd -ErrorAction SilentlyContinue))
    $hasGeminiCmd = [bool](Get-Command gemini.cmd -ErrorAction SilentlyContinue)
    $hasGemini = $hasGeminiCmd -or [bool](Get-Command gemini -ErrorAction SilentlyContinue)
    $checks.Add("gemini.cmd: " + $hasGemini)
    return ($checks -join [Environment]::NewLine)
}

Ensure-AppAssets
Update-DesktopShortcutIcon

if ($SelfTest) {
    Test-Setup
    exit 0
}

if ($NoGui) {
    $body = Get-InputText -DirectText $Text -Path $TextFile
    if ([string]::IsNullOrWhiteSpace($body)) {
        throw '저장할 내용이 비어 있습니다.'
    }

    if ($InboxOnly) {
        New-InboxNote -NoteTitle $Title -Body $body
    }
    elseif ($SaveMode -eq 'raw') {
        Save-RawClassifiedNote -AiProvider $Provider -RequestType $Type -NoteTitle $Title -Body $body
    }
    else {
        $result = Save-RefinedClassifiedNote -AiProvider $Provider -RequestType $Type -NoteTitle $Title -Body $body
        $result.Path
    }
    exit 0
}

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Obsidian Note Saver"
        Width="920"
        Height="880"
        MinWidth="760"
        MinHeight="720"
        WindowStartupLocation="CenterScreen"
        Background="#F7F9FC"
        FontFamily="Malgun Gothic"
        FontSize="14">
    <Window.Resources>
        <SolidColorBrush x:Key="PrimaryBrush" Color="#3182F6"/>
        <SolidColorBrush x:Key="PrimaryHoverBrush" Color="#1C6FE8"/>
        <SolidColorBrush x:Key="TextBrush" Color="#1F2937"/>
        <SolidColorBrush x:Key="MutedBrush" Color="#6B7280"/>
        <SolidColorBrush x:Key="BorderBrushSoft" Color="#E5EAF2"/>
        <Style x:Key="PrimaryButton" TargetType="Button">
            <Setter Property="Background" Value="{StaticResource PrimaryBrush}"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="22,12"/>
            <Setter Property="MinHeight" Value="44"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="14" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="{StaticResource PrimaryHoverBrush}"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Background" Value="#CBD5E1"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource PrimaryButton}">
            <Setter Property="Background" Value="#EDF4FF"/>
            <Setter Property="Foreground" Value="#2368D5"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="14" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#E0EDFF"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Background" Value="#EEF2F7"/>
                                <Setter Property="Foreground" Value="#94A3B8"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="InputTextBox" TargetType="TextBox">
            <Setter Property="Background" Value="#F9FAFB"/>
            <Setter Property="Foreground" Value="{StaticResource TextBrush}"/>
            <Setter Property="BorderBrush" Value="{StaticResource BorderBrushSoft}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
        </Style>
        <Style x:Key="InputComboBox" TargetType="ComboBox">
            <Setter Property="Background" Value="#F9FAFB"/>
            <Setter Property="Foreground" Value="{StaticResource TextBrush}"/>
            <Setter Property="BorderBrush" Value="{StaticResource BorderBrushSoft}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8"/>
        </Style>
    </Window.Resources>

    <Grid Margin="28">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Grid Grid.Row="0" Margin="0,0,0,22">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Border Width="58" Height="58" CornerRadius="18" Background="White" Padding="7">
                <Image x:Name="LogoImage" Stretch="Uniform"/>
            </Border>
            <StackPanel Grid.Column="1" Margin="16,2,0,0">
                <TextBlock Text="Obsidian Note Saver" FontSize="26" FontWeight="Bold" Foreground="{StaticResource TextBrush}"/>
                <TextBlock Text="메모를 붙여넣으면 Vault 규칙에 맞춰 분류하고 저장합니다." Margin="0,6,0,0" Foreground="{StaticResource MutedBrush}"/>
            </StackPanel>
        </Grid>

        <Border Grid.Row="1" Background="White" CornerRadius="26" Padding="24" BorderBrush="#E8EDF5" BorderThickness="1">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <Grid Grid.Row="0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="170"/>
                        <ColumnDefinition Width="170"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Margin="0,0,16,0">
                        <TextBlock Text="제목 힌트" FontWeight="SemiBold" Foreground="{StaticResource TextBrush}" Margin="0,0,0,8"/>
                        <TextBox x:Name="TitleBox" Style="{StaticResource InputTextBox}" Height="46"/>
                    </StackPanel>
                    <StackPanel Grid.Column="1" Margin="0,0,16,0">
                        <TextBlock Text="유형 힌트" FontWeight="SemiBold" Foreground="{StaticResource TextBrush}" Margin="0,0,0,8"/>
                        <ComboBox x:Name="TypeBox" Style="{StaticResource InputComboBox}" Height="46" SelectedIndex="0">
                            <ComboBoxItem Content="auto"/>
                            <ComboBoxItem Content="quick"/>
                            <ComboBoxItem Content="meeting"/>
                            <ComboBoxItem Content="reference"/>
                            <ComboBoxItem Content="project-doc"/>
                            <ComboBoxItem Content="project"/>
                        </ComboBox>
                    </StackPanel>
                    <StackPanel Grid.Column="2">
                        <TextBlock Text="AI 엔진" FontWeight="SemiBold" Foreground="{StaticResource TextBrush}" Margin="0,0,0,8"/>
                        <ComboBox x:Name="ProviderBox" Style="{StaticResource InputComboBox}" Height="46" SelectedIndex="0">
                            <ComboBoxItem Content="Gemini"/>
                            <ComboBoxItem Content="Codex"/>
                        </ComboBox>
                    </StackPanel>
                </Grid>

                <Grid Grid.Row="1" Margin="0,22,0,18">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="16"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <Border x:Name="RefineCard" CornerRadius="18" BorderBrush="#3182F6" BorderThickness="2" Background="#F3F8FF" Padding="18">
                        <RadioButton x:Name="RefineMode" IsChecked="True" GroupName="SaveMode" Cursor="Hand">
                            <StackPanel>
                                <TextBlock Text="내용 다듬기" FontSize="16" FontWeight="Bold" Foreground="{StaticResource TextBrush}"/>
                                <TextBlock Text="문장을 정리하고 템플릿 구조에 맞춰 저장" Margin="0,6,0,0" Foreground="{StaticResource MutedBrush}" TextWrapping="Wrap"/>
                            </StackPanel>
                        </RadioButton>
                    </Border>
                    <Border x:Name="RawCard" Grid.Column="2" CornerRadius="18" BorderBrush="#E5EAF2" BorderThickness="1" Background="#FFFFFF" Padding="18">
                        <RadioButton x:Name="RawMode" GroupName="SaveMode" Cursor="Hand">
                            <StackPanel>
                                <TextBlock Text="원문 유지" FontSize="16" FontWeight="Bold" Foreground="{StaticResource TextBrush}"/>
                                <TextBlock Text="본문은 그대로 두고 속성과 폴더만 분류" Margin="0,6,0,0" Foreground="{StaticResource MutedBrush}" TextWrapping="Wrap"/>
                            </StackPanel>
                        </RadioButton>
                    </Border>
                </Grid>

                <Grid Grid.Row="2">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <Grid Margin="0,0,0,8">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="내용" FontWeight="SemiBold" Foreground="{StaticResource TextBrush}" VerticalAlignment="Center"/>
                        <TextBlock x:Name="ContentStats" Grid.Column="1" Foreground="{StaticResource MutedBrush}" Margin="12,0,0,0" VerticalAlignment="Center"/>
                        <Button x:Name="ExpandContentButton" Grid.Column="2" Style="{StaticResource SecondaryButton}" Content="크게 보기" MinHeight="36" Padding="16,8"/>
                    </Grid>
                    <TextBox x:Name="ContentBox"
                             Grid.Row="1"
                             Style="{StaticResource InputTextBox}"
                             AcceptsReturn="True"
                             AcceptsTab="True"
                             TextWrapping="Wrap"
                             VerticalScrollBarVisibility="Visible"
                             HorizontalScrollBarVisibility="Auto"
                             VerticalContentAlignment="Top"
                             MinHeight="360"
                             FontSize="14"/>
                </Grid>

                <Grid Grid.Row="3" Margin="0,20,0,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <Button x:Name="SaveButton" Style="{StaticResource PrimaryButton}" Content="저장하기"/>
                    <Button x:Name="InboxButton" Grid.Column="1" Style="{StaticResource SecondaryButton}" Content="Inbox에 바로 저장" Margin="10,0,0,0"/>
                    <Button x:Name="OpenButton" Grid.Column="3" Style="{StaticResource SecondaryButton}" Content="Obsidian에서 열기" IsEnabled="False" Margin="0,0,10,0"/>
                    <Button x:Name="CopyPathButton" Grid.Column="4" Style="{StaticResource SecondaryButton}" Content="경로 복사" IsEnabled="False"/>
                </Grid>

                <Border Grid.Row="4" Margin="0,18,0,0" Background="#F8FAFD" CornerRadius="18" Padding="16" BorderBrush="#E8EDF5" BorderThickness="1">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <TextBlock x:Name="StatusText" Text="대기 중" FontWeight="SemiBold" Foreground="{StaticResource TextBrush}"/>
                        <ProgressBar x:Name="BusyProgress"
                                     Grid.Row="1"
                                     Margin="0,10,0,2"
                                     Height="6"
                                     IsIndeterminate="True"
                                     Visibility="Collapsed"
                                     Foreground="#3182F6"
                                     Background="#E8EDF5"/>
                        <TextBox x:Name="ResultBox"
                                 Grid.Row="2"
                                 Margin="0,8,0,0"
                                 Background="#F8FAFD"
                                 BorderThickness="0"
                                 Foreground="{StaticResource MutedBrush}"
                                 IsReadOnly="True"
                                 TextWrapping="Wrap"
                                 MinHeight="48"
                                 VerticalScrollBarVisibility="Auto"/>
                    </Grid>
                </Border>
            </Grid>
        </Border>

        <TextBlock Grid.Row="2" Margin="4,14,0,0" Foreground="#8A95A6" Text="Tip: 원문 유지 모드는 본문을 직접 쓰지 않고, Codex가 분류 계획만 만들면 프로그램이 원문 그대로 저장합니다."/>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$window.Icon = New-Object System.Windows.Media.Imaging.BitmapImage([System.Uri]$Script:LogoIconPath)

$LogoImage = $window.FindName('LogoImage')
$TitleBox = $window.FindName('TitleBox')
$TypeBox = $window.FindName('TypeBox')
$ProviderBox = $window.FindName('ProviderBox')
$ContentBox = $window.FindName('ContentBox')
$ContentStats = $window.FindName('ContentStats')
$ExpandContentButton = $window.FindName('ExpandContentButton')
$RefineMode = $window.FindName('RefineMode')
$RawMode = $window.FindName('RawMode')
$RefineCard = $window.FindName('RefineCard')
$RawCard = $window.FindName('RawCard')
$SaveButton = $window.FindName('SaveButton')
$InboxButton = $window.FindName('InboxButton')
$OpenButton = $window.FindName('OpenButton')
$CopyPathButton = $window.FindName('CopyPathButton')
$StatusText = $window.FindName('StatusText')
$BusyProgress = $window.FindName('BusyProgress')
$ResultBox = $window.FindName('ResultBox')

$LogoImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([System.Uri]$Script:LogoPngPath)

function Get-SelectedType {
    $item = $TypeBox.SelectedItem
    if ($item -and $item.Content) {
        return [string]$item.Content
    }
    return 'auto'
}

function Get-SelectedProvider {
    $item = $ProviderBox.SelectedItem
    $label = if ($item -and $item.Content) { [string]$item.Content } else { 'Codex' }
    if ($label -eq 'Gemini') {
        return 'gemini'
    }
    return 'codex'
}

function Set-DefaultProvider {
    $hasGeminiCmd = [bool](Get-Command gemini.cmd -ErrorAction SilentlyContinue)
    $hasGemini = $hasGeminiCmd -or [bool](Get-Command gemini -ErrorAction SilentlyContinue)
    if ($hasGemini) {
        $ProviderBox.SelectedIndex = 0
    }
    else {
        $ProviderBox.SelectedIndex = 1
    }
}

function Set-ModeCards {
    if ($RefineMode.IsChecked) {
        $RefineCard.BorderBrush = [System.Windows.Media.Brushes]::DodgerBlue
        $RefineCard.BorderThickness = New-Object System.Windows.Thickness(2)
        $RefineCard.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString('#F3F8FF'))
        $RawCard.BorderBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString('#E5EAF2'))
        $RawCard.BorderThickness = New-Object System.Windows.Thickness(1)
        $RawCard.Background = [System.Windows.Media.Brushes]::White
    }
    else {
        $RawCard.BorderBrush = [System.Windows.Media.Brushes]::DodgerBlue
        $RawCard.BorderThickness = New-Object System.Windows.Thickness(2)
        $RawCard.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString('#F3F8FF'))
        $RefineCard.BorderBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString('#E5EAF2'))
        $RefineCard.BorderThickness = New-Object System.Windows.Thickness(1)
        $RefineCard.Background = [System.Windows.Media.Brushes]::White
    }
}

function Refresh-Ui {
    $window.Dispatcher.Invoke(
        [Action]{},
        [System.Windows.Threading.DispatcherPriority]::Background
    )
}

function Set-Busy {
    param(
        [bool]$Busy,
        [string]$Message = ''
    )

    $window.Cursor = if ($Busy) { [System.Windows.Input.Cursors]::Wait } else { $null }
    $SaveButton.IsEnabled = -not $Busy
    $InboxButton.IsEnabled = -not $Busy
    $ProviderBox.IsEnabled = -not $Busy
    $TypeBox.IsEnabled = -not $Busy
    $RefineMode.IsEnabled = -not $Busy
    $RawMode.IsEnabled = -not $Busy
    $ExpandContentButton.IsEnabled = -not $Busy
    $OpenButton.IsEnabled = (-not $Busy) -and ($Script:LastSavedPaths.Count -gt 0)
    $CopyPathButton.IsEnabled = (-not $Busy) -and ($Script:LastSavedPaths.Count -gt 0)
    $BusyProgress.Visibility = if ($Busy) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    if (-not [string]::IsNullOrWhiteSpace($Message)) {
        $StatusText.Text = $Message
    }
    elseif ($Busy) {
        $StatusText.Text = if ($Busy) { '저장 중...' } else { '대기 중' }
    }
    Refresh-Ui
}

function Set-Progress {
    param([string]$Message)

    $StatusText.Text = $Message
    $ResultBox.Text = $Message
    Refresh-Ui
}

function Set-Result {
    param(
        [string]$Status,
        [string]$Message,
        [string[]]$Paths = @()
    )

    $Script:LastSavedPaths = @($Paths)
    $StatusText.Text = $Status
    $OpenButton.IsEnabled = $Script:LastSavedPaths.Count -gt 0
    $CopyPathButton.IsEnabled = $Script:LastSavedPaths.Count -gt 0

    if ($Script:LastSavedPaths.Count -gt 0) {
        $pathText = ($Script:LastSavedPaths | ForEach-Object { "완료 경로: $_" }) -join [Environment]::NewLine
        $ResultBox.Text = ($pathText + [Environment]::NewLine + $Message).Trim()
    }
    else {
        $ResultBox.Text = $Message
    }
}

function Write-AppError {
    param([System.Exception]$Exception)

    if (-not (Test-Path -LiteralPath $Script:TempFolder)) {
        New-Item -ItemType Directory -Force -Path $Script:TempFolder | Out-Null
    }

    $path = Join-Path $Script:TempFolder 'last-error.txt'
    $message = @"
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Message:
$($Exception.Message)

StackTrace:
$($Exception.ScriptStackTrace)
"@
    Write-Utf8NoBom -Path $path -Content $message
    return $path
}

function Update-ContentStats {
    $text = if ($ContentBox.Text) { [string]$ContentBox.Text } else { '' }
    $lineCount = if ($text.Length -eq 0) { 0 } else { (($text -split "`r`n|`n|`r").Count) }
    $ContentStats.Text = "$($text.Length)자 · $lineCount줄"
}

function Show-LargeContentEditor {
    $editorWindow = New-Object System.Windows.Window
    $editorWindow.Title = '내용 크게 보기'
    $editorWindow.Width = 980
    $editorWindow.Height = 760
    $editorWindow.MinWidth = 720
    $editorWindow.MinHeight = 520
    $editorWindow.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
    $editorWindow.Owner = $window
    $editorWindow.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString('#F7F9FC'))
    $editorWindow.FontFamily = New-Object System.Windows.Media.FontFamily('Malgun Gothic')
    $editorWindow.FontSize = 14
    $editorWindow.Icon = $window.Icon

    $root = New-Object System.Windows.Controls.Grid
    $root.Margin = New-Object System.Windows.Thickness(24)
    $row1 = New-Object System.Windows.Controls.RowDefinition
    $row1.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $row2 = New-Object System.Windows.Controls.RowDefinition
    $row2.Height = [System.Windows.GridLength]::Auto
    $root.RowDefinitions.Add($row1)
    $root.RowDefinitions.Add($row2)

    $editorBox = New-Object System.Windows.Controls.TextBox
    $editorBox.Text = $ContentBox.Text
    $editorBox.AcceptsReturn = $true
    $editorBox.AcceptsTab = $true
    $editorBox.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $editorBox.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Visible
    $editorBox.HorizontalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $editorBox.VerticalContentAlignment = [System.Windows.VerticalAlignment]::Top
    $editorBox.Padding = New-Object System.Windows.Thickness(16)
    $editorBox.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString('#FFFFFF'))
    $editorBox.BorderBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString('#DCE3ED'))
    $editorBox.BorderThickness = New-Object System.Windows.Thickness(1)
    $editorBox.FontSize = 15
    [System.Windows.Controls.Grid]::SetRow($editorBox, 0)
    $root.Children.Add($editorBox) | Out-Null

    $buttonPanel = New-Object System.Windows.Controls.StackPanel
    $buttonPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $buttonPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
    $buttonPanel.Margin = New-Object System.Windows.Thickness(0, 16, 0, 0)
    [System.Windows.Controls.Grid]::SetRow($buttonPanel, 1)

    $applyButton = New-Object System.Windows.Controls.Button
    $applyButton.Content = '적용'
    $applyButton.MinWidth = 96
    $applyButton.MinHeight = 40
    $applyButton.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
    $applyButton.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString('#3182F6'))
    $applyButton.Foreground = [System.Windows.Media.Brushes]::White
    $applyButton.BorderThickness = New-Object System.Windows.Thickness(0)

    $cancelButton = New-Object System.Windows.Controls.Button
    $cancelButton.Content = '닫기'
    $cancelButton.MinWidth = 96
    $cancelButton.MinHeight = 40
    $cancelButton.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString('#EDF4FF'))
    $cancelButton.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString('#2368D5'))
    $cancelButton.BorderThickness = New-Object System.Windows.Thickness(0)

    $buttonPanel.Children.Add($applyButton) | Out-Null
    $buttonPanel.Children.Add($cancelButton) | Out-Null
    $root.Children.Add($buttonPanel) | Out-Null

    $applyButton.Add_Click({
        $ContentBox.Text = $editorBox.Text
        Update-ContentStats
        $editorWindow.Close()
    })
    $cancelButton.Add_Click({ $editorWindow.Close() })

    $editorWindow.Content = $root
    $editorBox.Focus() | Out-Null
    [void]$editorWindow.ShowDialog()
}

$RefineMode.Add_Checked({ Set-ModeCards })
$RawMode.Add_Checked({ Set-ModeCards })
$RefineCard.Add_MouseLeftButtonUp({ $RefineMode.IsChecked = $true; Set-ModeCards })
$RawCard.Add_MouseLeftButtonUp({ $RawMode.IsChecked = $true; Set-ModeCards })
$ContentBox.Add_TextChanged({ Update-ContentStats })
$ExpandContentButton.Add_Click({ Show-LargeContentEditor })

$InboxButton.Add_Click({
    try {
        $body = $ContentBox.Text
        if ([string]::IsNullOrWhiteSpace($body)) {
            [System.Windows.MessageBox]::Show('저장할 내용을 입력하세요.', 'Obsidian Note Saver') | Out-Null
            return
        }

        Set-Busy $true -Message 'Inbox 저장을 시작했습니다...'
        Set-Progress '파일 경로를 만들고 메모를 저장하는 중입니다...'
        $path = New-InboxNote -NoteTitle $TitleBox.Text -Body $body
        Set-Result -Status 'Inbox 저장 완료' -Message 'AI 분류 없이 빠른 메모로 저장했습니다.' -Paths @($path)
    }
    catch {
        $errorPath = Write-AppError $_.Exception
        Set-Result -Status '저장 실패' -Message ($_.Exception.Message + "`r`n오류 로그: $errorPath")
        [System.Windows.MessageBox]::Show($_.Exception.Message, '저장 실패') | Out-Null
    }
    finally {
        Set-Busy $false
    }
})

$SaveButton.Add_Click({
    try {
        $body = $ContentBox.Text
        if ([string]::IsNullOrWhiteSpace($body)) {
            [System.Windows.MessageBox]::Show('저장할 내용을 입력하세요.', 'Obsidian Note Saver') | Out-Null
            return
        }

        Set-Busy $true -Message '저장을 시작했습니다...'
        $requestType = Get-SelectedType
        $aiProvider = Get-SelectedProvider
        $providerLabel = if ($aiProvider -eq 'gemini') { 'Gemini' } else { 'Codex' }

        if ($RawMode.IsChecked) {
            Set-Progress "$providerLabel로 폴더와 속성을 분류하는 중입니다..."
            $path = Save-RawClassifiedNote -AiProvider $aiProvider -RequestType $requestType -NoteTitle $TitleBox.Text -Body $body
            Set-Result -Status '원문 유지 저장 완료' -Message "AI 엔진: $aiProvider`r`n본문은 그대로 두고 properties와 저장 위치만 적용했습니다." -Paths @($path)
        }
        else {
            Set-Progress "$providerLabel로 내용을 정리하고 저장 계획을 만드는 중입니다..."
            $result = Save-RefinedClassifiedNote -AiProvider $aiProvider -RequestType $requestType -NoteTitle $TitleBox.Text -Body $body
            $message = "AI 엔진: $aiProvider"
            if (-not [string]::IsNullOrWhiteSpace($result.Reason)) {
                $message += "`r`n분류 이유: " + $result.Reason
            }
            Set-Result -Status '내용 다듬기 저장 완료' -Message $message -Paths @($result.Path)
        }
    }
    catch {
        $errorPath = Write-AppError $_.Exception
        Set-Result -Status '저장 실패' -Message ($_.Exception.Message + "`r`n오류 로그: $errorPath")
        [System.Windows.MessageBox]::Show($_.Exception.Message, '저장 실패') | Out-Null
    }
    finally {
        Set-Busy $false
    }
})

$OpenButton.Add_Click({
    try {
        if ($Script:LastSavedPaths.Count -gt 0) {
            Open-InObsidian $Script:LastSavedPaths[0]
        }
    }
    catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Obsidian 열기 실패') | Out-Null
    }
})

$CopyPathButton.Add_Click({
    if ($Script:LastSavedPaths.Count -gt 0) {
        [System.Windows.Clipboard]::SetText(($Script:LastSavedPaths -join [Environment]::NewLine))
        $StatusText.Text = '경로를 복사했습니다'
    }
})

Set-DefaultProvider
Set-ModeCards
Update-ContentStats
Set-Result -Status '준비 완료' -Message (Test-Setup)
if ($UiSelfTest) {
    "UI loaded: $([bool]$window)"
    "Logo loaded: $([bool]$LogoImage.Source)"
    "Save button: $([bool]$SaveButton)"
    "Provider box: $([bool]$ProviderBox)"
    "Progress bar: $([bool]$BusyProgress)"
    exit 0
}
[void]$window.ShowDialog()












