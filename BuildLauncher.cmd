@echo off
setlocal
set "SCRIPT=%~dp0BuildLauncher.ps1"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
