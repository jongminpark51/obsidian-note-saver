@echo off
setlocal
set "SCRIPT=%~dp0ObsidianNoteSaver.ps1"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%SCRIPT%"

