# modulos/compiladores.ps1 - Modulo opcional del entorno portable: compilador de C y
# herramientas de trabajo (gcc, gdb, make, cmake, ninja, cppcheck, clang-format/tidy,
# doxygen y librerias comunes) desde pacman sobre MSYS2 UCRT64.
#
# Es la parte pesada del entorno y por eso no forma parte de la base (setup.ps1): un
# contexto que solo usa Python, git o las herramientas de la catedra no la necesita.
# Lista de paquetes: packages-compiladores.txt (fuente unica compartida con bin/).
#
# Uso:
#   instalar-compiladores.bat               (doble clic, o desde la consola: instalar compiladores)
#   powershell -File modulos\compiladores.ps1
#     -DesdeSetup  uso interno: lo invoca setup.ps1 (comparte su log de instalacion)
#
# Es idempotente: volver a ejecutarlo sincroniza pacman, actualiza el sistema e instala
# solo lo que falte (pacman --needed).
param(
    [switch]$DesdeSetup
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$portableRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $portableRoot "lib\instalador.ps1")

$msysDir = Join-Path $portableRoot "msys64"
$descargasDir = Join-Path $portableRoot "descargas"
$bashPath = Join-Path $msysDir "usr\bin\bash.exe"

if (-not (Test-Path $bashPath) -or -not (Test-Path (Join-Path $portableRoot ".msys_complete"))) {
    throw "Falta la base del entorno (MSYS2). Ejecuta primero setup.ps1."
}

$transcriptStarted = $false
if (-not $DesdeSetup) {
    try {
        Start-Transcript -Path (Join-Path $portableRoot "modulo-compiladores.log") -Force -ErrorAction Stop | Out-Null
        $transcriptStarted = $true
    } catch {
        Write-Warning "No se pudo iniciar el log del modulo. Se continua sin registrar en archivo."
    }
    Write-Host "=== Modulo de compiladores del entorno portable ===" -ForegroundColor Cyan
    Write-Host "Directorio del entorno: $portableRoot`n"
}

try {
    Assert-FreeSpace -Path $portableRoot -RequiredGB 3 -Context "el modulo de compiladores"

    $packages = Get-PackageList -Path (Join-Path $portableRoot "packages-compiladores.txt")
    $pkgString = $packages -join " "

    $cygpathExe = Join-Path $msysDir "usr\bin\cygpath.exe"
    $unixCacheDir = (& $cygpathExe -u "$descargasDir/pacman_cache").Trim()

    # La base de datos de pacman puede ser de dias atras (la base se instalo antes): instalar
    # sin sincronizar pediria versiones que el espejo ya no tiene. -Syu y luego -Su porque una
    # actualizacion del nucleo de MSYS2 se aplica en dos pasos.
    Write-Host "Sincronizando base de datos de pacman y actualizando paquetes del sistema..." -ForegroundColor Cyan
    try {
        Invoke-PacmanWithRetry -BashPath $bashPath -Arguments "-Syu --noconfirm --cachedir '$unixCacheDir'"
        Invoke-PacmanWithRetry -BashPath $bashPath -Arguments "-Su --noconfirm --cachedir '$unixCacheDir'"
    } catch {
        Write-Warning "No se pudo sincronizar pacman (posiblemente sin internet). Se intenta con la cache local..."
    }

    Write-Host "Instalando compilador y herramientas ($($packages.Count) paquetes de packages-compiladores.txt)..." -ForegroundColor Cyan
    Invoke-PacmanWithRetry -BashPath $bashPath -Arguments "-S --needed --noconfirm --cachedir '$unixCacheDir' $pkgString"

    # make.exe como ejecutable nativo en ucrt64\bin (ademas del alias interactivo de bash),
    # para que lo encuentren VS Code, CMake y los Makefile de la catedra.
    $mingwMakeExe = Join-Path $msysDir "ucrt64\bin\mingw32-make.exe"
    $makeExe = Join-Path $msysDir "ucrt64\bin\make.exe"
    if ((Test-Path $mingwMakeExe) -and -not (Test-Path $makeExe)) {
        Copy-Item -Path $mingwMakeExe -Destination $makeExe -Force
    }

    if (-not (Test-Path (Join-Path $msysDir "ucrt64\bin\gcc.exe"))) {
        throw "pacman termino pero no se encuentra gcc.exe en msys64\ucrt64\bin."
    }
    Set-Content -Path (Join-Path $portableRoot ".compiladores_complete") -Value "Complete"
    Write-Host "Modulo de compiladores instalado. Probalo en la consola con: gcc --version" -ForegroundColor Green
} finally {
    if ($transcriptStarted) {
        try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch { }
    }
}
