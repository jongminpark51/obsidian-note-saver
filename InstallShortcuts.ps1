param(
    [switch]$OpenPinLocation
)

$ErrorActionPreference = 'Stop'

$ProjectDir = $PSScriptRoot
$MainCmd = Join-Path $ProjectDir 'ObsidianNoteSaver.cmd'
$MainScript = Join-Path $ProjectDir 'ObsidianNoteSaver.ps1'
$IconPath = Join-Path $ProjectDir 'Assets\obsidian-note-saver-penguin.ico'
$PowerShellExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$OneDriveDesktop = Join-Path $env:USERPROFILE 'OneDrive\Desktop'
$Desktop = [Environment]::GetFolderPath('Desktop')
if (Test-Path -LiteralPath $OneDriveDesktop) {
    $Desktop = $OneDriveDesktop
}
elseif ([string]::IsNullOrWhiteSpace($Desktop)) {
    $Desktop = Join-Path $env:USERPROFILE 'Desktop'
}

$StartMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Obsidian Note Saver'

New-Item -ItemType Directory -Force -Path $Desktop, $StartMenuDir | Out-Null

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
$mainArgs = "-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File `"$MainScript`""

New-AppShortcut -Path $desktopMain -Target $PowerShellExe -Arguments $mainArgs -Description 'Save quick notes into Obsidian' -Hotkey 'CTRL+ALT+O'
New-AppShortcut -Path $startMain -Target $PowerShellExe -Arguments $mainArgs -Description 'Save quick notes into Obsidian'

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
}
