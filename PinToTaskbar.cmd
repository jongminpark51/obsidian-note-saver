@echo off
setlocal
set "SCRIPT=%~dp0InstallShortcuts.ps1"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -OpenPinLocation
