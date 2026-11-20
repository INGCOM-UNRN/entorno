@echo off
setlocal
:: Determinar el directorio raiz portable
set "PORTABLE_ROOT=%~dp0"

:: Delegar la inicializacion y el lanzamiento al script de PowerShell para evitar errores sintacticos de CMD y mantener el entorno unificado
powershell -NoProfile -ExecutionPolicy Bypass -File "%PORTABLE_ROOT%launch-vscode.ps1" %*
:: Si el lanzador falla, la ventana queda abierta para poder leer el error
if errorlevel 1 (
    echo.
    echo El lanzador termino con un error: revisa el mensaje de arriba.
    pause
)
