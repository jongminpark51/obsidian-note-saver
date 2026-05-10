@echo off
setlocal
set "SCRIPT=%~dp0ObsidianNoteSaverWidget.ps1"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%SCRIPT%"

