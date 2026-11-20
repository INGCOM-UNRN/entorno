# modulos/vscode.ps1 - Modulo opcional del entorno portable: VS Code portable y extensiones.
#
# La base (setup.ps1) no lo necesita: el entorno funciona con la consola (WezTerm + bash) y
# jonesy. Este modulo agrega VS Code en modo portable (carpeta vscode\, con su 'data' propia)
# y las extensiones de C/C++ y Python fijadas en config\versions.json.
#
# Uso:
#   instalar-vscode.bat                         (doble clic, o desde la consola: instalar vscode)
#   powershell -File modulos\vscode.ps1 [-Actualizar] [-Yes] [-Latest]
#     -Actualizar  si ya esta instalado, busca una version nueva y reinstala las extensiones
#     -Yes         acepta las actualizaciones sin preguntar
#     -Latest      ignora los pines de versions.json
#     -DesdeSetup  uso interno: lo invoca setup.ps1 (comparte su log de instalacion)
param(
    [switch]$Actualizar,
    [switch]$Yes,
    [switch]$Latest,
    [switch]$DesdeSetup
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$portableRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $portableRoot "lib\instalador.ps1")

$descargasDir = Join-Path $portableRoot "descargas"
$vscodeDir = Join-Path $portableRoot "vscode"
$pinnedVersions = Read-VersionManifest -Path (Join-Path $portableRoot "config\versions.json") -Latest:$Latest
# "Modo actualizacion" del modulo: solo si se pidio y ya habia una instalacion completa
$isUpdateMode = $Actualizar -and (Test-Path (Join-Path $portableRoot ".vscode_complete"))

if (-not (Test-Path $descargasDir)) {
    New-Item -ItemType Directory -Path $descargasDir | Out-Null
}

$transcriptStarted = $false
if (-not $DesdeSetup) {
    try {
        Start-Transcript -Path (Join-Path $portableRoot "modulo-vscode.log") -Force -ErrorAction Stop | Out-Null
        $transcriptStarted = $true
    } catch {
        Write-Warning "No se pudo iniciar el log del modulo. Se continua sin registrar en archivo."
    }
    Write-Host "=== Modulo VS Code del entorno portable ===" -ForegroundColor Cyan
    Write-Host "Directorio del entorno: $portableRoot`n"
}

try {
if (-not $isUpdateMode -and -not (Test-Path (Join-Path $vscodeDir "Code.exe"))) {
    Assert-FreeSpace -Path $portableRoot -RequiredGB 1 -Context "el modulo de VS Code"
}

# ==========================================
# 4. Gestion e Instalacion de VS Code Portable
# ==========================================
$vscodeZipUrl = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-archive"
$isCodeInstalled = Test-Path (Join-Path $vscodeDir "Code.exe")
$isCodeComplete = Test-Path (Join-Path $portableRoot ".vscode_complete")

# Resolver la URL de redireccion final de VS Code
$resolvedVscodeUrl = $vscodeZipUrl
$vscodePinned = Get-Pinned 'vscode'
if ($vscodePinned) {
    $resolvedVscodeUrl = $vscodePinned
    Write-Host "VS Code fijado por el manifiesto de versiones." -ForegroundColor DarkGray
}
if ($isUpdateMode -or -not $isCodeComplete) {
    if (-not $vscodePinned) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $request = [System.Net.WebRequest]::Create($vscodeZipUrl)
        $request.Method = "HEAD"
        $request.AllowAutoRedirect = $false
        $request.Timeout = 10000
        $response = $request.GetResponse()
        $resolvedVscodeUrl = $response.Headers["Location"]
        $response.Close()
        if ([string]::IsNullOrEmpty($resolvedVscodeUrl)) {
            $resolvedVscodeUrl = $vscodeZipUrl
        }
    } catch {
        try {
            $request = [System.Net.WebRequest]::Create($vscodeZipUrl)
            $request.Method = "GET"
            $request.AllowAutoRedirect = $false
            $request.Timeout = 10000
            $response = $request.GetResponse()
            $resolvedVscodeUrl = $response.Headers["Location"]
            $response.Close()
            if ([string]::IsNullOrEmpty($resolvedVscodeUrl)) {
                $resolvedVscodeUrl = $vscodeZipUrl
            }
        } catch {
            Write-Warning "No se pudo resolver la URL final de redireccion de VS Code. Se usara la URL directa."
        }
    }
    } # fin if (-not $vscodePinned)
}

