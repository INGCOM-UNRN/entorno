@echo off
setlocal
:: Instala (o completa) el modulo opcional 'compiladores' del entorno portable.
:: Se puede ejecutar con doble clic o desde la consola del entorno (comando: instalar compiladores).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0modulos\compiladores.ps1" %*
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
