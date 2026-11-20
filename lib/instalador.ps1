# lib/instalador.ps1 - Funciones compartidas por el instalador base (setup.ps1) y los
# modulos opcionales (modulos/compiladores.ps1, modulos/vscode.ps1).
#
# Se carga con dot-sourcing (". lib\instalador.ps1") para que las funciones vean las
# variables del script que las usa: $descargasDir (cache de descargas) y
# $pinnedVersions (manifiesto versions.json, lo carga Read-VersionManifest).
# Compatible con Windows PowerShell 5.1 y PowerShell 7 (pwsh).

# Codificacion UTF-8 sin BOM para los archivos que generan los instaladores
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Manifiesto de versiones por cuatrimestre (versions.json): valores null = ultima disponible.
# Por defecto se respetan los pines para reproducibilidad; -Latest los ignora (devuelve $null).
function Read-VersionManifest {
    param(
        [string]$Path,
        [switch]$Latest
    )
    if ($Latest -or -not (Test-Path $Path)) { return $null }
    try {
        $manifest = Get-Content $Path -Raw | ConvertFrom-Json
        if ($manifest.canal) {
            Write-Host "Canal de versiones configurado: $($manifest.canal)" -ForegroundColor DarkGray
        }
        return $manifest
    } catch {
        Write-Warning "versions.json invalido ($_). Se usaran las ultimas versiones disponibles."
        return $null
    }
}

function Get-Pinned([string]$Key) {
    if ($null -eq $script:pinnedVersions) { return $null }
    $prop = $script:pinnedVersions.PSObject.Properties[$Key]
    if ($null -eq $prop) { return $null }
    if ($prop.Value -is [string] -and $prop.Value.Trim()) { return $prop.Value.Trim() }
    return $null
}

# Cache de respuestas de la API de GitHub: en aulas con NAT compartido el limite
# de 60 consultas por hora por IP se agota rapido. Guarda cada respuesta en
# descargas/api_cache con vencimiento (24 horas) y, si la API no responde o
# rechaza por limite de peticiones, reutiliza la ultima copia aunque este vencida.
function Get-GitHubApiCached {
    param([string]$Url)
    $cacheDir = Join-Path $descargasDir "api_cache"
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Url))
    } finally {
        $sha.Dispose()
    }
    $hash = [System.BitConverter]::ToString($hashBytes).Replace("-", "").Substring(0, 16).ToLower()
    $cacheFile = Join-Path $cacheDir "$hash.json"
    $stampFile = Join-Path $cacheDir "$hash.stamp"
    $ttlHours = 24

    $cachedJson = $null
    $cacheFresh = $false
    if (Test-Path $cacheFile) {
        $cachedJson = Get-Content $cacheFile -Raw
        if (Test-Path $stampFile) {
            try {
                $stampUtc = [datetimeoffset]::Parse((Get-Content $stampFile -Raw).Trim()).UtcDateTime
                if (((Get-Date).ToUniversalTime() - $stampUtc).TotalHours -lt $ttlHours) { $cacheFresh = $true }
            } catch { }
        }
        if ($cacheFresh) {
            Write-Host "Respuesta de la API de GitHub servida desde la cache local." -ForegroundColor DarkGray
            try { return ($cachedJson | ConvertFrom-Json) } catch { }
        }
    }

    try {
        $response = Invoke-RestMethod -Uri $Url -UseBasicParsing -TimeoutSec 10
        New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
        Set-Content -Path $cacheFile -Value ($response | ConvertTo-Json -Depth 20)
        Set-Content -Path $stampFile -Value (Get-Date).ToUniversalTime().ToString("o")
        return $response
    } catch {
        if (-not [string]::IsNullOrEmpty($cachedJson)) {
            Write-Warning "Consulta a la API de GitHub fallida; se usa la cache local (aunque vencida)."
            try { return ($cachedJson | ConvertFrom-Json) } catch { }
        }
        throw
    }
}

