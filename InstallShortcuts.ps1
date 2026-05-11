param(
    [switch]$OpenPinLocation
)

$ErrorActionPreference = 'Stop'

$ProjectDir = $PSScriptRoot
$LauncherExe = Join-Path $ProjectDir 'ObsidianNoteSaver.exe'
$BuildLauncherScript = Join-Path $ProjectDir 'BuildLauncher.ps1'
$IconPath = Join-Path $ProjectDir 'Assets\obsidian-note-saver-penguin.ico'
$OneDriveDesktop = Join-Path $env:USERPROFILE 'OneDrive\Desktop'
$Desktop = [Environment]::GetFolderPath('Desktop')
if (Test-Path -LiteralPath $OneDriveDesktop) {
    $Desktop = $OneDriveDesktop
}
elseif ([string]::IsNullOrWhiteSpace($Desktop)) {
    $Desktop = Join-Path $env:USERPROFILE 'Desktop'
}

$StartMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Obsidian Note Saver'
$TaskbarDir = Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'

New-Item -ItemType Directory -Force -Path $Desktop, $StartMenuDir | Out-Null

if (-not (Test-Path -LiteralPath $LauncherExe)) {
    if (-not (Test-Path -LiteralPath $BuildLauncherScript)) {
        throw "런처 빌드 스크립트를 찾을 수 없습니다: $BuildLauncherScript"
    }
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $BuildLauncherScript | Out-Null
}

$shell = New-Object -ComObject WScript.Shell

function New-AppShortcut {
    param(
        [string]$Path,
        [string]$Target,
        [string]$Description,
        [string]$Arguments = '',
        [string]$Hotkey = ''
    )

    $shortcut = $shell.CreateShortcut($Path)
    $shortcut.TargetPath = $Target
    $shortcut.Arguments = $Arguments
    $shortcut.WorkingDirectory = $ProjectDir
    $shortcut.Description = $Description
    if (Test-Path -LiteralPath $IconPath) {
        $shortcut.IconLocation = "$IconPath,0"
    }
    if (-not [string]::IsNullOrWhiteSpace($Hotkey)) {
        $shortcut.Hotkey = $Hotkey
    }
    $shortcut.Save()
}

$desktopMain = Join-Path $Desktop 'Obsidian Note Saver.lnk'
$startMain = Join-Path $StartMenuDir 'Obsidian Note Saver.lnk'
$taskbarMain = Join-Path $TaskbarDir 'Obsidian Note Saver.lnk'
$legacyTaskbarWidget = Join-Path $TaskbarDir 'Obsidian Note Saver Widget.lnk'

New-AppShortcut -Path $desktopMain -Target $LauncherExe -Description 'Save quick notes into Obsidian' -Hotkey 'CTRL+ALT+O'
New-AppShortcut -Path $startMain -Target $LauncherExe -Description 'Save quick notes into Obsidian'

if (Test-Path -LiteralPath $legacyTaskbarWidget) {
    New-AppShortcut -Path $legacyTaskbarWidget -Target $LauncherExe -Description 'Save quick notes into Obsidian'
}

if (Test-Path -LiteralPath $taskbarMain) {
    New-AppShortcut -Path $taskbarMain -Target $LauncherExe -Description 'Save quick notes into Obsidian'
}

$ie4uinit = Join-Path $env:WINDIR 'System32\ie4uinit.exe'
if (Test-Path -LiteralPath $ie4uinit) {
    Start-Process -FilePath $ie4uinit -ArgumentList '-show' -WindowStyle Hidden
}

if ($OpenPinLocation) {
    Start-Process -FilePath 'explorer.exe' -ArgumentList "/select,`"$startMain`""
}

[PSCustomObject]@{
    DesktopMain = $desktopMain
    StartMenuMain = $startMain
    RepairedLegacyTaskbarWidget = (Test-Path -LiteralPath $legacyTaskbarWidget)
    RepairedTaskbarMain = (Test-Path -LiteralPath $taskbarMain)
}
