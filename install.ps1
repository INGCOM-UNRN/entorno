# install.ps1 - Bootstrap para el Entorno Portable
# Este archivo esta guardado en ASCII sin BOM para poder ejecutarse directamente desde internet:
# irm https://raw.githubusercontent.com/INGCOM-UNRN-P1/entorno/main/install.ps1 | iex
#
# Corre dentro de la ventana de PowerShell del usuario (iex): por eso nunca usa 'exit', que
# cerraria esa ventana, y todo va dentro de un bloque para no dejar cambiadas variables ni
# preferencias ($ErrorActionPreference) en la sesion.

& {
    $ErrorActionPreference = "Stop"
    # Acelerar Invoke-RestMethod/WebRequest en Windows PowerShell 5.1
    $ProgressPreference = "SilentlyContinue"
    $setupUrl = "https://raw.githubusercontent.com/INGCOM-UNRN-P1/entorno/main/setup.ps1"
    $destPath = Join-Path (Get-Location).Path "setup.ps1"

    Write-Host "Descargando script principal de instalacion..." -ForegroundColor Cyan
    try {
        # Descargar con soporte TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $content = Invoke-RestMethod -Uri $setupUrl -UseBasicParsing
        if ([string]::IsNullOrEmpty($content)) {
            throw "El archivo descargado esta vacio."
        }
        # Remover el BOM si viene en el texto remoto
        $content = $content.TrimStart([char]0xFEFF)
        # Escribir setup.ps1 local sin BOM (los scripts PS del entorno son ASCII puro)
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($destPath, $content, $utf8NoBom)
    } catch {
        Write-Host ""
        Write-Host "No se pudo descargar setup.ps1: $_" -ForegroundColor Red
        Write-Host "Revisa la conexion a internet y volve a ejecutar el comando." -ForegroundColor Yellow
        if (-not $env:CI) {
            try {
                if (-not [Console]::IsInputRedirected -and [Environment]::UserInteractive) {
                    $null = Read-Host "Presiona Enter para terminar"
                }
            } catch { }
        }
        return
    }

    Write-Host "`n======================================================================" -ForegroundColor Green
    Write-Host " DESCARGA DE SETUP COMPLETADA. INICIANDO INSTALACION..." -ForegroundColor Green
    Write-Host "======================================================================`n" -ForegroundColor Green

    # setup.ps1 muestra sus propios errores y espera antes de terminar: aca solo se evita que
    # el error se repita y se deja la ventana abierta.
    try {
        & $destPath @args
    } catch {
        Write-Host "La instalacion no termino correctamente (detalle arriba y en install.log)." -ForegroundColor Red
    }
} @args
