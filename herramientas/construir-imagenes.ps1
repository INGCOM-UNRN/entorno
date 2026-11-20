# construir-imagenes.ps1 - Arma las imagenes precompiladas del entorno que publica el workflow
# release-imagenes.yml (tambien se puede correr a mano en una maquina Windows).
#
# Uso, en este orden y sobre un entorno recien instalado desde un clon:
#   .\setup.ps1 -Yes -SkipUpdate -SinImagen -Modulos ninguno
#   .\herramientas\construir-imagenes.ps1 -Etapa base -Salida C:\imagenes
#   .\modulos\compiladores.ps1 -SinImagen
#   .\herramientas\construir-imagenes.ps1 -Etapa compiladores -Salida C:\imagenes
#
# -Etapa base          entorno-base-windows-x64.zip: los scripts versionados del repositorio
#                      mas los componentes de la base ya instalados ($ComponentesImagenBase).
#                      Se puede descomprimir y usar sin internet. Guarda ademas un inventario
#                      de msys64 para la etapa siguiente.
# -Etapa compiladores  entorno-compiladores-windows-x64.zip: los archivos de msys64 que el
#                      modulo de compiladores agrego o cambio respecto del inventario (incluye
#                      la base de datos de pacman, para que pacman los siga administrando),
#                      mas la lista de los que elimino ($ListaEliminadosCapa): sin aplicarla,
#                      una version vieja de un paquete de la base quedaria registrada junto a
#                      la nueva.
#
# Nunca se empaquetan: el HOME portable, el HOME de MSYS2 de la maquina que arma la imagen,
# temporales, la cache de pacman ni el llavero de pacman (etc/pacman.d/gnupg: su clave
# privada quedaria publicada y compartida; MSYS2 lo regenera en el primer inicio). Tampoco
# los .exe de python\*\Scripts (pip.exe y similares): guardan la ruta absoluta del python.exe
# de la maquina que armo la imagen; en la consola, bin\pip usa 'python3 -m pip'.
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("base", "compiladores")]
    [string]$Etapa,
    [Parameter(Mandatory = $true)]
    [string]$Salida
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Vive en herramientas\: la raiz del entorno es la carpeta padre
$portableRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $portableRoot "lib\instalador.ps1")

$tarExe = Join-Path $env:SystemRoot "System32\tar.exe"
if (-not (Test-Path $tarExe)) { throw "Hace falta tar.exe (Windows 10 1803 o posterior) para armar las imagenes." }
New-Item -ItemType Directory -Force -Path $Salida | Out-Null
$Salida = (Resolve-Path $Salida).Path
$inventarioPath = Join-Path $Salida "inventario-msys64.json"

# Rutas de msys64 que nunca viajan en una imagen (relativas a la raiz, con /)
$excluidos = @(
    "msys64/home", "msys64/tmp", "msys64/var/cache/pacman/pkg", "msys64/etc/pacman.d/gnupg",
    "msys64/usr/share/doc", "msys64/usr/share/man", "msys64/usr/share/info",
    "msys64/ucrt64/share/doc", "msys64/ucrt64/share/man"
)
function Test-Excluido([string]$Relativa) {
    foreach ($e in $excluidos) {
        if ($Relativa -eq $e -or $Relativa.StartsWith("$e/")) { return $true }
    }
    return $false
}

