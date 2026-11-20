@echo off
setlocal
:: Cambiar al directorio del script
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0herramientas\customize-terminal.ps1"
pause
