$ErrorActionPreference = 'Stop'

$projectDir = $PSScriptRoot
$sourcePath = Join-Path $projectDir 'ObsidianNoteSaverLauncher.cs'
$outputPath = Join-Path $projectDir 'ObsidianNoteSaver.exe'
$iconPath = Join-Path $projectDir 'Assets\obsidian-note-saver-penguin.ico'

$compilerCandidates = @(
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
)

$compiler = $compilerCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $compiler) {
    throw 'C# compiler(csc.exe)를 찾을 수 없습니다. .NET Framework 4.x 또는 .NET SDK 설치가 필요합니다.'
}

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "런처 소스 파일을 찾을 수 없습니다: $sourcePath"
}

if (-not (Test-Path -LiteralPath $iconPath)) {
    throw "아이콘 파일을 찾을 수 없습니다: $iconPath"
}

$arguments = @(
    '/nologo',
    '/target:winexe',
    '/platform:anycpu',
    '/optimize+',
    "/out:$outputPath",
    "/win32icon:$iconPath",
    '/reference:System.Windows.Forms.dll',
    $sourcePath
)

& $compiler @arguments
if ($LASTEXITCODE -ne 0) {
    throw "런처 빌드 실패: csc.exe exit $LASTEXITCODE"
}

[PSCustomObject]@{
    Launcher = $outputPath
    Icon = $iconPath
    Compiler = $compiler
}