if (-not $isUpdateMode -and $isCodeComplete -and $isCodeInstalled) {
    Write-Host "VS Code ya se encuentra instalado y configurado de una ejecucion previa." -ForegroundColor Green
} else {
    $shouldInstallOrUpdateVscode = $false
    if ($isUpdateMode) {
        $installedVscodeVersionFile = Join-Path $vscodeDir ".version"
        $installedVscodeUrl = ""
        if (Test-Path $installedVscodeVersionFile) {
            $installedVscodeUrl = (Get-Content $installedVscodeVersionFile -Raw).Trim()
        }
        
        if ($resolvedVscodeUrl -ne $installedVscodeUrl) {
            Write-Host "Hay una nueva version de VS Code disponible para actualizar (o no pudo verificarse la version local)." -ForegroundColor Yellow
            if ($Yes -or ((Read-Host "Deseas descargar e instalar la actualizacion de VS Code? (s/n)") -match "^[sS]$")) {
                $shouldInstallOrUpdateVscode = $true
                if ($Yes) { Write-Host "(--Yes) Actualizando VS Code automaticamente..." -ForegroundColor DarkGray }
            } else {
                Write-Host "Omitiendo actualizacion de VS Code." -ForegroundColor DarkGray
            }
        } else {
            Write-Host "VS Code ya se encuentra en la version mas reciente ($resolvedVscodeUrl)." -ForegroundColor Green
        }
    } else {
        $shouldInstallOrUpdateVscode = $true
    }

    if ($shouldInstallOrUpdateVscode) {
        if (-not $isUpdateMode -and $isCodeInstalled) {
            Write-Host "Se detecto una instalacion previa incompleta de VS Code. Se intentara continuar con la configuracion..." -ForegroundColor Yellow
            $dataDir = Join-Path $vscodeDir "data"
            $userSettingsDir = Join-Path $dataDir "user-data\User"
            $settingsJsonPath = Join-Path $userSettingsDir "settings.json"
            if (-not (Test-Path $settingsJsonPath)) {
                if (-not (Test-Path $userSettingsDir)) {
                    New-Item -ItemType Directory -Path $userSettingsDir -Force | Out-Null
                }
                $defaultSettings = @{
                    "telemetry.telemetryLevel" = "off"
                    "update.mode" = "none"
                    "extensions.autoUpdate" = $false
                    "chat.disableAIFeatures" = $true
                    "github.copilot.enable" = @{
                        "*" = $false
                    }
                    "terminal.integrated.profiles.windows" = @{
                        "UCRT64 Bash" = @{
                            "path" = "bash.exe"
                            "args" = @("--login", "-i")
                        }
                    }
                    "terminal.integrated.defaultProfile.windows" = "UCRT64 Bash"
                } | ConvertTo-Json -Depth 10
                Set-Content -Path $settingsJsonPath -Value $defaultSettings
            }
        } else {
            # Resolver nombre de archivo de forma dinamica e identificar version
            $vscodeZipName = Get-FileNameFromUrl -Url $resolvedVscodeUrl -DefaultName "vscode_archive.zip"
            $vscodeZipPath = Join-Path $descargasDir $vscodeZipName

            $vscodeZipValid = $false
            if (Test-Path $vscodeZipPath) {
                Write-Host "Se detecto una descarga previa de VS Code ($vscodeZipName). Verificando..." -ForegroundColor Yellow
                try {
                    $fileSize = (Get-Item $vscodeZipPath).Length
                    if ($fileSize -gt 50MB) {
                        # Verificacion activa: si existe el hash registrado de una descarga previa, compararlo
                        $sidecar = "$vscodeZipPath.sha256"
                        if (Test-Path $sidecar) {
                            $expectedHash = (Get-Content $sidecar -Raw).Trim()
                            $actualHash = (Get-FileHash -Path $vscodeZipPath -Algorithm SHA256).Hash
                            if ($actualHash -ne $expectedHash) {
                                Write-Host "El ZIP previo de VS Code esta corrupto (SHA256 no coincide). Se volvera a descargar." -ForegroundColor Yellow
                            } else {
                                $vscodeZipValid = $true
                                Write-Host "El archivo ZIP previo es valido (SHA256 verificado)." -ForegroundColor Green
                            }
                        } else {
                            $vscodeZipValid = $true
                            Write-Host "El archivo ZIP previo es valido (sin hash previo registrado)." -ForegroundColor Green
                        }
                    } else {
                        Write-Host "El archivo ZIP previo esta incompleto o danado. Se volvera a descargar." -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "No se pudo verificar el archivo ZIP previo. Se volvera a descargar." -ForegroundColor Yellow
                }
            }
            
            if (-not $vscodeZipValid) {
                Write-Host "Descargando VS Code desde $resolvedVscodeUrl..." -ForegroundColor Cyan
                Invoke-DownloadWithRetry -Url $resolvedVscodeUrl -OutFile $vscodeZipPath
                (Get-FileHash -Path $vscodeZipPath -Algorithm SHA256).Hash | Set-Content -Path "$vscodeZipPath.sha256"
            }
            
            $backupDataDir = Join-Path $portableRoot "vscode_data_backup"
            $dataDir = Join-Path $vscodeDir "data"
            $extractTemp = Join-Path $descargasDir "vscode_extract"

            # Actualizacion atomica: se extrae y valida en un directorio temporal
            # antes de tocar la instalacion vigente; ante cualquier fallo se restaura el respaldo.
            try {
                if (Test-Path $extractTemp) {
                    Remove-Item -Path $extractTemp -Recurse -Force -ErrorAction SilentlyContinue
                }
                New-Item -ItemType Directory -Path $extractTemp | Out-Null

                Write-Host "Extrayendo VS Code a directorio temporal..." -ForegroundColor Cyan
                Expand-Archive -Path $vscodeZipPath -DestinationPath $extractTemp -Force
                if (-not (Test-Path (Join-Path $extractTemp "Code.exe"))) {
                    throw "El ZIP extraido no contiene Code.exe; se cancela el reemplazo de la instalacion vigente."
                }

                if ((Test-Path $dataDir)) {
                    Write-Host "Respaldando carpeta data de VS Code..." -ForegroundColor Cyan
                    if (Test-Path $backupDataDir) {
                        Remove-Item -Path $backupDataDir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Move-Item -Path $dataDir -Destination $backupDataDir -Force
                }

                if (Test-Path $vscodeDir) {
                    Write-Host "Reemplazando instalacion anterior de VS Code..." -ForegroundColor Cyan
                    Remove-Item -Path $vscodeDir -Recurse -Force -ErrorAction SilentlyContinue
                }
                Move-Item -Path $extractTemp -Destination $vscodeDir

                if (Test-Path $backupDataDir) {
                    Write-Host "Restaurando carpeta data..." -ForegroundColor Cyan
                    Move-Item -Path $backupDataDir -Destination $dataDir -Force
                } else {
                # Activar el Modo Portable creando la carpeta 'data'
                $userSettingsDir = Join-Path $dataDir "user-data\User"
                if (-not (Test-Path $userSettingsDir)) {
                    New-Item -ItemType Directory -Path $userSettingsDir | Out-Null
                }
                
                # Escribir configuracion inicial de settings.json para aislar telemetria y configurar bash
                $settingsJsonPath = Join-Path $userSettingsDir "settings.json"
                $defaultSettings = @{
                    "telemetry.telemetryLevel" = "off"
                    "update.mode" = "none"
                    "extensions.autoUpdate" = $false
                    "chat.disableAIFeatures" = $true
                    "github.copilot.enable" = @{
                        "*" = $false
                    }
                    "terminal.integrated.profiles.windows" = @{
                        "UCRT64 Bash" = @{
                            "path" = "bash.exe"
                            "args" = @("--login", "-i")
                        }
                    }
                    "terminal.integrated.defaultProfile.windows" = "UCRT64 Bash"
                } | ConvertTo-Json -Depth 10
                
                Set-Content -Path $settingsJsonPath -Value $defaultSettings
                }
            } catch {
                Write-Warning "Fallo durante la actualizacion de VS Code: $_"
                # Rollback: si el respaldo existe y la data no fue restaurada, reconstruir
                if ((Test-Path $backupDataDir) -and (-not (Test-Path $dataDir))) {
                    Write-Host "Restaurando respaldo de datos de VS Code tras el fallo..." -ForegroundColor Yellow
                    if (-not (Test-Path $vscodeDir)) {
                        New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
                    }
                    Move-Item -Path $backupDataDir -Destination $dataDir -Force
                }
                throw
            } finally {
                if (Test-Path $extractTemp) {
                    Remove-Item -Path $extractTemp -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        Set-Content -Path (Join-Path $vscodeDir ".version") -Value $resolvedVscodeUrl
        # El marcador .vscode_complete se escribe recien con las extensiones instaladas (abajo):
        # si alguna falla, el proximo intento retoma las pendientes en lugar de saltearlas.
        Write-Host "VS Code Portable configurado/actualizado con exito." -ForegroundColor Green
    }
}

# ==========================================
# 5. Instalacion de Extensiones de VS Code
# ==========================================
$codeCmd = Join-Path $vscodeDir "bin\code.cmd"
if (Test-Path $codeCmd) {
    if ($isUpdateMode -or -not $isCodeComplete) {
        Write-Host "Verificando e instalando extensiones de VS Code..." -ForegroundColor Cyan
        # Versiones pineadas en versions.json (campo "extensiones": id -> version o null)
        $extensions = @(
            "ms-vscode.cpptools",
            "ms-vscode.cpptools-extension-pack",
            "ms-vscode.cmake-tools",
            "ms-vscode.makefile-tools",
            "ms-python.python",
            "GitHub.vscode-pull-request-github",
            "bierner.github-markdown-preview"
        )
        if ($null -ne $pinnedVersions) {
            $extProp = $pinnedVersions.PSObject.Properties['extensiones']
            if ($extProp) {
                $pinnedExts = @($extProp.Value.PSObject.Properties | ForEach-Object {
                    if ($_.Value -is [string] -and $_.Value.Trim()) { "$($_.Name)@$($_.Value.Trim())" } else { $_.Name }
                })
                if ($pinnedExts.Count -gt 0) { $extensions = $pinnedExts }
            }
        }
        $extensionesFallidas = @()
        foreach ($ext in $extensions) {
            Write-Host "Instalando/verificando extension: $ext..."
            $process = Start-Process -FilePath $codeCmd -ArgumentList "--install-extension", $ext, "--force" -Wait -NoNewWindow -PassThru
            if ($process.ExitCode -eq 0) {
                Write-Host "Extension $ext instalada/verificada." -ForegroundColor Green
            } else {
                Write-Warning "No se pudo instalar/verificar la extension $ext."
                $extensionesFallidas += $ext
            }
        }
        if ($extensionesFallidas.Count -gt 0) {
            # Sin marcador: el proximo intento vuelve a instalar las extensiones
            throw "No se pudieron instalar las extensiones: $($extensionesFallidas -join ', '). Reintenta con instalar-vscode.bat."
        }
        Set-Content -Path (Join-Path $portableRoot ".vscode_complete") -Value "Complete"
    }
} elseif (-not (Test-Path (Join-Path $portableRoot ".vscode_complete"))) {
    throw "VS Code no quedo instalado (falta vscode\bin\code.cmd). Reintenta con instalar-vscode.bat."
}


if (Test-Path (Join-Path $portableRoot ".vscode_complete")) {
    Write-Host "Modulo VS Code listo. Abrilo con launch-vscode.bat." -ForegroundColor Green
}
} finally {
    if ($transcriptStarted) {
        try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch { }
    }
}