# Descarga uniforme con reintentos para archivos grandes (MSYS2, VS Code, gh, WezTerm).
# Un unico punto para ajustar cantidad de intentos y espera entre intentos.
function Invoke-DownloadWithRetry {
    param(
        [string]$Url,
        [string]$OutFile,
        [int]$MaxAttempts = 3,
        [int]$DelaySeconds = 2
    )
    $attempts = 0
    while ($true) {
        $attempts++
        try {
            Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
            return
        } catch {
            if ($attempts -ge $MaxAttempts) { throw }
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

# Integridad de los artefactos de la catedra (Ola 11): compara el archivo con la linea de su
# nombre en el SHA256SUMS publicado junto a la URL (el mismo release), o con -Expected si se da
# (versions.json: "<clave>_sha256"). Lanza una excepcion si no coincide o no se puede comprobar:
# quien llama cancela la instalacion en vez de ejecutar algo descargado sin verificar.
function Assert-ReleaseSha256 {
    param(
        [string]$Path,
        [string]$Url,
        [string]$Expected = ""
    )
    $name = $Url.Substring($Url.LastIndexOf('/') + 1)
    if (-not $Expected) {
        $sumsUrl = $Url.Substring(0, $Url.LastIndexOf('/')) + "/SHA256SUMS"
        $sumsPath = "$Path.SHA256SUMS"
        try {
            Invoke-DownloadWithRetry -Url $sumsUrl -OutFile $sumsPath
        } catch {
            throw "No se pudo descargar $sumsUrl para verificar $name."
        }
        foreach ($line in (Get-Content -Path $sumsPath)) {
            $parts = $line.Trim() -split '\s+', 2
            if ($parts.Count -eq 2 -and ($parts[1] -eq $name -or $parts[1] -eq "*$name")) {
                $Expected = $parts[0]
                break
            }
        }
        Remove-Item -Path $sumsPath -Force -ErrorAction SilentlyContinue
        if (-not $Expected) { throw "El SHA256SUMS del release no trae la suma de $name." }
    }
    $actual = (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $Expected.Trim().ToLower()) {
        throw "La suma SHA-256 de $name no coincide con la del release (esperada: $($Expected.Trim().ToLower()); descargada: $actual)."
    }
}

# Espejo regional de pacman: mide latencia contra candidatos (prioridad sudamericana
# para Red UNRN) y configura el mas rapido como primera opcion de cada mirrorlist.
# Devuelve el espejo elegido o $null si ninguno respondio (no toca archivos en ese caso).
function Select-PacmanMirrorByLatency {
    param(
        [string]$MsysDir,
        [int]$TimeoutSec = 4
    )
    $mirrorCandidates = @(
        "https://mirror.ufro.cl/msys2",
        "https://repo.msys2.org",
        "https://mirrors.utexas.edu/msys2",
        "https://mirrors.ocf.berkeley.edu/msys2"
    )
    try {
        Write-Host "Midiendo latencia de espejos de pacman..." -ForegroundColor Cyan
        $bestMirror = $null
        $bestMs = [double]::MaxValue
        foreach ($candidate in $mirrorCandidates) {
            try {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                Invoke-WebRequest -Uri "$candidate/distrib/" -Method Head -UseBasicParsing -TimeoutSec $TimeoutSec | Out-Null
                $stopwatch.Stop()
                Write-Host ("  {0} -> {1} ms" -f $candidate, $stopwatch.ElapsedMilliseconds) -ForegroundColor DarkGray
                if ($stopwatch.ElapsedMilliseconds -lt $bestMs) {
                    $bestMs = $stopwatch.ElapsedMilliseconds
                    $bestMirror = $candidate
                }
            } catch {
                Write-Host "  $candidate -> sin respuesta" -ForegroundColor DarkGray
            }
        }
        if (-not $bestMirror) {
            Write-Warning "Ningun espejo de pacman respondio; se conservan los servidores por defecto."
            return $null
        }
        Write-Host "Espejo pacman seleccionado: $bestMirror (${bestMs} ms)" -ForegroundColor Green
        $markerLine = "# Espejo seleccionado automaticamente por setup.ps1 (latencia)"
        $repoSubPaths = @{
            "mirrorlist.msys"    = "/msys/x86_64/"
            "mirrorlist.ucrt64"  = "/mingw/ucrt64/"
            "mirrorlist.mingw64" = "/mingw/mingw64/"
            "mirrorlist.clang64" = "/mingw/clang64/"
        }
        foreach ($mirrorListName in $repoSubPaths.Keys) {
            $mirrorListFile = Join-Path (Join-Path $MsysDir "etc\pacman.d") $mirrorListName
            if (-not (Test-Path $mirrorListFile)) { continue }
            $existingLines = @(Get-Content $mirrorListFile)
            $serverLine = "Server = $($bestMirror)$($repoSubPaths[$mirrorListName])"
            $kept = @($existingLines | Where-Object { $_ -ne $serverLine -and $_ -notmatch 'Espejo seleccionado automaticamente' })
            Set-Content -Path $mirrorListFile -Value (@($markerLine, $serverLine) + $kept)
        }
        return $bestMirror
    } catch {
        Write-Warning "Fallo la seleccion de espejo de pacman; se conservan los servidores por defecto."
        return $null
    }
}

# Funcion para extraer el nombre de archivo de una URL o usar un fallback
function Get-FileNameFromUrl {
    param(
        [string]$Url,
        [string]$DefaultName
    )
    if ([string]::IsNullOrEmpty($Url)) { return $DefaultName }
    $leaf = $Url.Split('/')[-1]
    if ($leaf -match "\?") {
        $leaf = $leaf.Split('?')[0]
    }
    if ($leaf -match "\.(zip|exe|tar|gz|sfx)$") {
        return $leaf
    }
    return $DefaultName
}

# Funcion para ejecutar comandos de pacman con reintentos
function Invoke-PacmanWithRetry {
    param(
        [string]$BashPath,
        [string]$Arguments,
        [int]$MaxAttempts = 3,
        [int]$DelaySeconds = 5
    )
    
    $attempts = 0
    $success = $false
    
    while (-not $success -and $attempts -lt $MaxAttempts) {
        $attempts++
        if ($attempts -gt 1) {
            Write-Host "Reintentando comando pacman (Intento $attempts de $MaxAttempts) en $DelaySeconds segundos..." -ForegroundColor Yellow
            Start-Sleep -Seconds $DelaySeconds
        }
        
        # Ejecutar pacman con los argumentos correspondientes
        & $BashPath --login -c "pacman $Arguments"
        
        if ($LASTEXITCODE -eq 0) {
            $success = $true
        } else {
            Write-Warning "El comando 'pacman $Arguments' fallo con codigo de salida: $LASTEXITCODE"
        }
    }
    
    if (-not $success) {
        throw "No se pudo completar la instalacion o actualizacion de paquetes con pacman tras $MaxAttempts intentos."
    }
}

# Iniciar log de instalacion
$logPath = Join-Path $portableRoot "install.log"

# Lista de paquetes de pacman desde un archivo de texto (un paquete por linea, admite
# comentarios con #). Fuente unica compartida con los scripts de bin/.
function Get-PackageList {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        throw "No se encontro la lista de paquetes '$Path'."
    }
    return @(Get-Content -Path $Path | ForEach-Object { ($_ -split '#')[0].Trim() } | Where-Object { $_ })
}

# Hay una persona para responder preguntas? Sin consola interactiva (CI, tareas programadas,
# entrada redirigida) Read-Host quedaria bloqueado indefinidamente.
function Test-InteractiveConsole {
    param([switch]$Yes)
    if ($Yes -or $env:CI) { return $false }
    try {
        if ([Console]::IsInputRedirected) { return $false }
    } catch { }
    return [Environment]::UserInteractive
}

# Espacio libre en la unidad que contiene $Path. Lanza una excepcion si no alcanza;
# si no se puede medir (unidades de red, rutas UNC), solo advierte.
function Assert-FreeSpace {
    param(
        [string]$Path,
        [double]$RequiredGB,
        [string]$Context = "la instalacion"
    )
    try {
        $driveName = ($Path.Substring(0, 2)).TrimEnd('\')
        $drive = Get-PSDrive -Name $driveName[0] -ErrorAction Stop
        if ($drive.Free -lt ($RequiredGB * 1GB)) {
            $freeGb = [math]::Round($drive.Free / 1GB, 2)
            throw "Espacio insuficiente en ${driveName}: hay ${freeGb} GB libres y $Context necesita al menos $RequiredGB GB."
        }
        Write-Host "[OK] Espacio en disco suficiente para $Context ($([math]::Round($drive.Free / 1GB, 1)) GB libres)." -ForegroundColor DarkGray
    } catch [System.Management.Automation.PSInvalidOperationException] {
        Write-Warning "No se pudo verificar el espacio en disco para '$Path'. Continuando..."
    } catch [System.Management.Automation.DriveNotFoundException] {
        Write-Warning "No se pudo verificar el espacio en disco para '$Path'. Continuando..."
    }
}

# Ejecuta un programa externo descartando su salida y devuelve el codigo de salida.
# En Windows PowerShell 5.1, redirigir el stderr de un programa nativo con
# $ErrorActionPreference = "Stop" convierte cualquier linea en un error que corta el script;
# aca la preferencia es local a la funcion.
function Invoke-NativeQuiet {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList = @()
    )
    $ErrorActionPreference = "Continue"
    try {
        & $FilePath @ArgumentList *> $null
        return $LASTEXITCODE
    } catch {
        return 1
    }
}

# Espera una tecla antes de terminar, para que la ventana no desaparezca con el resultado
# (con exito o, sobre todo, con un error) cuando el script se abrio con doble clic, con
# "Ejecutar con PowerShell" o desde un .bat. Sin consola interactiva (-Yes, CI, entrada
# redirigida) no espera: los laboratorios y el CI siguen siendo desatendidos.
function Wait-AntesDeCerrar {
    param(
        [switch]$ConError,
        [switch]$Yes,
        [string]$Mensaje = ""
    )
    if ($ConError) {
        Write-Host ""
        Write-Host "Termino con errores: revisa los mensajes de arriba." -ForegroundColor Red
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