# Inventario de msys64: ruta relativa -> "tamano|fecha de modificacion" (pacman instala cada
# archivo con la fecha de su paquete: un paquete nuevo o actualizado cambia la fecha).
function Get-InventarioMsys {
    $raiz = $portableRoot.TrimEnd('\') + '\'
    $inventario = @{}
    foreach ($archivo in Get-ChildItem -Path (Join-Path $portableRoot "msys64") -Recurse -File -Force) {
        $relativa = $archivo.FullName.Substring($raiz.Length).Replace('\', '/')
        if (Test-Excluido $relativa) { continue }
        $inventario[$relativa] = "$($archivo.Length)|$($archivo.LastWriteTimeUtc.Ticks)"
    }
    return $inventario
}

# Comprime la lista de rutas (relativas a la raiz) en un .zip con tar.exe (bsdtar)
function New-Zip([string]$ZipPath, [string[]]$Rutas) {
    $listaPath = "$ZipPath.lista"
    [System.IO.File]::WriteAllLines($listaPath, $Rutas, (New-Object System.Text.UTF8Encoding($false)))
    if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
    # tmp y home no viajan (tar.exe excluye la carpeta aunque se excluya solo su contenido):
    # Initialize-PortableMsys (lib\env.common.psm1) las crea en cada sesion y en setup.ps1
    $exclusiones = @()
    foreach ($e in $excluidos) { $exclusiones += @("--exclude", $e) }
    $exclusiones += @("--exclude", "python/*/Scripts/*.exe")
    & $tarExe -a -c -f $ZipPath -C $portableRoot @exclusiones -T $listaPath
    if ($LASTEXITCODE -ne 0) { throw "tar.exe no pudo crear $ZipPath (codigo $LASTEXITCODE)." }
    Remove-Item $listaPath -Force
    Write-Host ("{0}: {1:N0} MB" -f (Split-Path $ZipPath -Leaf), ((Get-Item $ZipPath).Length / 1MB)) -ForegroundColor Green
}

if ($Etapa -eq "base") {
    foreach ($requerido in @("msys64\usr\bin\bash.exe", "mingit\cmd\git.exe", "bin\uv.exe", "python\ACTUAL")) {
        if (-not (Test-Path (Join-Path $portableRoot $requerido))) {
            throw "Falta ${requerido}: instala primero la base con setup.ps1 -SinImagen -Modulos ninguno."
        }
    }
    if (Test-Path (Join-Path $portableRoot "msys64\ucrt64\bin\gcc.exe")) {
        throw "El modulo de compiladores ya esta instalado: la imagen base tiene que armarse antes."
    }

    # Scripts versionados (sin CI ni pruebas) + componentes instalados
    $versionados = @(& git -C $portableRoot ls-files | Where-Object { $_ -notlike ".github/*" -and $_ -notlike "tests/*" })
    if ($LASTEXITCODE -ne 0 -or $versionados.Count -eq 0) { throw "No se pudo listar los archivos versionados (git ls-files)." }
    $componentes = @($ComponentesImagenBase | Where-Object { Test-Path (Join-Path $portableRoot $_) } | ForEach-Object { $_.Replace('\', '/') })
    New-Zip -ZipPath (Join-Path $Salida $NombreImagenBase) -Rutas ($versionados + $componentes)

    Write-Host "Guardando el inventario de msys64 para la capa de compiladores..." -ForegroundColor Cyan
    Get-InventarioMsys | ConvertTo-Json -Compress | Set-Content -Path $inventarioPath -Encoding UTF8
} else {
    if (-not (Test-Path $inventarioPath)) { throw "Falta ${inventarioPath}: corre primero la etapa base." }
    if (-not (Test-Path (Join-Path $portableRoot "msys64\ucrt64\bin\gcc.exe"))) {
        throw "No esta instalado el modulo de compiladores (modulos\compiladores.ps1 -SinImagen)."
    }
    $antes = @{}
    (Get-Content -Path $inventarioPath -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $antes[$_.Name] = $_.Value }
    $despues = Get-InventarioMsys
    $cambiados = @($despues.Keys | Where-Object { $antes[$_] -ne $despues[$_] } | Sort-Object)
    $eliminados = @($antes.Keys | Where-Object { -not $despues.ContainsKey($_) } | Sort-Object)
    Write-Host "Archivos de msys64 nuevos o cambiados por el modulo: $($cambiados.Count); eliminados: $($eliminados.Count)" -ForegroundColor Cyan
    if ($cambiados.Count -eq 0) { throw "El modulo de compiladores no cambio ningun archivo." }
    if ($eliminados.Count -gt 0) {
        $listaPath = $portableRoot
        foreach ($parte in $ListaEliminadosCapa.Split('/')) { $listaPath = Join-Path $listaPath $parte }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $listaPath) | Out-Null
        [System.IO.File]::WriteAllLines($listaPath, $eliminados, (New-Object System.Text.UTF8Encoding($false)))
        $cambiados += $ListaEliminadosCapa
    }
    New-Zip -ZipPath (Join-Path $Salida $NombreImagenCompiladores) -Rutas $cambiados
}
