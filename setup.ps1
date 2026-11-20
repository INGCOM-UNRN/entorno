# setup.ps1 - Instalador del entorno portable (Windows), en dos fases:
#
#   1. Base (este script): MSYS2 (bash), Git (MinGit), uv, Python con las dependencias de
#      las herramientas de la catedra, GitHub CLI, jonesy, WezTerm y Ripley. Es liviana, no
#      usa pacman y alcanza para usar el entorno en contextos que no compilan C.
#   2. Modulos opcionales (modulos\*.ps1), instalables en cualquier momento:
#        compiladores  gcc, gdb, make, cmake y herramientas de analisis (pacman)
#        vscode        VS Code portable con sus extensiones
#      Al terminar la base se ofrece instalarlos; despues: instalar-compiladores.bat,
#      instalar-vscode.bat o, desde la consola, 'instalar compiladores|vscode'.
#
# -Modulos: compiladores, vscode, todos o ninguno (se aceptan varios: -Modulos compiladores,vscode).
#   Sin el parametro, una instalacion nueva pregunta por cada modulo (-Yes los instala todos)
#   y una actualizacion actualiza solo los modulos que ya estaban instalados.
param(
    [string]$HomeDirName = "home",
    [switch]$ImportHostConfig,
    [switch]$SkipUpdate,
    [switch]$Yes,
    [switch]$Latest,
    [string[]]$Modulos
)

# ------------------------------------------------------------------
# La ventana no desaparece al terminar
# ------------------------------------------------------------------
# Si setup.ps1 se abre con "Ejecutar con PowerShell", desde un .bat o desde update-env.sh,
# la ventana se cierra en cuanto termina el script: un error se veria un instante y nada mas.
# Por eso espera una tecla al final, con exito o con error. Solo pausa la ejecucion externa
# (al relanzarse tras autoactualizarse, P1_SETUP_RELANZADO marca la interna) y nunca sin
# consola interactiva (-Yes, CI). Se define aca y no en lib\: install.ps1 descarga solo
# setup.ps1, asi que en la primera ejecucion lib\ todavia no existe.
$script:esEjecucionRaiz = ($env:P1_SETUP_RELANZADO -ne "1")
$script:pausaHecha = $false
$script:instalacionOk = $false
$script:modulosFallidos = @()
function Wait-FinSetup {
    param([switch]$ConError, [string]$Mensaje = "")
    if (-not $script:esEjecucionRaiz -or $script:pausaHecha) { return }
    $script:pausaHecha = $true
    if ($ConError) {
        Write-Host ""
        Write-Host "La instalacion no termino: revisa el error de arriba (el detalle completo queda en install.log)." -ForegroundColor Red
        Write-Host "Podes volver a ejecutar setup.ps1: retoma lo pendiente y reutiliza lo ya descargado." -ForegroundColor Yellow
    }
    if ($Mensaje) { Write-Host $Mensaje -ForegroundColor Yellow }
    if ($Yes -or $env:CI) { return }
    try {
        if ([Console]::IsInputRedirected) { return }
    } catch {
        return
    }
    if (-not [Environment]::UserInteractive) { return }
    Write-Host ""
    $null = Read-Host "Presiona Enter para terminar"
}
# Cualquier error no manejado (tambien los de antes del bloque principal) se muestra y espera
trap {
    Write-Host ""
    Write-Host "ERROR: $_" -ForegroundColor Red
    Wait-FinSetup -ConError
    break
}

$ErrorActionPreference = "Stop"

# Acelerar Invoke-WebRequest en Windows PowerShell 5.1 (la barra de progreso es hasta 10x mas lenta)
$ProgressPreference = "SilentlyContinue"

# Compatibilidad PowerShell 7 (pwsh): el instalador se valida contra Windows PowerShell 5.1.
# Bajo pwsh funciona en modo informativo, pero diferencias de encoding y ConvertTo-Json
# pueden producir resultados distintos; ante dudas, ejecutar con 'powershell' clasico.
if ($PSVersionTable.PSVersion.Major -ge 6) {
    Write-Warning "Estas ejecutando setup.ps1 con PowerShell $($PSVersionTable.PSVersion) (pwsh)."
    Write-Warning "La validacion completa de la catedra es sobre Windows PowerShell 5.1 ('powershell')."
    Write-Warning "Si algo falla de forma extrana (encoding, JSON), proba primero con: powershell -ExecutionPolicy Bypass -File setup.ps1"
}

