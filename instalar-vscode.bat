@echo off
setlocal
:: Instala (o completa) el modulo opcional 'vscode' del entorno portable.
:: Se puede ejecutar con doble clic o desde la consola del entorno (comando: instalar vscode).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0modulos\vscode.ps1" %*
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