function Test-IsDirectHomePath {
    <#
    .SYNOPSIS
    Verifica si una ruta dada coincide con el directorio HOME / UserProfile del host.
    #>
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }
    if ($Path -eq "~") {
        return $true
    }
    try {
        $resolved = [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
        $candidates = @()
        if ($HOME) {
            $candidates += [System.IO.Path]::GetFullPath($HOME).TrimEnd('\', '/')
        }
        if ($env:USERPROFILE) {
            $candidates += [System.IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\', '/')
        }
        $specialProfile = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
        if ($specialProfile) {
            $candidates += [System.IO.Path]::GetFullPath($specialProfile).TrimEnd('\', '/')
        }

        foreach ($cand in $candidates) {
            if ([string]::Equals($resolved, $cand, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }
    } catch {
        return $false
    }
    return $false
}

# Directorio base del script (con fallback al directorio actual si se ejecuta desde internet via IEX)
$portableRoot = $PSScriptRoot
if ([string]::IsNullOrEmpty($portableRoot)) {
    $portableRoot = (Get-Location).Path
}

# Evitar la instalacion directa en el HOME / perfil de usuario
if (Test-IsDirectHomePath -Path $portableRoot) {
    Write-Host "==========================================================================" -ForegroundColor Red
    Write-Host "ERROR: NO SE PUEDE INSTALAR DIRECTAMENTE EN EL DIRECTORIO DE USUARIO (`$HOME)" -ForegroundColor Red
    Write-Host "==========================================================================" -ForegroundColor Red
    Write-Host "La ruta de instalacion coincide con tu directorio personal:" -ForegroundColor Yellow
    Write-Host "  $portableRoot" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Instalar directamente en el HOME rompe el aislamiento del entorno portable"
    Write-Host "y mezcla herramientas (msys64, vscode, bin, .env, descargas) con tus archivos."
    Write-Host ""
    Write-Host "Crea una subcarpeta dedicada y ejecuta el instalador desde alli."
    Write-Host "Ejemplos recomendados:"
    Write-Host "  mkdir C:\dev\entorno; cd C:\dev\entorno"
    Write-Host "  (o adentro de una subcarpeta: $(Join-Path $portableRoot 'entorno'))"
    Write-Host "==========================================================================" -ForegroundColor Red
    throw "Instalacion cancelada: no esta permitido instalar directamente en `$HOME ($portableRoot)."
}

if (-not ($HomeDirName -match "^[a-zA-Z0-9_][a-zA-Z0-9_-]*$")) {
    $HomeDirName = "home"
}
$msysDir = Join-Path $portableRoot "msys64"
$descargasDir = Join-Path $portableRoot "descargas"
$homeDir = Join-Path $portableRoot $HomeDirName
$vscodeDir = Join-Path $portableRoot "vscode"
$isUpdateMode = Test-Path (Join-Path $portableRoot ".install_complete")

# Funciones compartidas con los modulos (descargas, pines de versions.json, pacman)
$libPath = Join-Path $portableRoot "lib\instalador.ps1"
# Codificacion UTF-8 sin BOM para los archivos que genera el instalador
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Modulos opcionales: se validan antes de empezar para no fallar a mitad de la instalacion
$modulosValidos = @("compiladores", "vscode")
$modulosPedidos = $null
if ($PSBoundParameters.ContainsKey('Modulos')) {
    $modulosPedidos = @()
    foreach ($nombre in @($Modulos | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })) {
        if ($nombre -eq "todos") {
            $modulosPedidos = @($modulosValidos)
        } elseif ($nombre -eq "ninguno") {
            $modulosPedidos = @()
        } elseif ($modulosValidos -contains $nombre) {
            if ($modulosPedidos -notcontains $nombre) { $modulosPedidos += $nombre }
        } else {
            throw "Modulo desconocido '$nombre'. Valores validos: compiladores, vscode, todos, ninguno."
        }
    }
}

# Iniciar log de instalacion
$logPath = Join-Path $portableRoot "install.log"
$transcriptStarted = $false
try {
    Start-Transcript -Path $logPath -Force -ErrorAction Stop | Out-Null
    $transcriptStarted = $true
} catch {
    Write-Warning "No se pudo iniciar el log oficial de PowerShell. La instalacion continuara sin registrar salida en archivo."
}

# Escribir informacion del entorno y fecha/hora de inicio en el log
Write-Host "======================================================================"
Write-Host "LOG DE INSTALACION DETALLADO"
Write-Host "======================================================================"
Write-Host "Fecha/Hora de Inicio : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$versionFile = Join-Path $portableRoot "VERSION"
$entornoVersion = "?"
if (Test-Path $versionFile) { $entornoVersion = (Get-Content $versionFile -Raw).Trim() }
Write-Host "Version del Entorno  : $entornoVersion"
if ($PSVersionTable.PSVersion.Major -ge 6) {
    Write-Host "Aviso de Compatibilidad: estas ejecutando PowerShell $($PSVersionTable.PSVersion); el instalador esta validado principalmente sobre Windows PowerShell 5.1." -ForegroundColor Yellow
}
Write-Host "Entorno de Ejecucion : $($PSVersionTable.OS) / OS: $($env:OS)"
Write-Host "Nombre del Equipo    : $($env:COMPUTERNAME)"
Write-Host "Usuario Ejecutor     : $($env:USERNAME)"
Write-Host "Version PowerShell   : $($PSVersionTable.PSVersion)"
Write-Host "Ruta de la Carpeta   : $portableRoot"
Write-Host "Parametros Utilizados: -HomeDirName '$HomeDirName' -ImportHostConfig: $ImportHostConfig -Modulos: $(if ($null -eq $modulosPedidos) { '(preguntar)' } else { ($modulosPedidos -join ',') })"
Write-Host "Modo de Ejecucion    : $(if ($isUpdateMode) { 'Actualizacion' } else { 'Instalacion/Finalizacion' })"
Write-Host "======================================================================`n"

try {
    # ==========================================
    # 0. Actualizacion automatica de scripts
    # ==========================================
    # Una sola vez por ejecucion (P1_SETUP_RELANZADO): si el canal configurado es anterior a los
    # modulos, el snapshot tampoco los trae y relanzar de nuevo seria un bucle.
    $archivosRequeridos = @("lib\instalador.ps1", "lib\env.common.psm1", "modulos", "config\versions.json")
    $faltanArchivosNuevos = ($env:P1_SETUP_RELANZADO -ne "1") -and
        (@($archivosRequeridos | Where-Object { -not (Test-Path (Join-Path $portableRoot $_)) }).Count -gt 0)
    if ($SkipUpdate -and $faltanArchivosNuevos) {
        Write-Host "Faltan archivos del instalador (lib\, modulos\, config\): se descargan aunque se pidio -SkipUpdate." -ForegroundColor Yellow
    }
    if ($SkipUpdate -and -not $faltanArchivosNuevos) {
        Write-Host "=== Omitiendo actualizacion de scripts (-SkipUpdate) ===" -ForegroundColor DarkGray
    } else {
        Write-Host "=== Comprobando actualizaciones de los scripts del entorno ===" -ForegroundColor Cyan
        
        $didUpdate = $false
        $repoOwner = "INGCOM-UNRN-P1"
    $repoName = "entorno"
    # Canal de actualizacion configurable via .env (ej: CHANNEL=estable-2026c1).
    # Solo aplica a instalaciones standalone; en repos Git rige la rama local.
    $branch = "main"
    $envFileEarly = Join-Path $portableRoot ".env"
    if (Test-Path $envFileEarly) {
        $envRawEarly = Get-Content $envFileEarly -Raw
        if ($envRawEarly -match '(?m)^CHANNEL=([^\s#]+)') {
            $branch = $Matches[1].Trim()
            Write-Host "Canal de scripts configurado: $branch" -ForegroundColor DarkGray
        }
    }
    $rawBaseUrl = "https://raw.githubusercontent.com/$repoOwner/$repoName/$branch"
    $isGitRepo = Test-Path (Join-Path $portableRoot ".git")

    if ($isGitRepo) {
        Write-Host "Repositorio Git detectado. Intentando actualizar via 'git pull'..." -ForegroundColor Cyan
        
        # Git del entorno (MinGit), el de MSYS2 de instalaciones anteriores o el del sistema
        $gitExe = "git"
        foreach ($candidatoGit in @((Join-Path $portableRoot "mingit\cmd\git.exe"), (Join-Path $portableRoot "msys64\usr\bin\git.exe"))) {
            if (Test-Path $candidatoGit) { $gitExe = $candidatoGit; break }
        }
        
        try {
            $process = Start-Process -FilePath $gitExe -ArgumentList "pull" -WorkingDirectory $portableRoot -Wait -NoNewWindow -PassThru -ErrorAction Stop
            if ($process.ExitCode -eq 0) {
                Write-Host "Scripts actualizados con exito a traves de Git.`n" -ForegroundColor Green
                $didUpdate = $true
            } else {
                Write-Warning "Fallo al realizar git pull (codigo de salida: $($process.ExitCode)). Se continuara con la ejecucion local."
            }
        } catch {
            Write-Warning "No se pudo ejecutar git para la actualizacion automatica: $_. Se continuara con la ejecucion local."
        }
    } else {
        $hasExistingScripts = Test-Path (Join-Path $portableRoot "launch.bat")
        $shouldUpdate = $true
        
        if ($hasExistingScripts) {
            Write-Host "Se detectaron scripts de consola existentes en el directorio." -ForegroundColor Yellow
            if ($Yes) {
                Write-Host "(--Yes) Actualizando scripts automaticamente..." -ForegroundColor DarkGray
            } elseif ((Read-Host "Deseas actualizar todos los scripts del entorno a la ultima version desde GitHub? (s/n)") -notmatch "^[sS]$") {
                $shouldUpdate = $false
                Write-Host "Se omite la actualizacion de los scripts. Se utilizaran las versiones locales.`n" -ForegroundColor Yellow
            }
        }
        
        if ($shouldUpdate) {
            Write-Host "No se detecto un repositorio de Git (carpeta standalone). Descargando snapshot del repositorio..." -ForegroundColor Cyan
            
            if (-not (Test-Path $descargasDir)) {
                New-Item -ItemType Directory -Path $descargasDir | Out-Null
            }
            
            $zipUrl = "https://github.com/$repoOwner/$repoName/archive/refs/heads/$branch.zip"
            $zipPath = Join-Path $descargasDir "repo_temp.zip"
            $extractTempDir = Join-Path $descargasDir "repo_extracted"
            
            # Limpiar directorio de extraccion si ya existia
            if (Test-Path $extractTempDir) {
                Remove-Item -Path $extractTempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            
            try {
                Write-Host "Descargando snapshot del repositorio desde GitHub..." -ForegroundColor Gray
                # Descarga con reintentos
                $attempts = 0
                $success = $false
                while (-not $success -and $attempts -lt 3) {
                    $attempts++
                    try {
                        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
                        $success = $true
                    } catch {
                        if ($attempts -lt 3) {
                            Start-Sleep -Seconds 1
                        } else {
                            throw $_
                        }
                    }
                }
                
                Write-Host "Extrayendo archivos del snapshot..." -ForegroundColor Gray
                Expand-Archive -Path $zipPath -DestinationPath $extractTempDir -Force
                
                $extractedRepoDir = Join-Path $extractTempDir "$repoName-$branch"
                if (-not (Test-Path $extractedRepoDir)) {
                    throw "No se pudo encontrar la carpeta extraida '$repoName-$branch' en el archivo zip."
                }
                
                # Se copia el snapshot completo del repositorio: solo contiene archivos versionados
                # (nunca msys64, vscode, python, el HOME portable ni descargas), asi que cualquier
                # script nuevo llega sin mantener una lista a mano.
                $extractedRepoFull = (Resolve-Path $extractedRepoDir).Path.TrimEnd('\', '/')
                foreach ($srcItem in @(Get-ChildItem -Path $extractedRepoFull -Recurse -File -Force)) {
                    $relativePath = $srcItem.FullName.Substring($extractedRepoFull.Length + 1)
                    if ($relativePath -like ".github*") { continue }
                    $destPath = Join-Path $portableRoot $relativePath
                    $parentDir = Split-Path -Parent $destPath
                    if (-not (Test-Path $parentDir)) {
                        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                    }
                    Copy-Item -Path $srcItem.FullName -Destination $destPath -Force
                    # Los scripts PS son ASCII puro: quitar el BOM que traigan versiones anteriores
                    if ($relativePath -like "*.ps1" -or $relativePath -like "*.psm1") {
                        $content = [System.IO.File]::ReadAllText($destPath, [System.Text.Encoding]::UTF8)
                        [System.IO.File]::WriteAllText($destPath, $content, $utf8NoBom)
                    }
                }

                Write-Host "Actualizacion de scripts completada con exito.`n" -ForegroundColor Green
                $didUpdate = $true
            } catch {
                Write-Warning "Fallo al descargar o extraer la actualizacion de los scripts: $_"
            } finally {
                # Limpieza final de temporales
                if (Test-Path $extractTempDir) {
                    Remove-Item -Path $extractTempDir -Recurse -Force -ErrorAction SilentlyContinue
                }
                if (Test-Path $zipPath) {
                    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    if ($didUpdate) {
        Write-Host "Relanzando setup.ps1 para aplicar la version mas reciente en memoria..." -ForegroundColor Magenta
        $newArgs = @{
            SkipUpdate = $true
        }
        if ($HomeDirName -ne "home") { $newArgs["HomeDirName"] = $HomeDirName }
        if ($ImportHostConfig) { $newArgs["ImportHostConfig"] = $true }
        if ($Yes) { $newArgs["Yes"] = $true }
        if ($Latest) { $newArgs["Latest"] = $true }
        if ($PSBoundParameters.ContainsKey('Modulos')) { $newArgs["Modulos"] = $Modulos }
        
        $localSetup = Join-Path $portableRoot "setup.ps1"
        $env:P1_SETUP_RELANZADO = "1"
        & $localSetup @newArgs
        # Si la ejecucion interna fallo, su error llega hasta aca y lo atiende el trap
        $script:instalacionOk = $true
        exit 0
    }
}

if (-not (Test-Path $libPath)) {
    throw "Falta $libPath. Volve a descargar el entorno completo (o ejecuta setup.ps1 sin -SkipUpdate)."
}
. $libPath
Import-Module (Join-Path $portableRoot "lib\env.common.psm1") -Force

# La raiz del repositorio se reorganizo: la autoactualizacion copia los archivos en su lugar
# nuevo pero no borra los viejos. En instalaciones sin git se quitan las copias obsoletas de
# la raiz (solo si ya existe la nueva); en un repositorio git eso lo resuelve git pull.
if (-not (Test-Path (Join-Path $portableRoot ".git"))) {
    $archivosMovidos = [ordered]@{
        "env.common.psm1"           = "lib\env.common.psm1"
        "versions.json"             = "config\versions.json"
        "packages-baseline.txt"     = "config\packages-compiladores.txt"
        "wezterm.lua.template"      = "config\wezterm.lua.template"
        "clean-shared-host.ps1"     = "herramientas\clean-shared-host.ps1"
        "customize-terminal.ps1"    = "herramientas\customize-terminal.ps1"
        "fix-antivirus.ps1"         = "herramientas\fix-antivirus.ps1"
        "package-env.ps1"           = "herramientas\package-env.ps1"
        "smoke.ps1"                 = "herramientas\smoke.ps1"
        "plan.md"                   = "docs\desarrollo\plan.md"
        "mejoras-y-problemas.md"    = "docs\desarrollo\mejoras-y-problemas.md"
    }
    foreach ($viejo in $archivosMovidos.Keys) {
        $rutaVieja = Join-Path $portableRoot $viejo
        if ((Test-Path $rutaVieja) -and (Test-Path (Join-Path $portableRoot $archivosMovidos[$viejo]))) {
            Remove-Item -Path $rutaVieja -Force -ErrorAction SilentlyContinue
        }
    }
}

# Manifiesto de versiones por cuatrimestre (config\versions.json); -Latest lo ignora
$pinnedVersions = Read-VersionManifest -Path (Join-Path $portableRoot "config\versions.json") -Latest:$Latest

# Escribir archivo de configuracion .env local. Se reemplaza solo HOME_DIR_NAME: el resto de
# las claves (por ejemplo CHANNEL, el canal de actualizacion) se conserva.
$envFilePath = Join-Path $portableRoot ".env"
$envLines = @()
if (Test-Path $envFilePath) {
    $envLines = @(Get-Content $envFilePath | Where-Object { $_ -notmatch 'HOME_DIR_NAME=' })
}
$envLines = @(('set "HOME_DIR_NAME={0}"' -f $HomeDirName)) + $envLines
Set-Content -Path $envFilePath -Value $envLines

# Asegurar que el archivo .env, el directorio personalizado y la carpeta descargas esten excluidos en .gitignore
$gitignorePath = Join-Path $portableRoot ".gitignore"
if (Test-Path $gitignorePath) {
    $gitignoreContent = Get-Content $gitignorePath -Raw
    if (-not $gitignoreContent.Contains(".env")) {
        Add-Content -Path $gitignorePath -Value "`n# Local environment config`n.env"
    }
    $ignoreRule = "$HomeDirName/"
    if (-not $gitignoreContent.Contains($ignoreRule)) {
        Add-Content -Path $gitignorePath -Value "`n# Custom home folder`n$ignoreRule"
    }
    if (-not $gitignoreContent.Contains("descargas/")) {
        Add-Content -Path $gitignorePath -Value "`n# Persistent downloads cache`ndescargas/"
    }
}

Write-Host "=== Entorno Portable de Desarrollo C + Python (instalacion base) ===" -ForegroundColor Cyan
if ($isUpdateMode) {
    Write-Host ">>> MODO ACTUALIZACION: Se detecto una instalacion previa completa. <<<" -ForegroundColor Green
} else {
    Write-Host ">>> MODO INSTALACION/FINALIZACION: Completando o finalizando instalacion... <<<" -ForegroundColor Yellow
}
Write-Host "Directorio de instalacion: $portableRoot`n"

# Validar espacios, caracteres no ASCII o carpetas sincronizadas en la ruta (causan errores con Make/compiladores)
$hasSpaces = $portableRoot -match ' '
$hasNonAscii = $portableRoot -match '[^\u0000-\u007F]'
$hasSyncFolder = $portableRoot -match '(?i)onedrive|dropbox|google\s+drive|icloud'

if ($hasSpaces -or $hasNonAscii -or $hasSyncFolder) {
    Write-Host "==========================================================================" -ForegroundColor Yellow
    Write-Host "ADVERTENCIA: RUTA CON POSIBLES CONFLICTOS DETECTADA" -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Yellow
    if ($hasSpaces) {
        Write-Host "* La ruta de instalacion contiene espacios en blanco." -ForegroundColor Yellow
    }
    if ($hasNonAscii) {
        Write-Host "* La ruta de instalacion contiene caracteres no ASCII (acentos, enes, etc.)." -ForegroundColor Yellow
    }
    if ($hasSyncFolder) {
        Write-Host "* La ruta esta dentro de una carpeta sincronizada (OneDrive/Dropbox/etc.)," -ForegroundColor Yellow
        Write-Host "  conocida por corromper instalaciones y compilaciones." -ForegroundColor Yellow
    }
    Write-Host "--------------------------------------------------------------------------"
    Write-Host "Muchas herramientas de compilacion de C (como Make, CMake y compiladores)"
    Write-Host "fallan o tienen comportamientos erraticos con este tipo de rutas."
    Write-Host "Se recomienda mover la carpeta a una ruta simple (Ej: C:\dev\entorno)."
    Write-Host "--------------------------------------------------------------------------"

    if ($Yes) {
        Write-Host "(--Yes) Continuando con la instalacion bajo riesgo del usuario...`n" -ForegroundColor Yellow
    } else {
        $choice = Read-Host "Deseas continuar con la instalacion de todas formas? (s/n)"
        if ($choice -notmatch "^[sS]$") {
            Write-Host "Instalacion cancelada." -ForegroundColor Red
            Wait-FinSetup
            return
        }
        Write-Host "Continuando con la instalacion bajo riesgo del usuario...`n" -ForegroundColor Yellow
    }
}

# Asegurar que existan los directorios iniciales y sus archivos skel
if (-not (Test-Path $homeDir)) {
    New-Item -ItemType Directory -Path $homeDir | Out-Null
    Write-Host "Creado directorio HOME portable: $homeDir" -ForegroundColor Green
}

# ==========================================
# 0.5 Preflight de recursos
# ==========================================
# Espacio en disco para la base; cada modulo verifica lo suyo antes de descargar.
Assert-FreeSpace -Path $portableRoot -RequiredGB 2 -Context "la instalacion base"
# Rutas largas: msys64 agrega profundidad significativa; el limite clasico es 260 caracteres.
if ($portableRoot.Length -gt 100) {
    Write-Warning ("La ruta de instalacion tiene {0} caracteres y puede exceder el limite clasico de 260 al extraer MSYS2." -f $portableRoot.Length)
    Write-Warning "Si la extraccion falla con 'path too long', move el entorno a una ruta mas corta (ej: C:\dev\entorno)."
}

$bashProfilePath = Join-Path $homeDir ".bash_profile"
if (-not (Test-Path $bashProfilePath)) {
    $bashProfileContent = "if [ -f `"`${HOME}/.bashrc`" ] ; then`n  source `"`${HOME}/.bashrc`"`nfi"
    [System.IO.File]::WriteAllText($bashProfilePath, $bashProfileContent, $utf8NoBom)
}

$bashrcPath = Join-Path $homeDir ".bashrc"
if (-not (Test-Path $bashrcPath)) {
    $bashrcContent = "# .bashrc`n# Aqui podes agregar tus alias y funciones personalizadas.`n`n# Agregar bin portable al PATH en formato Unix (sin duplicar en shells anidados)`nif [ -n `"`$PORTABLE_ROOT`" ]; then`n    UNIX_ROOT=`$`(cygpath -u `"`$PORTABLE_ROOT`"` 2>/dev/null || echo `"`$PORTABLE_ROOT`"`)`n    case `":`$PATH:`" in`n        *`":`${UNIX_ROOT}/bin:`"*|*`":`${UNIX_ROOT}/linux/bin:`"*) : ;;`n        *) export PATH=`"`${UNIX_ROOT}/bin:`${UNIX_ROOT}/linux/bin:`${UNIX_ROOT}/local/bin:`${UNIX_ROOT}/msys64/ucrt64/bin:`${UNIX_ROOT}/msys64/usr/bin:`$PATH`" ;;`n    esac`nfi`n"
    [System.IO.File]::WriteAllText($bashrcPath, $bashrcContent, $utf8NoBom)
}

if (-not (Test-Path $descargasDir)) {
    New-Item -ItemType Directory -Path $descargasDir | Out-Null
}

# ==========================================
# 1. Gestion e Instalacion de MSYS2
# ==========================================
$isMsysInstalled = Test-Path (Join-Path $msysDir "usr\bin\bash.exe")
$isMsysComplete = Test-Path (Join-Path $portableRoot ".msys_complete")

if (-not $isMsysInstalled -or -not $isMsysComplete) {
    if (-not $isMsysInstalled) {
        Write-Host "[Instalacion] MSYS2 no detectado. Iniciando descarga..." -ForegroundColor Yellow

        # MSYS2 puede estar fijado en versions.json (canal reproducible)
        $downloadUrl = Get-Pinned 'msys2'
        if ($downloadUrl) {
            $fileName = Split-Path $downloadUrl -Leaf
            Write-Host "MSYS2 fijado por el manifiesto de versiones: $fileName" -ForegroundColor DarkGray
        }

        if (-not $downloadUrl) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $releasesUrl = "https://api.github.com/repos/msys2/msys2-installer/releases"
            Write-Host "Consultando API de GitHub por la ultima version de MSYS2..."
            $releases = Get-GitHubApiCached -Url $releasesUrl
            # Buscar la primera version que no sea un build 'nightly' y que contenga el archivo sfx.exe
            foreach ($release in $releases) {
                if ($release.tag_name -notlike "*nightly*") {
                    $asset = $release.assets | Where-Object { $_.name -like "msys2-base-x86_64-*.sfx.exe" }
                    if ($asset) {
                        $downloadUrl = $asset.browser_download_url
                        $fileName = $asset.name
                        Write-Host "Ultima version estable detectada: $fileName (Tag: $($release.tag_name))" -ForegroundColor Green
                        break
                    }
                }
            }
        } catch {
            Write-Warning "Fallo al consultar la API de GitHub. Usando fallback fijo."
        }
        } # fin if (-not $downloadUrl)

        if (-not $downloadUrl) {
            $downloadUrl = if ($pinF = Get-Pinned 'msys2_fallback') { $pinF } else { "https://github.com/msys2/msys2-installer/releases/download/2025-02-21/msys2-base-x86_64-20250221.sfx.exe" }
            $fileName = Split-Path $downloadUrl -Leaf
            Write-Host "Fallback URL: $downloadUrl" -ForegroundColor Yellow
        }

        $exePath = Join-Path $descargasDir $fileName
        $shaPath = "$exePath.sha256"
        $shaUrl = "$downloadUrl.sha256"
        $isDownloadedAndValid = $false

        # Verificar si ya existe una descarga previa valida para evitar descargas duplicadas en reintentos
        if (Test-Path $exePath) {
            Write-Host "Se detecto un instalador de MSYS2 descargado previamente. Verificando firma..." -ForegroundColor Yellow
            try {
                if (-not (Test-Path $shaPath)) {
                    Invoke-WebRequest -Uri $shaUrl -OutFile $shaPath -UseBasicParsing -ErrorAction Stop
                }
                $shaContent = (Get-Content $shaPath -Raw).Trim()
                if ($shaContent -match '<html' -or $shaContent -match '<!DOCTYPE') {
                    throw "El archivo de firma contiene HTML (posible pagina de error del servidor)."
                }
                $expectedHash = $shaContent.Split(" ")[0].Trim().ToLower()
                if ($expectedHash -notmatch '^[0-9a-f]{64}$') {
                    $truncatedHash = $expectedHash
                    if ($truncatedHash.Length -gt 100) { $truncatedHash = $truncatedHash.Substring(0, 100) + "..." }
                    throw "El hash esperado recuperado no tiene un formato SHA256 valido: '$truncatedHash'"
                }
                $actualHash = (Get-FileHash -Path $exePath -Algorithm SHA256).Hash.ToLower()
                if ($actualHash -eq $expectedHash) {
                    $isDownloadedAndValid = $true
                    Write-Host "El archivo existente es valido. Se omitira la descarga." -ForegroundColor Green
                } else {
                    Write-Host "La firma del archivo existente no coincide. Se procedera a descargar nuevamente." -ForegroundColor Yellow
                    Remove-Item -Path $shaPath -Force -ErrorAction SilentlyContinue
                    Remove-Item -Path $exePath -Force -ErrorAction SilentlyContinue
                }
            } catch {
                Write-Host "No se pudo verificar la firma del archivo existente. Se procedera a descargar nuevamente. Detalles: $_" -ForegroundColor Yellow
                Remove-Item -Path $shaPath -Force -ErrorAction SilentlyContinue
            }
        }

        if (-not $isDownloadedAndValid) {
            Write-Host "Descargando $fileName..." -ForegroundColor Cyan
            Invoke-DownloadWithRetry -Url $downloadUrl -OutFile $exePath

            Write-Host "Descargando verificacion SHA256..." -ForegroundColor Cyan
            try {
                $attempts = 0
                $success = $false
                while (-not $success -and $attempts -lt 3) {
                    $attempts++
                    try {
                        Invoke-WebRequest -Uri $shaUrl -OutFile $shaPath -UseBasicParsing -ErrorAction Stop
                        $success = $true
                    } catch {
                        if ($attempts -lt 3) {
                            Start-Sleep -Seconds 1
                        } else {
                            throw $_
                        }
                    }
                }
            } catch {
                throw "Error fatal al descargar el archivo de firma SHA256 desde: $shaUrl. Detalles: $_"
            }

            try {
                $shaContent = (Get-Content $shaPath -Raw).Trim()
                if ($shaContent -match '<html' -or $shaContent -match '<!DOCTYPE') {
                    throw "El archivo de firma contiene HTML (posible pagina de error del servidor o rate limit)."
                }
                $expectedHash = $shaContent.Split(" ")[0].Trim().ToLower()
                if ($expectedHash -notmatch '^[0-9a-f]{64}$') {
                    $truncatedHash = $expectedHash
                    if ($truncatedHash.Length -gt 100) { $truncatedHash = $truncatedHash.Substring(0, 100) + "..." }
                    throw "El hash esperado recuperado no tiene un formato SHA256 valido: '$truncatedHash'"
                }
                $actualHash = (Get-FileHash -Path $exePath -Algorithm SHA256).Hash.ToLower()

                if ($actualHash -ne $expectedHash) {
                    throw "El hash calculado ($actualHash) no coincide con el esperado ($expectedHash)."
                }
                Write-Host "Firma SHA256 verificada con exito." -ForegroundColor Green
            } catch {
                Remove-Item -Path $shaPath -Force -ErrorAction SilentlyContinue
                throw "Falla critica en la verificacion de firma SHA256. La instalacion se detiene. Detalles: $_"
            }
        }

        Write-Host "Extrayendo entorno base MSYS2 en: $portableRoot" -ForegroundColor Cyan
        $process = Start-Process -FilePath $exePath -ArgumentList "-y", "-o$portableRoot" -Wait -NoNewWindow -PassThru
        if ($process.ExitCode -ne 0) {
            throw "Error durante la extraccion de MSYS2 (codigo de salida: $($process.ExitCode))"
        }
        Write-Host "Instalacion base de MSYS2 completada con exito.`n" -ForegroundColor Green
    } else {
        Write-Host "Se detecto una instalacion previa incompleta de MSYS2. Intentando continuar con la instalacion existente..." -ForegroundColor Yellow
    }
} else {
    Write-Host "[Actualizacion] MSYS2 base ya instalado y verificado." -ForegroundColor Green
}

if ($isUpdateMode -or -not $isMsysComplete) {
    # ==========================================
    # 2. Inicializacion y Actualizacion de MSYS2
    # ==========================================
    Write-Host "Inicializando entorno de consola..." -ForegroundColor Cyan
    $bashPath = Join-Path $msysDir "usr\bin\bash.exe"
    & $bashPath --login -c "exit"

    # Descargas paralelas en pacman: la base no usa pacman, pero el modulo de compiladores si
    & $bashPath --login -c "sed -i -E 's/^#?[[:space:]]*ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf"

    # Configurar alias en el HOME portable
    $bashrcPath = Join-Path $homeDir ".bashrc"
    if (-not (Test-Path $bashrcPath)) {
        & $bashPath -env "HOME=$homeDir" --login -c "exit"
    }

    if (Test-Path $bashrcPath) {
        $aliasesFile = Join-Path $homeDir ".bash_aliases"
        $customAliases = @(
            "# === Portable Dev Environment Aliases ===",
            "alias python='python3'",
            "alias pip='pip3'",
            "alias make='mingw32-make'",
            "alias ll='ls -alF --color=auto'",
            "export PS1='\[\e[32m\]\u@portable \[\e[33m\]\w\[\e[0m\]\n$ '"
        )
        [System.IO.File]::WriteAllText($aliasesFile, ($customAliases -join "`n") + "`n", $utf8NoBom)
        
        $sourceLine = "if [ -f ~/.bash_aliases ]; then source ~/.bash_aliases; fi"
        $content = [System.IO.File]::ReadAllText($bashrcPath, $utf8NoBom)
        
        $isModified = $false
        if (-not $content.Contains("source ~/.bash_aliases")) {
            $content += "`r`n$sourceLine"
            $isModified = $true
        }

        # Agregar banner institucional (UNRN Andina - Programacion 1)
        $startInstMarker = "# === START INSTITUTIONAL BANNER ==="
        $endInstMarker = "# === END INSTITUTIONAL BANNER ==="
        $instBanner = @(
            "",
            $startInstMarker,
            "clear",
            'echo -e "\e[35m"', # Violeta
            'echo "======================================================================"',
            'echo "  UNRN Andina - Programacion 1"',
            'echo "======================================================================"',
            'echo -e "\e[0m"',
            'command -v ayuda >/dev/null 2>&1 && ayuda',
            $endInstMarker
        ) -join "`r`n"
        
        if (-not $content.Contains($startInstMarker)) {
            $content += "`r`n$instBanner"
            $isModified = $true
        }
        
        if ($isModified) {
            [System.IO.File]::WriteAllText($bashrcPath, $content, $utf8NoBom)
            Write-Host "Configuracion de terminal personalizada guardada." -ForegroundColor Green
        }
    }
    Set-Content -Path (Join-Path $portableRoot ".msys_complete") -Value "Complete"
} else {
    Write-Host "[Actualizacion] Base de MSYS2 ya configurada." -ForegroundColor Green
}

# ==========================================
# 3. uv y Python (base: las herramientas de la catedra son Python)
# ==========================================
# uv se instala como binario standalone (no depende de pacman ni del modulo de
# compiladores) y administra el Python de la base. Todo queda dentro del entorno:
# uv.exe en bin\, el interprete en python\ y la cache en descargas\uv_cache, sin
# registrar nada en el sistema (Set-PortableUvEnvironment en lib\env.common.psm1).
Set-PortableUvEnvironment -PortableRoot $portableRoot
$uvExe = Join-Path $portableRoot "bin\uv.exe"
$uvVersionFile = Join-Path $portableRoot "bin\.uv_version"
$uvAssetName = "uv-x86_64-pc-windows-msvc.zip"

$uvDownloadUrl = $null
if ($isUpdateMode -or $Latest -or -not (Test-Path $uvExe)) {
    $uvDownloadUrl = Get-Pinned 'uv'
    if ($uvDownloadUrl) {
        Write-Host "uv fijado por el manifiesto de versiones." -ForegroundColor DarkGray
    } else {
        try {
            $uvRelease = Get-GitHubApiCached -Url "https://api.github.com/repos/astral-sh/uv/releases/latest"
            $uvAsset = $uvRelease.assets | Where-Object { $_.name -eq $uvAssetName } | Select-Object -First 1
            if ($uvAsset) {
                $uvDownloadUrl = $uvAsset.browser_download_url
                Write-Host "Ultima version detectada de uv: $($uvRelease.tag_name)" -ForegroundColor Green
            }
        } catch {
            Write-Warning "Fallo al consultar la API de GitHub para uv. Usando fallback fijo."
        }
        if (-not $uvDownloadUrl) {
            $uvDownloadUrl = Get-Pinned 'uv_fallback'
        }
    }
}

$installedUvUrl = ""
if (Test-Path $uvVersionFile) { $installedUvUrl = (Get-Content $uvVersionFile -Raw).Trim() }

if ((Test-Path $uvExe) -and (-not $uvDownloadUrl -or $uvDownloadUrl -eq $installedUvUrl)) {
    Write-Host "uv ya esta instalado en bin\uv.exe." -ForegroundColor Green
} elseif (-not $uvDownloadUrl) {
    throw "No se pudo resolver la URL de descarga de uv (sin API de GitHub ni 'uv_fallback' en versions.json)."
} else {
    Write-Host "Descargando uv desde $uvDownloadUrl..." -ForegroundColor Cyan
    $uvZipPath = Join-Path $descargasDir $uvAssetName
    $uvExtractDir = Join-Path $descargasDir "uv_extract"
    try {
        Invoke-DownloadWithRetry -Url $uvDownloadUrl -OutFile $uvZipPath
        # Astral publica la suma de cada artefacto junto al archivo (<archivo>.sha256)
        $uvShaPath = "$uvZipPath.sha256"
        Invoke-DownloadWithRetry -Url "$uvDownloadUrl.sha256" -OutFile $uvShaPath
        $uvExpected = ((Get-Content $uvShaPath -Raw).Trim() -split '\s+')[0].ToLower()
        $uvActual = (Get-FileHash -Path $uvZipPath -Algorithm SHA256).Hash.ToLower()
        Remove-Item -Path $uvShaPath -Force -ErrorAction SilentlyContinue
        if ($uvExpected -notmatch '^[0-9a-f]{64}$' -or $uvActual -ne $uvExpected) {
            throw "La suma SHA-256 de $uvAssetName no coincide con la publicada (esperada: $uvExpected; descargada: $uvActual)."
        }
        if (Test-Path $uvExtractDir) { Remove-Item -Path $uvExtractDir -Recurse -Force }
        Expand-Archive -Path $uvZipPath -DestinationPath $uvExtractDir -Force
        $uvBinDir = Join-Path $portableRoot "bin"
        foreach ($uvBin in @("uv.exe", "uvx.exe", "uvw.exe")) {
            $uvSrc = Get-ChildItem -Path $uvExtractDir -Recurse -Filter $uvBin | Select-Object -First 1
            if ($uvSrc) { Copy-Item -Path $uvSrc.FullName -Destination (Join-Path $uvBinDir $uvBin) -Force }
        }
        if (-not (Test-Path $uvExe)) { throw "El ZIP de uv no contiene uv.exe." }
        Set-Content -Path $uvVersionFile -Value $uvDownloadUrl
        Write-Host "uv instalado en bin\uv.exe ($((& $uvExe --version) -join ' '))." -ForegroundColor Green
    } finally {
        if (Test-Path $uvExtractDir) { Remove-Item -Path $uvExtractDir -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $uvZipPath) { Remove-Item -Path $uvZipPath -Force -ErrorAction SilentlyContinue }
    }
}

# Python de la base: version menor fijada en versions.json ("python"), 3.12 por defecto.
$pythonVersion = Get-Pinned 'python'
if (-not $pythonVersion) { $pythonVersion = "3.12" }
$pythonRoot = Join-Path $portableRoot "python"
$pythonDir = Get-PortablePythonDir -PortableRoot $portableRoot
if ($isUpdateMode -or -not $pythonDir) {
    Write-Host "Instalando/verificando Python $pythonVersion con uv..." -ForegroundColor Cyan
    & $uvExe python install $pythonVersion
    if ($LASTEXITCODE -ne 0) {
        throw "uv no pudo instalar Python $pythonVersion (codigo $LASTEXITCODE)."
    }
    # Registrar la carpeta real del interprete (no la junction por version menor, que guarda
    # una ruta absoluta): el entorno sigue funcionando si se mueve de carpeta o de unidad.
    $pythonDir = $null
    $versionPattern = '^cpython-' + [regex]::Escape($pythonVersion) + '\.(\d+)'
    $bestPatch = -1
    foreach ($dir in @(Get-ChildItem -Path $pythonRoot -Directory -Filter "cpython-*" -ErrorAction SilentlyContinue)) {
        if ($dir.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { continue }
        if (-not (Test-Path (Join-Path $dir.FullName "python.exe"))) { continue }
        if ($dir.Name -match $versionPattern -and [int]$Matches[1] -gt $bestPatch) {
            $bestPatch = [int]$Matches[1]
            $pythonDir = $dir.FullName
        }
    }
    if (-not $pythonDir) {
        throw "uv termino sin errores pero no se encontro python.exe en $pythonRoot."
    }
    Set-Content -Path (Join-Path $pythonRoot "ACTUAL") -Value (Split-Path $pythonDir -Leaf)
}
Write-Host "Python de la base: $pythonDir" -ForegroundColor Green
$pythonExe = Join-Path $pythonDir "python.exe"

# 'python3' es el nombre que usan los scripts de bin\ (ripley, verificar, etc.)
$python3Exe = Join-Path $pythonDir "python3.exe"
if (-not (Test-Path $python3Exe)) { Copy-Item -Path $pythonExe -Destination $python3Exe -Force }

# Es el Python propio del entorno: pip debe poder instalar paquetes del alumno en el.
$externallyManaged = Join-Path $pythonDir "Lib\EXTERNALLY-MANAGED"
if (Test-Path $externallyManaged) { Remove-Item -Path $externallyManaged -Force }
if ((Invoke-NativeQuiet -FilePath $pythonExe -ArgumentList @("-m", "pip", "--version")) -ne 0) {
    Write-Host "Habilitando pip en el Python de la base..." -ForegroundColor Cyan
    & $pythonExe -m ensurepip --upgrade
    if ($LASTEXITCODE -ne 0) { Write-Warning "No se pudo habilitar pip (ensurepip). 'uv pip' sigue disponible." }
}

# Dependencias de las herramientas de la catedra (Ripley necesita typer y rich)
$requirementsBase = Join-Path $portableRoot "config\requirements-base.txt"
if (Test-Path $requirementsBase) {
    Write-Host "Instalando dependencias Python de la base (config\requirements-base.txt)..." -ForegroundColor Cyan
    & $uvExe pip install --python $pythonExe --break-system-packages -r $requirementsBase
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "No se pudieron instalar las dependencias Python de la base (codigo $LASTEXITCODE). Ripley no va a funcionar hasta reintentar setup.ps1."
    }
}

# ==========================================
# 3.5 Git (MinGit)
# ==========================================
# MinGit es la distribucion minima de Git for Windows pensada para uso en consola: un
# zip autocontenido, sin instalador ni pacman. Reemplaza al git de MSYS2 para que la base
# no tenga que sincronizar ni actualizar pacman. Va en mingit\ y su carpeta cmd\ entra
# al PATH de la sesion (lib\env.common.psm1). Como es un git nativo de Windows, uv
# ('uv tool install git+...') y VS Code lo usan directamente.
$mingitDir = Join-Path $portableRoot "mingit"
$mingitExe = Join-Path $mingitDir "cmd\git.exe"
$mingitVersionFile = Join-Path $mingitDir ".version"

$mingitUrl = $null
$mingitExpected = $null
if ($isUpdateMode -or $Latest -or -not (Test-Path $mingitExe)) {
    $mingitUrl = Get-Pinned 'mingit'
    if ($mingitUrl) {
        $mingitExpected = Get-Pinned 'mingit_sha256'
        Write-Host "MinGit fijado por el manifiesto de versiones." -ForegroundColor DarkGray
    } else {
        try {
            $gitRelease = Get-GitHubApiCached -Url "https://api.github.com/repos/git-for-windows/git/releases/latest"
            $gitAsset = $gitRelease.assets | Where-Object { $_.name -match '^MinGit-[0-9.]+-64-bit\.zip$' } | Select-Object -First 1
            if ($gitAsset) {
                $mingitUrl = $gitAsset.browser_download_url
                # La API de GitHub publica la suma de cada artefacto como "sha256:<hex>"
                if ($gitAsset.digest -and $gitAsset.digest -match '^sha256:([0-9a-fA-F]{64})$') {
                    $mingitExpected = $Matches[1]
                }
                Write-Host "Ultima version detectada de MinGit: $($gitAsset.name)" -ForegroundColor Green
            }
        } catch {
            Write-Warning "Fallo al consultar la API de GitHub para MinGit. Usando fallback fijo."
        }
        if (-not $mingitUrl) {
            $mingitUrl = Get-Pinned 'mingit_fallback'
            $mingitExpected = Get-Pinned 'mingit_sha256'
        }
    }
}

$installedMingitUrl = ""
if (Test-Path $mingitVersionFile) { $installedMingitUrl = (Get-Content $mingitVersionFile -Raw).Trim() }

if ((Test-Path $mingitExe) -and (-not $mingitUrl -or $mingitUrl -eq $installedMingitUrl)) {
    Write-Host "Git (MinGit) ya esta instalado en mingit\." -ForegroundColor Green
} elseif (-not $mingitUrl) {
    throw "No se pudo resolver la URL de descarga de MinGit (sin API de GitHub ni 'mingit_fallback' en versions.json)."
} else {
    $mingitZipName = Get-FileNameFromUrl -Url $mingitUrl -DefaultName "MinGit-64-bit.zip"
    $mingitZipPath = Join-Path $descargasDir $mingitZipName
    $mingitExtractDir = Join-Path $descargasDir "mingit_extract"
    try {
        Write-Host "Descargando MinGit desde $mingitUrl..." -ForegroundColor Cyan
        Invoke-DownloadWithRetry -Url $mingitUrl -OutFile $mingitZipPath
        $mingitActual = (Get-FileHash -Path $mingitZipPath -Algorithm SHA256).Hash.ToLower()
        if ($mingitExpected) {
            if ($mingitActual -ne $mingitExpected.Trim().ToLower()) {
                throw "La suma SHA-256 de $mingitZipName no coincide con la publicada (esperada: $($mingitExpected.Trim().ToLower()); descargada: $mingitActual)."
            }
            Write-Host "Suma SHA-256 de MinGit verificada." -ForegroundColor Green
        } else {
            Write-Warning "No hay suma SHA-256 publicada para $mingitZipName (defini 'mingit_sha256' en versions.json para verificarla)."
        }

        # Extraer aparte y reemplazar al final: un fallo no deja un git a medias
        if (Test-Path $mingitExtractDir) { Remove-Item -Path $mingitExtractDir -Recurse -Force }
        Expand-Archive -Path $mingitZipPath -DestinationPath $mingitExtractDir -Force
        if (-not (Test-Path (Join-Path $mingitExtractDir "cmd\git.exe"))) {
            throw "El ZIP de MinGit no contiene cmd\git.exe."
        }
        if (Test-Path $mingitDir) { Remove-Item -Path $mingitDir -Recurse -Force }
        Move-Item -Path $mingitExtractDir -Destination $mingitDir
        Set-Content -Path $mingitVersionFile -Value $mingitUrl

        # Configuracion de sistema (queda dentro de mingit\, nunca en el host):
        # - sin credential manager: guardaria tokens en el Administrador de credenciales de
        #   Windows del equipo (configure-git.sh usa el de gh, dentro del HOME portable);
        # - autocrlf=input, igual que el git de MSYS2 al que reemplaza.
        $null = Invoke-NativeQuiet -FilePath $mingitExe -ArgumentList @("config", "--system", "--unset-all", "credential.helper")
        $null = Invoke-NativeQuiet -FilePath $mingitExe -ArgumentList @("config", "--system", "core.autocrlf", "input")
        Write-Host "Git instalado en mingit\ ($((& $mingitExe --version) -join ' '))." -ForegroundColor Green
    } finally {
        if (Test-Path $mingitExtractDir) { Remove-Item -Path $mingitExtractDir -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $mingitZipPath) { Remove-Item -Path $mingitZipPath -Force -ErrorAction SilentlyContinue }
    }
}

# ==========================================
# 5.5. Gestion e Instalacion de GitHub CLI (gh)
# ==========================================
$ghExe = Join-Path $portableRoot "bin\gh.exe"
$isGhInstalled = Test-Path $ghExe
$isGhComplete = Test-Path (Join-Path $portableRoot ".gh_complete")

$ghDownloadUrl = ""
$shouldInstallOrUpdateGh = $false

if ($isUpdateMode -or -not $isGhComplete -or -not $isGhInstalled) {
    Write-Host "Obteniendo URL de descarga de GitHub CLI..." -ForegroundColor Cyan
    # Pin del manifiesto tiene prioridad; si no hay, se consulta la API
    $ghDownloadUrl = Get-Pinned 'gh'
    $ghFallbackUrl = if ($pinF = Get-Pinned 'gh_fallback') { $pinF } else { "https://github.com/cli/cli/releases/download/v2.49.0/gh_2.49.0_windows_amd64.zip" }
    if ($ghDownloadUrl) {
        Write-Host "GitHub CLI fijado por el manifiesto de versiones." -ForegroundColor DarkGray
    } else {
    try {
        $ghReleaseUrl = "https://api.github.com/repos/cli/cli/releases/latest"
        $ghRelease = Get-GitHubApiCached -Url $ghReleaseUrl
        $ghAsset = $ghRelease.assets | Where-Object { $_.name -like "*windows_amd64.zip" }
        if ($ghAsset) {
            $ghDownloadUrl = $ghAsset.browser_download_url
            Write-Host "Ultima version detectada de GitHub CLI: $($ghAsset.name)" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Fallo al consultar la API de GitHub para GitHub CLI. Usando fallback fijo."
    }

    if (-not $ghDownloadUrl) {
        $ghDownloadUrl = $ghFallbackUrl
        Write-Host "Fallback URL GitHub CLI: $ghDownloadUrl" -ForegroundColor Yellow
    }
    }
}

if (-not $isUpdateMode -and $isGhComplete -and $isGhInstalled) {
    Write-Host "GitHub CLI ya esta instalado y configurado de una ejecucion previa." -ForegroundColor Green
} else {
    if ($isUpdateMode) {
        $installedGhVersionFile = Join-Path $portableRoot "bin\.gh_version"
        $installedGhUrl = ""
        if (Test-Path $installedGhVersionFile) {
            $installedGhUrl = (Get-Content $installedGhVersionFile -Raw).Trim()
        }
        if ($ghDownloadUrl -ne $installedGhUrl) {
            # Si se uso la URL de fallback porque fallo la API y ya hay una version instalada,
            # asumimos que la instalada es valida para no sugerir un downgrade o alertar innecesariamente.
            $isFallback = ($ghDownloadUrl -eq $ghFallbackUrl)
            if ($isFallback -and $installedGhUrl) {
                Write-Host "Omitiendo comprobacion de actualizacion de GitHub CLI (la API de GitHub no esta disponible)." -ForegroundColor Green
            } else {
                Write-Host "Hay una nueva version de GitHub CLI disponible para actualizar (o no pudo verificarse la version local)." -ForegroundColor Yellow
                if ($Yes -or ((Read-Host "Deseas descargar e instalar la actualizacion de GitHub CLI? (s/n)") -match "^[sS]$")) {
                    $shouldInstallOrUpdateGh = $true
                    if ($Yes) { Write-Host "(--Yes) Actualizando GitHub CLI automaticamente..." -ForegroundColor DarkGray }
                } else {
                    Write-Host "Omitiendo actualizacion de GitHub CLI." -ForegroundColor DarkGray
                }
            }
        } else {
            Write-Host "GitHub CLI ya se encuentra en la version mas reciente ($ghDownloadUrl)." -ForegroundColor Green
        }
    } else {
        $shouldInstallOrUpdateGh = $true
    }

    if ($shouldInstallOrUpdateGh) {
        if (-not $isUpdateMode -and $isGhInstalled) {
            Write-Host "Se detecto una instalacion previa incompleta de GitHub CLI. Se continuara con la instalacion existente..." -ForegroundColor Yellow
        } else {
            # Resolver nombre de archivo de forma dinamica
            $ghZipName = Get-FileNameFromUrl -Url $ghDownloadUrl -DefaultName "gh_archive.zip"
            $ghZipPath = Join-Path $descargasDir $ghZipName

            $isGhZipValid = $false
            if (Test-Path $ghZipPath) {
                Write-Host "Se detecto un archivo ZIP de GitHub CLI descargado previamente ($ghZipName). Verificando..." -ForegroundColor Yellow
                try {
                    $fileSize = (Get-Item $ghZipPath).Length
                    if ($fileSize -gt 5MB) {
                        $sidecar = "$ghZipPath.sha256"
                        if (Test-Path $sidecar) {
                            $expectedHash = (Get-Content $sidecar -Raw).Trim()
                            $actualHash = (Get-FileHash -Path $ghZipPath -Algorithm SHA256).Hash
                            if ($actualHash -ne $expectedHash) {
                                Write-Host "El ZIP previo de GitHub CLI esta corrupto (SHA256 no coincide). Se volvera a descargar." -ForegroundColor Yellow
                            } else {
                                $isGhZipValid = $true
                                Write-Host "El ZIP previo de GitHub CLI es valido (SHA256 verificado)." -ForegroundColor Green
                            }
                        } else {
                            $isGhZipValid = $true
                            Write-Host "El archivo ZIP previo de GitHub CLI es valido (sin hash previo registrado)." -ForegroundColor Green
                        }
                    } else {
                        Write-Host "El archivo ZIP previo de GitHub CLI esta incompleto. Se volvera a descargar." -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "No se pudo verificar el archivo ZIP previo de GitHub CLI. Se volvera a descargar." -ForegroundColor Yellow
                }
            }

            if (-not $isGhZipValid) {
                Write-Host "Descargando GitHub CLI desde $ghDownloadUrl..." -ForegroundColor Cyan
                Invoke-DownloadWithRetry -Url $ghDownloadUrl -OutFile $ghZipPath
                (Get-FileHash -Path $ghZipPath -Algorithm SHA256).Hash | Set-Content -Path "$ghZipPath.sha256"
            }

            $ghTempDir = Join-Path $portableRoot "gh_temp"
            if (Test-Path $ghTempDir) {
                Remove-Item -Path $ghTempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            New-Item -ItemType Directory -Path $ghTempDir | Out-Null
            
            Write-Host "Extrayendo GitHub CLI..." -ForegroundColor Cyan
            Expand-Archive -Path $ghZipPath -DestinationPath $ghTempDir -Force
            
            $extractedGhExe = Get-ChildItem -Path $ghTempDir -Filter "gh.exe" -Recurse | Select-Object -First 1
            if ($extractedGhExe) {
                $binDir = Join-Path $portableRoot "bin"
                if (-not (Test-Path $binDir)) {
                    New-Item -ItemType Directory -Path $binDir | Out-Null
                }
                Move-Item -Path $extractedGhExe.FullName -Destination $ghExe -Force
                Write-Host "GitHub CLI copiado con exito a $ghExe." -ForegroundColor Green
            } else {
                Write-Error "No se pudo encontrar gh.exe en el paquete extraido."
            }

            Remove-Item -Path $ghTempDir -Recurse -Force -ErrorAction SilentlyContinue
            # No removemos el archivo zip para mantener la cache de descargas
        }

        Set-Content -Path (Join-Path $portableRoot "bin\.gh_version") -Value $ghDownloadUrl
        Set-Content -Path (Join-Path $portableRoot ".gh_complete") -Value "Complete"
        Write-Host "GitHub CLI instalado con exito." -ForegroundColor Green
    }
}

# ==========================================
# 5.6. Gestion e Instalacion de jonesy (IDE en terminal)
# ==========================================
$jonesyExe = Join-Path $portableRoot "bin\jonesy.exe"
$isJonesyInstalled = Test-Path $jonesyExe
$isJonesyComplete = Test-Path (Join-Path $portableRoot ".jonesy_complete")

$jonesyDownloadUrl = ""
$shouldInstallOrUpdateJonesy = $false

if ($isUpdateMode -or -not $isJonesyComplete -or -not $isJonesyInstalled) {
    Write-Host "Obteniendo URL de descarga de jonesy..." -ForegroundColor Cyan
    # Pin del manifiesto tiene prioridad; si no hay, se consulta la API
    $jonesyDownloadUrl = Get-Pinned 'jonesy'
    $jonesyFallbackUrl = if ($pinF = Get-Pinned 'jonesy_fallback') { $pinF } else { "https://github.com/INGCOM-UNRN-P1/jonesy/releases/download/v0.1.0/jonesy-0.1.0-windows-x86_64.zip" }
    if ($jonesyDownloadUrl) {
        Write-Host "jonesy fijado por el manifiesto de versiones." -ForegroundColor DarkGray
    } else {
        try {
            $jonesyReleaseUrl = "https://api.github.com/repos/INGCOM-UNRN-P1/jonesy/releases/latest"
            $jonesyRelease = Get-GitHubApiCached -Url $jonesyReleaseUrl
            $jonesyAsset = $jonesyRelease.assets | Where-Object { $_.name -like "*windows-x86_64.zip" }
            if ($jonesyAsset) {
                $jonesyDownloadUrl = $jonesyAsset.browser_download_url
                Write-Host "Ultima version detectada de jonesy: $($jonesyAsset.name)" -ForegroundColor Green
            }
        } catch {
            Write-Warning "Fallo al consultar la API de GitHub para jonesy. Usando fallback fijo."
        }

        if (-not $jonesyDownloadUrl) {
            $jonesyDownloadUrl = $jonesyFallbackUrl
            Write-Host "Fallback URL jonesy: $jonesyDownloadUrl" -ForegroundColor Yellow
        }
    }
}

if (-not $isUpdateMode -and $isJonesyComplete -and $isJonesyInstalled) {
    Write-Host "jonesy ya esta instalado y configurado de una ejecucion previa." -ForegroundColor Green
} else {
    if ($isUpdateMode) {
        $installedJonesyVersionFile = Join-Path $portableRoot "bin\.jonesy_version"
        $installedJonesyUrl = ""
        if (Test-Path $installedJonesyVersionFile) {
            $installedJonesyUrl = (Get-Content $installedJonesyVersionFile -Raw).Trim()
        }
        if ($jonesyDownloadUrl -ne $installedJonesyUrl) {
            $isFallback = ($jonesyDownloadUrl -eq $jonesyFallbackUrl)
            if ($isFallback -and $installedJonesyUrl) {
                Write-Host "Omitiendo comprobacion de actualizacion de jonesy (la API de GitHub no esta disponible)." -ForegroundColor Green
            } else {
                Write-Host "Hay una nueva version de jonesy disponible para actualizar (o no pudo verificarse la version local)." -ForegroundColor Yellow
                if ($Yes -or ((Read-Host "Deseas descargar e instalar la actualizacion de jonesy? (s/n)") -match "^[sS]$")) {
                    $shouldInstallOrUpdateJonesy = $true
                    if ($Yes) { Write-Host "(--Yes) Actualizando jonesy automaticamente..." -ForegroundColor DarkGray }
                } else {
                    Write-Host "Omitiendo actualizacion de jonesy." -ForegroundColor DarkGray
                }
            }
        } else {
            Write-Host "jonesy ya se encuentra en la version mas reciente ($jonesyDownloadUrl)." -ForegroundColor Green
        }
    } else {
        $shouldInstallOrUpdateJonesy = $true
    }

    if ($shouldInstallOrUpdateJonesy) {
        if (-not $isUpdateMode -and $isJonesyInstalled) {
            Write-Host "Se detecto una instalacion previa incompleta de jonesy. Se continuara con la instalacion existente..." -ForegroundColor Yellow
        } else {
            $jonesyZipName = Get-FileNameFromUrl -Url $jonesyDownloadUrl -DefaultName "jonesy_archive.zip"
            $jonesyZipPath = Join-Path $descargasDir $jonesyZipName

            $isJonesyZipValid = $false
            if (Test-Path $jonesyZipPath) {
                Write-Host "Se detecto un archivo ZIP de jonesy descargado previamente ($jonesyZipName). Verificando..." -ForegroundColor Yellow
                try {
                    $fileSize = (Get-Item $jonesyZipPath).Length
                    if ($fileSize -gt 1MB) {
                        $sidecar = "$jonesyZipPath.sha256"
                        if (Test-Path $sidecar) {
                            $expectedHash = (Get-Content $sidecar -Raw).Trim()
                            $actualHash = (Get-FileHash -Path $jonesyZipPath -Algorithm SHA256).Hash
                            if ($actualHash -ne $expectedHash) {
                                Write-Host "El ZIP previo de jonesy esta corrupto (SHA256 no coincide). Se volvera a descargar." -ForegroundColor Yellow
                            } else {
                                $isJonesyZipValid = $true
                                Write-Host "El ZIP previo de jonesy es valido (SHA256 verificado)." -ForegroundColor Green
                            }
                        } else {
                            $isJonesyZipValid = $true
                            Write-Host "El archivo ZIP previo de jonesy es valido (sin hash previo registrado)." -ForegroundColor Green
                        }
                    } else {
                        Write-Host "El archivo ZIP previo de jonesy esta incompleto. Se volvera a descargar." -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "No se pudo verificar el archivo ZIP previo de jonesy. Se volvera a descargar." -ForegroundColor Yellow
                }
            }

            if (-not $isJonesyZipValid) {
                Write-Host "Descargando jonesy desde $jonesyDownloadUrl..." -ForegroundColor Cyan
                Invoke-DownloadWithRetry -Url $jonesyDownloadUrl -OutFile $jonesyZipPath
                try {
                    Assert-ReleaseSha256 -Path $jonesyZipPath -Url $jonesyDownloadUrl -Expected (Get-Pinned 'jonesy_sha256')
                } catch {
                    Remove-Item -Path $jonesyZipPath, "$jonesyZipPath.sha256" -Force -ErrorAction SilentlyContinue
                    throw "Instalacion cancelada: $_"
                }
                Write-Host "Suma SHA-256 de jonesy verificada contra el release." -ForegroundColor Green
                (Get-FileHash -Path $jonesyZipPath -Algorithm SHA256).Hash | Set-Content -Path "$jonesyZipPath.sha256"
            }

            $jonesyTempDir = Join-Path $portableRoot "jonesy_temp"
            if (Test-Path $jonesyTempDir) {
                Remove-Item -Path $jonesyTempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            New-Item -ItemType Directory -Path $jonesyTempDir | Out-Null

            Write-Host "Extrayendo jonesy..." -ForegroundColor Cyan
            Expand-Archive -Path $jonesyZipPath -DestinationPath $jonesyTempDir -Force

            $extractedJonesyExe = Get-ChildItem -Path $jonesyTempDir -Filter "jonesy.exe" -Recurse | Select-Object -First 1
            if ($extractedJonesyExe) {
                $binDir = Join-Path $portableRoot "bin"
                if (-not (Test-Path $binDir)) {
                    New-Item -ItemType Directory -Path $binDir | Out-Null
                }
                Move-Item -Path $extractedJonesyExe.FullName -Destination $jonesyExe -Force
                Write-Host "jonesy copiado con exito a $jonesyExe." -ForegroundColor Green
            } else {
                Write-Error "No se pudo encontrar jonesy.exe en el paquete extraido."
            }

            Remove-Item -Path $jonesyTempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        Set-Content -Path (Join-Path $portableRoot "bin\.jonesy_version") -Value $jonesyDownloadUrl
        Set-Content -Path (Join-Path $portableRoot ".jonesy_complete") -Value "Complete"
        Write-Host "jonesy instalado con exito." -ForegroundColor Green
    }
}

# ==========================================
# 6. Gestion e Instalacion de WezTerm Portable
# ==========================================
$wezDir = Join-Path $portableRoot "wezterm"
$isWezInstalled = Test-Path (Join-Path $wezDir "wezterm.exe")
$isWezComplete = Test-Path (Join-Path $portableRoot ".wezterm_complete")

# Obtener URL de descarga de WezTerm (pin del manifiesto tiene prioridad)
$wezDownloadUrl = Get-Pinned 'wezterm'
$wezFallbackUrl = if ($pinF = Get-Pinned 'wezterm_fallback') { $pinF } else { "https://github.com/wez/wezterm/releases/download/20240203-110809-5046fc22/WezTerm-windows-20240203-110809-5046fc22.zip" }

if ($isUpdateMode -or -not $isWezComplete) {
    if ($wezDownloadUrl) {
        Write-Host "WezTerm fijado por el manifiesto de versiones." -ForegroundColor DarkGray
    } else {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $wezReleaseUrl = "https://api.github.com/repos/wez/wezterm/releases/latest"
        Write-Host "Consultando API de GitHub por la ultima version de WezTerm..."
        $wezRelease = Get-GitHubApiCached -Url $wezReleaseUrl
        $wezAsset = $wezRelease.assets | Where-Object { $_.name -like "WezTerm-windows-*.zip" -and $_.name -notlike "*setup*" }
        if ($wezAsset) {
            $wezDownloadUrl = $wezAsset.browser_download_url
            Write-Host "Ultima version detectada de WezTerm: $($wezAsset.name)" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Fallo al consultar la API de GitHub para WezTerm. Usando fallback fijo."
    }

    if (-not $wezDownloadUrl) {
        $wezDownloadUrl = $wezFallbackUrl
        Write-Host "Fallback URL WezTerm: $wezDownloadUrl" -ForegroundColor Yellow
    }
    }
}

if (-not $isUpdateMode -and $isWezComplete -and $isWezInstalled) {
    Write-Host "WezTerm ya esta instalado y configurado de una ejecucion previa." -ForegroundColor Green
} else {
    $shouldInstallOrUpdateWez = $false
    if ($isUpdateMode) {
        $installedWezVersionFile = Join-Path $wezDir ".version"
        $installedWezUrl = ""
        if (Test-Path $installedWezVersionFile) {
            $installedWezUrl = (Get-Content $installedWezVersionFile -Raw).Trim()
        }
        
        if ($wezDownloadUrl -ne $installedWezUrl) {
            # Si se uso la URL de fallback porque fallo la API y ya hay una version instalada,
            # asumimos que la instalada es valida para no sugerir un downgrade o alertar innecesariamente.
            $isFallback = ($wezDownloadUrl -eq $wezFallbackUrl)
            if ($isFallback -and $installedWezUrl) {
                Write-Host "Omitiendo comprobacion de actualizacion de WezTerm (la API de GitHub no esta disponible)." -ForegroundColor Green
            } else {
                Write-Host "Hay una nueva version de WezTerm disponible para actualizar (o no pudo verificarse la version local)." -ForegroundColor Yellow
                if ($Yes -or ((Read-Host "Deseas descargar e instalar la actualizacion de WezTerm? (s/n)") -match "^[sS]$")) {
                    $shouldInstallOrUpdateWez = $true
                    if ($Yes) { Write-Host "(--Yes) Actualizando WezTerm automaticamente..." -ForegroundColor DarkGray }
                } else {
                    Write-Host "Omitiendo actualizacion de WezTerm." -ForegroundColor DarkGray
                }
            }
        } else {
            Write-Host "WezTerm ya se encuentra en la version mas reciente ($wezDownloadUrl)." -ForegroundColor Green
        }
    } else {
        $shouldInstallOrUpdateWez = $true
    }

    if ($shouldInstallOrUpdateWez) {
        if (-not $isUpdateMode -and $isWezInstalled) {
            Write-Host "Se detecto una instalacion previa incompleta de WezTerm. Se continuara con la instalacion existente..." -ForegroundColor Yellow
        } else {
            # Resolver nombre de archivo de forma dinamica
            $wezZipName = Get-FileNameFromUrl -Url $wezDownloadUrl -DefaultName "wezterm_archive.zip"
            $wezZipPath = Join-Path $descargasDir $wezZipName

            $isWezZipValid = $false
            if (Test-Path $wezZipPath) {
                Write-Host "Se detecto un archivo ZIP de WezTerm descargado previamente ($wezZipName). Verificando..." -ForegroundColor Yellow
                try {
                    $fileSize = (Get-Item $wezZipPath).Length
                    if ($fileSize -gt 10MB) {
                        $sidecar = "$wezZipPath.sha256"
                        if (Test-Path $sidecar) {
                            $expectedHash = (Get-Content $sidecar -Raw).Trim()
                            $actualHash = (Get-FileHash -Path $wezZipPath -Algorithm SHA256).Hash
                            if ($actualHash -ne $expectedHash) {
                                Write-Host "El ZIP previo de WezTerm esta corrupto (SHA256 no coincide). Se volvera a descargar." -ForegroundColor Yellow
                            } else {
                                $isWezZipValid = $true
                                Write-Host "El ZIP previo de WezTerm es valido (SHA256 verificado)." -ForegroundColor Green
                            }
                        } else {
                            $isWezZipValid = $true
                            Write-Host "El archivo ZIP previo de WezTerm es valido (sin hash previo registrado)." -ForegroundColor Green
                        }
                    } else {
                        Write-Host "El archivo ZIP previo de WezTerm esta incompleto. Se volvera a descargar." -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "No se pudo verificar el archivo ZIP previo de WezTerm. Se volvera a descargar." -ForegroundColor Yellow
                }
            }

            if (-not $isWezZipValid) {
                Write-Host "Descargando WezTerm desde $wezDownloadUrl..." -ForegroundColor Cyan
                Invoke-DownloadWithRetry -Url $wezDownloadUrl -OutFile $wezZipPath
                (Get-FileHash -Path $wezZipPath -Algorithm SHA256).Hash | Set-Content -Path "$wezZipPath.sha256"
            }

            # Actualizacion atomica: extraer y aplanar en un directorio temporal,
            # validar wezterm.exe y recien entonces reemplazar la instalacion vigente.
            $wezExtractTemp = Join-Path $descargasDir "wezterm_extract"
            try {
                if (Test-Path $wezExtractTemp) {
                    Remove-Item -Path $wezExtractTemp -Recurse -Force -ErrorAction SilentlyContinue
                }
                New-Item -ItemType Directory -Path $wezExtractTemp | Out-Null

                Write-Host "Extrayendo WezTerm a directorio temporal..." -ForegroundColor Cyan
                Expand-Archive -Path $wezZipPath -DestinationPath $wezExtractTemp -Force

                # Si la descompresion creo un subdirectorio (ej: WezTerm-windows-...), aplanar dentro del temporal
                $subExe = Get-ChildItem -Path $wezExtractTemp -Filter "wezterm.exe" -Recurse | Select-Object -First 1
                if (-not $subExe) {
                    throw "El ZIP extraido no contiene wezterm.exe; se cancela el reemplazo de la instalacion vigente."
                }
                if ($subExe.DirectoryName -ne $wezExtractTemp) {
                    Write-Host "Aplanando estructura de carpetas de WezTerm..." -ForegroundColor Cyan
                    Get-ChildItem -Path $subExe.DirectoryName | Move-Item -Destination $wezExtractTemp -Force
                    Remove-Item -Path $subExe.DirectoryName -Recurse -Force
                }

                if (Test-Path $wezDir) {
                    Write-Host "Reemplazando instalacion anterior de WezTerm..." -ForegroundColor Cyan
                    Remove-Item -Path $wezDir -Recurse -Force -ErrorAction SilentlyContinue
                }
                Move-Item -Path $wezExtractTemp -Destination $wezDir
            } catch {
                Write-Warning "Fallo durante la actualizacion de WezTerm: $_"
                throw
            } finally {
                if (Test-Path $wezExtractTemp) {
                    Remove-Item -Path $wezExtractTemp -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        Set-Content -Path (Join-Path $wezDir ".version") -Value $wezDownloadUrl
        Set-Content -Path (Join-Path $portableRoot ".wezterm_complete") -Value "Complete"
        Write-Host "WezTerm Portable instalado con exito." -ForegroundColor Green
    }
}

# Escribir configuracion wezterm.lua a partir de la plantilla canonica unica
$wezConfigPath = Join-Path $portableRoot "wezterm.lua"
$wezTemplateFile = Join-Path $portableRoot "config\wezterm.lua.template"
if (-not (Test-Path $wezConfigPath) -or $isUpdateMode -or $shouldInstallOrUpdateWez) {
    if (-not (Test-Path $wezTemplateFile)) {
        throw "No se encontro config\wezterm.lua.template en el entorno."
    }
    $wezConfigContent = Get-Content $wezTemplateFile -Raw
    $wezConfigContent = $wezConfigContent.Replace('@HOME_DIR_NAME@', $HomeDirName)
    [System.IO.File]::WriteAllText($wezConfigPath, $wezConfigContent, $utf8NoBom)
    Write-Host "Configuracion wezterm.lua creada/actualizada desde la plantilla." -ForegroundColor Green
}

# ==========================================
# 6.5 Aprovisionamiento del motor Ripley (zipapp ripley.pyz)
# ==========================================
# Ripley es el verificador pedagogico de C que usan bin/verificar, bin/entregar,
# nuevo-proyecto y tp.sh. Se distribuye como zipapp autocontenido (ripley.pyz)
# adjunto a los Releases de GitHub: no requiere venv ni instalacion.
$ripleyPyzPath = Join-Path $portableRoot "bin\ripley.pyz"
$ripleyUrl = Get-Pinned 'ripley'
if (-not $ripleyUrl) {
    $ripleyUrl = "https://github.com/INGCOM-UNRN-P1/ripley/releases/latest/download/ripley.pyz"
}

function Test-ZipappValid([string]$Path) {
    # Un zipapp ejecutable arranca con shebang y le sigue el archivo ZIP (cabecera PK)
    try {
        if ((Get-Item $Path).Length -lt 10KB) { return $false }
        $head = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($Path)[0..63])
        return ($head.StartsWith("#!/usr/bin/env python3") -and $head.Contains("PK"))
    } catch { return $false }
}

$needsRipleyDownload = $false
if (-not (Test-Path $ripleyPyzPath)) {
    $needsRipleyDownload = $true
    Write-Host "El motor Ripley no esta descargado todavia." -ForegroundColor Yellow
} elseif ($isUpdateMode -or $Latest) {
    # En modo actualizacion se refresca silenciosamente (el zipapp pesa ~2 MB: trae typer, rich y demas dependencias)
    $needsRipleyDownload = $true
} else {
    Write-Host "Motor Ripley ya aprovisionado en bin\ripley.pyz." -ForegroundColor Green
}

if ($needsRipleyDownload) {
    $ripleyTmpPath = "$ripleyPyzPath.tmp"
    $ripleyDownloaded = $false
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Host "Descargando Ripley desde $ripleyUrl..." -ForegroundColor Cyan
        Invoke-DownloadWithRetry -Url $ripleyUrl -OutFile $ripleyTmpPath
        if (-not (Test-ZipappValid $ripleyTmpPath)) {
            throw "El archivo descargado no parece un zipapp valido."
        }
        $ripleyDownloaded = $true
    } catch {
        # No bloquea la instalacion: verificar/entregar caen al corrector diff clasico sin Ripley.
        Write-Warning "No se pudo descargar ripley.pyz ($_). El corrector local funcionara en modo clasico."
        if (Test-Path $ripleyTmpPath) { Remove-Item $ripleyTmpPath -Force -ErrorAction SilentlyContinue }
    }
    # Una descarga que no es la publicada si cancela: no se instala un zipapp sin verificar.
    if ($ripleyDownloaded) {
        try {
            Assert-ReleaseSha256 -Path $ripleyTmpPath -Url $ripleyUrl -Expected (Get-Pinned 'ripley_sha256')
        } catch {
            Remove-Item $ripleyTmpPath -Force -ErrorAction SilentlyContinue
            throw "Instalacion cancelada: $_"
        }
        Write-Host "Suma SHA-256 de ripley.pyz verificada contra el release." -ForegroundColor Green
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ripleyPyzPath) | Out-Null
        Move-Item -Path $ripleyTmpPath -Destination $ripleyPyzPath -Force
        Write-Host "Motor Ripley aprovisionado con exito ($( '{0:N0}' -f ((Get-Item $ripleyPyzPath).Length / 1KB) ) KB)." -ForegroundColor Green
        Write-Host "Probalo con: ripley doctor" -ForegroundColor DarkGray
    }
}

# ==========================================
# 6.8 Modulos opcionales: compiladores y VS Code
# ==========================================
# La base ya esta completa. Los modulos son descargas grandes que no todos los contextos
# necesitan; cada uno es un script independiente (modulos\<nombre>.ps1) que tambien se
# puede ejecutar despues con instalar-<nombre>.bat.
$modulosInfo = [ordered]@{
    "compiladores" = @{ Marker = ".compiladores_complete"; Descripcion = "compilador de C y herramientas (gcc, gdb, make, cmake, cppcheck, clang-format)" }
    "vscode"       = @{ Marker = ".vscode_complete";       Descripcion = "VS Code portable con las extensiones de C y Python" }
}

# Migracion: antes de los modulos, .msys_complete significaba "MSYS2 con compiladores".
$compiladoresMarker = Join-Path $portableRoot ".compiladores_complete"
if (-not (Test-Path $compiladoresMarker) -and (Test-Path (Join-Path $msysDir "ucrt64\bin\gcc.exe"))) {
    Set-Content -Path $compiladoresMarker -Value "Complete"
}

$modulosAEjecutar = @()
if ($null -ne $modulosPedidos) {
    $modulosAEjecutar = @($modulosPedidos)
} else {
    $interactivo = Test-InteractiveConsole -Yes:$Yes
    foreach ($nombre in $modulosInfo.Keys) {
        $info = $modulosInfo[$nombre]
        if (Test-Path (Join-Path $portableRoot $info.Marker)) {
            # Ya instalado: se ejecuta para completar o actualizar
            $modulosAEjecutar += $nombre
        } elseif ($isUpdateMode) {
            Write-Host "Modulo '$nombre' no instalado ($($info.Descripcion)). Se instala con instalar-$nombre.bat." -ForegroundColor DarkGray
        } elseif (-not $interactivo) {
            # Desatendido (-Yes, CI): se respeta el comportamiento historico de instalar todo
            $modulosAEjecutar += $nombre
        } else {
            $respuesta = Read-Host "Instalar ahora el modulo '$nombre' - $($info.Descripcion)? (S/n)"
            if ($respuesta -notmatch '^[nN]') {
                $modulosAEjecutar += $nombre
            } else {
                Write-Host "Modulo '$nombre' omitido. Podes instalarlo cuando quieras con instalar-$nombre.bat." -ForegroundColor DarkGray
            }
        }
    }
}

foreach ($nombre in $modulosAEjecutar) {
    $moduloScript = Join-Path $portableRoot "modulos\$nombre.ps1"
    $moduloArgs = @{ DesdeSetup = $true }
    if ($nombre -eq "vscode") {
        $moduloArgs["Yes"] = [bool]$Yes
        $moduloArgs["Latest"] = [bool]$Latest
        $moduloArgs["Actualizar"] = [bool]$isUpdateMode
    }
    Write-Host "`n=== Modulo: $nombre ===" -ForegroundColor Cyan
    try {
        & $moduloScript @moduloArgs
    } catch {
        Write-Warning "El modulo '$nombre' fallo: $_"
        Write-Warning "La base quedo instalada. Reintenta el modulo con instalar-$nombre.bat."
        $script:modulosFallidos += $nombre
    }
}

# ==========================================
# 7. Importacion de configuracion del host (opcional)
# ==========================================
if ($ImportHostConfig) {
    Write-Host "Importando configuracion desde el host..." -ForegroundColor Cyan
    
    # 1. SSH Config
    $hostSshDir = Join-Path $env:USERPROFILE ".ssh"
    $portableSshDir = Join-Path $homeDir ".ssh"
    if (Test-Path $hostSshDir) {
        Write-Host "Copiando llaves SSH desde $hostSshDir..." -ForegroundColor Cyan
        if (-not (Test-Path $portableSshDir)) {
            New-Item -ItemType Directory -Path $portableSshDir | Out-Null
        }
        Copy-Item -Path (Join-Path $hostSshDir "*") -Destination $portableSshDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Configuracion de SSH copiada." -ForegroundColor Green
    } else {
        Write-Host "No se encontro la configuracion de SSH en el host." -ForegroundColor Yellow
    }

    # 2. Git Config
    $hostGitConfig = Join-Path $env:USERPROFILE ".gitconfig"
    $portableGitConfig = Join-Path $homeDir ".gitconfig"
    if (Test-Path $hostGitConfig) {
        Write-Host "Copiando .gitconfig desde $hostGitConfig..." -ForegroundColor Cyan
        Copy-Item -Path $hostGitConfig -Destination $portableGitConfig -Force
        Write-Host "Configuracion de Git copiada." -ForegroundColor Green
    } else {
        Write-Host "No se encontro el archivo .gitconfig en el host." -ForegroundColor Yellow
    }
    
    $hostGitCreds = Join-Path $env:USERPROFILE ".git-credentials"
    $portableGitCreds = Join-Path $homeDir ".git-credentials"
    if (Test-Path $hostGitCreds) {
        Write-Host "Copiando .git-credentials desde $hostGitCreds..." -ForegroundColor Cyan
        Copy-Item -Path $hostGitCreds -Destination $portableGitCreds -Force
        Write-Host "Credenciales de Git copiadas." -ForegroundColor Green
    }

    # 3. VS Code settings.json
    $hostVscodeSettings = Join-Path $env:APPDATA "Code\User\settings.json"
    $portableVscodeData = Join-Path $vscodeDir "data\user-data\User"
    $portableVscodeSettings = Join-Path $portableVscodeData "settings.json"
    
    if (Test-Path $hostVscodeSettings) {
        Write-Host "Importando y adaptando settings.json de VS Code..." -ForegroundColor Cyan
        if (-not (Test-Path $portableVscodeData)) {
            New-Item -ItemType Directory -Path $portableVscodeData | Out-Null
        }
        
        try {
            $hostSettingsContent = Get-Content $hostVscodeSettings -Raw
            $settingsObj = $hostSettingsContent | ConvertFrom-Json
            if (-not $settingsObj) {
                $settingsObj = @{}
            }
        } catch {
            Write-Warning "No se pudo leer o procesar el settings.json del host. Se va a usar una configuracion limpia."
            $settingsObj = @{}
        }
        
        # Forzar/Asegurar parametros de portabilidad e inhabilitar IA/Copilot
        $settingsObj | Add-Member -NotePropertyName "telemetry.telemetryLevel" -NotePropertyValue "off" -Force
        $settingsObj | Add-Member -NotePropertyName "update.mode" -NotePropertyValue "none" -Force
        $settingsObj | Add-Member -NotePropertyName "extensions.autoUpdate" -NotePropertyValue $false -Force
        $settingsObj | Add-Member -NotePropertyName "chat.disableAIFeatures" -NotePropertyValue $true -Force
        $settingsObj | Add-Member -NotePropertyName "github.copilot.enable" -NotePropertyValue @{ "*" = $false } -Force
        
        # Configurar el perfil de terminal Bash UCRT64
        $terminalProfiles = @{
            "UCRT64 Bash" = @{
                "path" = "bash.exe"
                "args" = @("--login", "-i")
            }
        }
        $settingsObj | Add-Member -NotePropertyName "terminal.integrated.profiles.windows" -NotePropertyValue $terminalProfiles -Force
        $settingsObj | Add-Member -NotePropertyName "terminal.integrated.defaultProfile.windows" -NotePropertyValue "UCRT64 Bash" -Force
        
        # Guardar configuracion fusionada
        $mergedSettingsJson = $settingsObj | ConvertTo-Json -Depth 10
        Set-Content -Path $portableVscodeSettings -Value $mergedSettingsJson
        Write-Host "Configuracion de VS Code importada y adaptada para portabilidad." -ForegroundColor Green
    } else {
        Write-Host "No se encontro la configuracion de VS Code en el host." -ForegroundColor Yellow
    }
} else {
    Write-Host "No se especifico -ImportHostConfig. Se deja de lado la configuracion del host para empezar con un entorno limpio." -ForegroundColor Yellow
}

# ==========================================
# 8. Limpieza final de temporales
# ==========================================
# Se mantiene la carpeta 'descargas' de forma permanente como cache local para acelerar futuras instalaciones.

    # Guardar el indicador final de instalacion completa exitosa
    Set-Content -Path (Join-Path $portableRoot ".install_complete") -Value "Complete"

    # Resumen de componentes para el usuario
    Write-Host "`n--- ESTADO DE COMPONENTES ---" -ForegroundColor Cyan
    $summaryComponents = @(
        @{ Name = "MSYS2 base (bash)";        Ok = (Test-Path (Join-Path $msysDir "usr\bin\bash.exe")) },
        @{ Name = "Git (MinGit)";             Ok = (Test-Path (Join-Path $portableRoot "mingit\cmd\git.exe")) },
        @{ Name = "uv";                       Ok = (Test-Path (Join-Path $portableRoot "bin\uv.exe")) },
        @{ Name = "Python";                   Ok = [bool](Get-PortablePythonDir -PortableRoot $portableRoot) },
        @{ Name = "WezTerm";                  Ok = (Test-Path (Join-Path $portableRoot "wezterm\wezterm.exe")) },
        @{ Name = "GitHub CLI";               Ok = (Test-Path (Join-Path $portableRoot "bin\gh.exe")) },
        @{ Name = "Jonesy (IDE Terminal)";    Ok = (Test-Path (Join-Path $portableRoot "bin\jonesy.exe")) }
    )
    foreach ($comp in $summaryComponents) {
        $state = if ($comp.Ok) { "[OK]   " } else { "[FALTA]" }
        $color = if ($comp.Ok) { "Green" } else { "Yellow" }
        Write-Host ("  {0} {1}" -f $state, $comp.Name) -ForegroundColor $color
    }
    Write-Host "  Modulos opcionales:" -ForegroundColor Cyan
    $summaryModules = @(
        @{ Name = "compiladores (gcc, gdb, make, cmake)"; Ok = (Test-Path (Join-Path $portableRoot ".compiladores_complete")); Bat = "instalar-compiladores.bat" },
        @{ Name = "vscode (VS Code portable)";            Ok = (Test-Path (Join-Path $portableRoot ".vscode_complete"));       Bat = "instalar-vscode.bat" }
    )
    foreach ($comp in $summaryModules) {
        if ($comp.Ok) {
            Write-Host ("  [OK]    {0}" -f $comp.Name) -ForegroundColor Green
        } else {
            Write-Host ("  [ -- ]  {0}: no instalado (se instala con {1})" -f $comp.Name, $comp.Bat) -ForegroundColor DarkGray
        }
    }

    Write-Host "`n=== ENTORNO PORTABLE CONFIGURADO Y LISTO ===" -ForegroundColor Green
    Write-Host "Ejecuta 'launch.bat' para iniciar la consola." -ForegroundColor Green
    if (Test-Path (Join-Path $portableRoot ".vscode_complete")) {
        Write-Host "Ejecuta 'launch-vscode.bat' para iniciar VS Code." -ForegroundColor Green
    }
    $script:instalacionOk = $true
}
finally {
    if ($transcriptStarted) {
        Write-Host "`n======================================================================"
        Write-Host "FIN DE LA INSTALACION: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Write-Host "======================================================================"
        try {
            Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
        } catch {
            # Ignorar si no esta transcribiendo en este momento
        }
    }
    # Exito (o modulos con problemas): esperar antes de cerrar. Los errores los atiende el trap.
    if ($script:instalacionOk) {
        $avisoModulos = ""
        if ($script:modulosFallidos.Count -gt 0) {
            $avisoModulos = "Atencion: no se pudieron instalar los modulos: $($script:modulosFallidos -join ', '). Reintentalos con instalar-<modulo>.bat."
        }
        Wait-FinSetup -Mensaje $avisoModulos
    }
}
exit 0
