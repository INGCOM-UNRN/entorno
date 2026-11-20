# env.common.psm1 - Logica compartida por los lanzadores del entorno portable.
# Consumido por launch.ps1 y launch-vscode.ps1: advertencia de ruta conflictiva,
# resolucion del HOME portable desde .env e inyeccion de la sesion de trabajo
# (PATH del toolchain y variables de C/C++) en el proceso que lanza la GUI.
# Compatible con Windows PowerShell 5.1 y PowerShell 7 (pwsh).

function Test-ConflictivePath {
    <#
    .SYNOPSIS
    Detecta condiciones de ruta que rompen herramientas de compilacion.
    .OUTPUTS
    PSCustomObject con HasSpaces, HasNonAscii, HasSyncFolder e IsConflictive.
    #>
    param([string]$Path)

    $hasSpaces = $Path -match " "
    $hasNonAscii = $Path -match "[^\u0000-\u007F]"
    $hasSyncFolder = $Path -match "(?i)onedrive|dropbox|google\s+drive|icloud"

    return [pscustomobject]@{
        HasSpaces     = $hasSpaces
        HasNonAscii   = $hasNonAscii
        HasSyncFolder = $hasSyncFolder
        IsConflictive = ($hasSpaces -or $hasNonAscii -or $hasSyncFolder)
    }
}

function Show-PathWarning {
    <#
    .SYNOPSIS
    Imprime la advertencia detallada de ruta conflictiva en la consola.
    #>
    param([string]$Path)

    $info = Test-ConflictivePath -Path $Path
    Write-Host "==========================================================================" -ForegroundColor Yellow
    Write-Host "[ADVERTENCIA] La ruta de instalacion contiene caracteres conflictivos:" -ForegroundColor Yellow
    if ($info.HasSpaces) {
        Write-Host "* Espacios en blanco." -ForegroundColor Yellow
    }
    if ($info.HasNonAscii) {
        Write-Host "* Caracteres no ASCII (acentos, enes, etc.)." -ForegroundColor Yellow
    }
    if ($info.HasSyncFolder) {
        Write-Host "* Carpeta sincronizada (OneDrive/Dropbox/etc.), puede corromper compilaciones." -ForegroundColor Yellow
    }
    Write-Host "Ruta: '$Path'"
    Write-Host "Esto puede romper herramientas de compilacion de C (Make, CMake, etc.)."
    Write-Host "Se recomienda mover el entorno a una ruta simple (Ej: C:\dev\entorno)."
    Write-Host "==========================================================================" -ForegroundColor Yellow
    Write-Host ""
}

function Get-PortableHomeName {
    <#
    .SYNOPSIS
    Resuelve el nombre del directorio HOME portable desde .env (clave
    HOME_DIR_NAME, con o sin comillas y con o sin 'set'). Devuelve "home"
    ante ausencia de archivo o valor invalido.
    #>
    param([string]$PortableRoot)

    $homeDirName = "home"
    $envFile = Join-Path $PortableRoot ".env"
    if (Test-Path $envFile) {
        $envContent = Get-Content $envFile -Raw
        if ($envContent -match 'HOME_DIR_NAME=(.*)') {
            $candidate = $Matches[1].Replace('"', '').Trim()
            if ($candidate -match "^[a-zA-Z0-9_][a-zA-Z0-9_-]*$") {
                $homeDirName = $candidate
            }
        }
    }
    return $homeDirName
}

function Set-PortableUvEnvironment {
    <#
    .SYNOPSIS
    Confina uv dentro del entorno portable: cache, interpretes de Python y herramientas
    (uv tool install) quedan bajo la raiz, sin escribir en %LOCALAPPDATA%, en el perfil
    del usuario ni en el registro de Windows. Lo usan setup.ps1 y las sesiones.
    #>
    param([string]$PortableRoot)

    $env:UV_CACHE_DIR               = Join-Path $PortableRoot "descargas\uv_cache"
    $env:UV_PYTHON_INSTALL_DIR      = Join-Path $PortableRoot "python"
    $env:UV_PYTHON_BIN_DIR          = Join-Path $PortableRoot "python\bin"
    $env:UV_PYTHON_INSTALL_BIN      = "0"
    $env:UV_PYTHON_INSTALL_REGISTRY = "0"
    $env:UV_PYTHON_PREFERENCE       = "only-managed"
    $env:UV_TOOL_DIR                = Join-Path $PortableRoot "local\uv-tools"
    $env:UV_TOOL_BIN_DIR            = Join-Path $PortableRoot "local\bin"
    $env:UV_NO_MODIFY_PATH          = "1"
}

function Get-PortablePythonDir {
    <#
    .SYNOPSIS
    Devuelve la carpeta del Python de la base (la que contiene python.exe) o $null si
    no esta instalado. setup.ps1 registra el nombre en python\ACTUAL; si falta, se
    elige la instalacion mas nueva de python\cpython-*. Las carpetas enlace (junctions
    que uv crea por version menor) se ignoran: guardan rutas absolutas y dejan de
    funcionar si el entorno se mueve de carpeta o de unidad.
    #>
    param([string]$PortableRoot)

    $pythonRoot = Join-Path $PortableRoot "python"
    if (-not (Test-Path $pythonRoot)) { return $null }

    $pointer = Join-Path $pythonRoot "ACTUAL"
    if (Test-Path $pointer) {
        $name = (Get-Content $pointer -Raw).Trim()
        if ($name -match '^[A-Za-z0-9._+-]+$') {
            $candidate = Join-Path $pythonRoot $name
            if (Test-Path (Join-Path $candidate "python.exe")) { return $candidate }
        }
    }

    $best = $null
    $bestVersion = $null
    foreach ($dir in @(Get-ChildItem -Path $pythonRoot -Directory -Filter "cpython-*" -ErrorAction SilentlyContinue)) {
        if ($dir.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { continue }
        if (-not (Test-Path (Join-Path $dir.FullName "python.exe"))) { continue }
        if ($dir.Name -notmatch '^cpython-(\d+\.\d+\.\d+)') { continue }
        $version = [version]$Matches[1]
        if ($null -eq $bestVersion -or $version -gt $bestVersion) {
            $bestVersion = $version
            $best = $dir.FullName
        }
    }
    return $best
}

function Set-PortableSession {
    <#
    .SYNOPSIS
    Inyecta la sesion portable completa en el proceso actual: crea el HOME
    portable si falta, antepone los PATH del entorno y exporta las variables
    del toolchain de C/C++ hacia MSYS2 UCRT64. Devuelve la ruta del HOME.
    #>
    param(
        [string]$PortableRoot,
        [string]$HomeDirName = "home"
    )

    $homeDir = Join-Path $PortableRoot $HomeDirName
    if (-not (Test-Path $homeDir)) {
        New-Item -ItemType Directory -Path $homeDir | Out-Null
    }

    # Variables base de la sesion portable
    $env:PORTABLE_ROOT = $PortableRoot
    $env:HOME = $homeDir
    $env:MSYSTEM = "UCRT64"
    $env:CHERE_INVOKING = "1"
    $env:LANG = "es_AR.UTF-8"

    # Scripts internos, Python y Git de la base, compilador y userland de MSYS2 al frente del PATH.
    # El Python de la base (uv) va antes que ucrt64\bin: en instalaciones viejas el modulo de
    # compiladores traia otro python3 y la base debe ganar. Las consolas bash heredan este
    # PATH (MSYS2_PATH_TYPE=inherit) para que vean el mismo Python que VS Code.
    $binPath = Join-Path $PortableRoot "bin"
    $gccPath = Join-Path $PortableRoot "msys64\ucrt64\bin"
    $usrPath = Join-Path $PortableRoot "msys64\usr\bin"
    $pythonPaths = ""
    $pythonDir = Get-PortablePythonDir -PortableRoot $PortableRoot
    if ($pythonDir) {
        $pythonPaths = "$pythonDir;$(Join-Path $pythonDir 'Scripts');"
    }
    # Git de la base (MinGit): cmd\ trae solo git.exe y sus wrappers, sin pisar el userland
    $gitPaths = ""
    $mingitCmd = Join-Path $PortableRoot "mingit\cmd"
    if (Test-Path (Join-Path $mingitCmd "git.exe")) {
        $gitPaths = "$mingitCmd;"
    }
    $env:PATH = "$binPath;$pythonPaths$gitPaths$gccPath;$usrPath;$env:PATH"
    $env:MSYS2_PATH_TYPE = "inherit"
    Set-PortableUvEnvironment -PortableRoot $PortableRoot

    # Variables especificas del Toolchain de C/C++
    # (GCC en MSYS2 resuelve sus directorios internos relativos a su ubicacion;
    # no se definen GCC_EXEC_PREFIX ni LIBRARY_PATH manualmente)
    $env:CC  = "gcc"
    $env:CXX = "g++"
    $env:AR  = "ar"
    $env:AS  = "as"
    $env:LD  = "ld"
    $env:CPP = "cpp"
    $env:CFLAGS  = "-O2 -Wall"
    $env:LDFLAGS = ""
    $env:PKG_CONFIG_PATH   = "$(Join-Path $PortableRoot 'msys64\ucrt64\lib\pkgconfig');$(Join-Path $PortableRoot 'msys64\usr\lib\pkgconfig');$env:PKG_CONFIG_PATH"
    $env:CMAKE_PREFIX_PATH = "$(Join-Path $PortableRoot 'msys64\ucrt64');$(Join-Path $PortableRoot 'msys64\usr');$env:CMAKE_PREFIX_PATH"

    # Variables para integraciones (VS Code, WezTerm)
    $env:VSCODE_ROOT  = Join-Path $PortableRoot "vscode"
    $env:WEZTERM_ROOT = Join-Path $PortableRoot "wezterm"

    return $homeDir
}

function Set-VsCodeCompilerSettings {
    <#
    .SYNOPSIS
    Parcheo quirurgico del settings.json de VS Code: actualiza unicamente las
    claves C_Cpp.default.* (ruta del compilador e IntelliSense) preservando el
    resto del archivo tal cual (comentarios, orden y formato del usuario).
    Escribe solo si hubo cambios, en UTF-8 con BOM. Devuelve $true si escribio.
    #>
    param(
        [string]$PortableRoot,
        [string]$VscodeDir
    )

    $settingsUserDir = Join-Path $VscodeDir "data\user-data\User"
    $settingsJsonPath = Join-Path $settingsUserDir "settings.json"
    if (-not (Test-Path $settingsUserDir)) {
        New-Item -ItemType Directory -Path $settingsUserDir -Force | Out-Null
    }

    # Ruta de gcc con barras inclinadas hacia adelante
    $gccExeUrl = (Join-Path $PortableRoot "msys64\ucrt64\bin\gcc.exe").Replace("\", "/")

    $content = ""
    if (Test-Path $settingsJsonPath) {
        $content = Get-Content $settingsJsonPath -Raw
    }
    if ([string]::IsNullOrWhiteSpace($content)) { $content = "{}" }

    $originalContent = $content
    foreach ($entry in @(
        @{ Key = "C_Cpp.default.compilerPath"; Value = $gccExeUrl },
        @{ Key = "C_Cpp.default.intelliSenseMode"; Value = "windows-gcc-x64" }
    )) {
        $key = $entry.Key
        $valueJson = '"' + $entry.Value + '"'
        $pattern = '"' + [regex]::Escape($key) + '"\s*:\s*"[^"]*"'
        if ($content -match $pattern) {
            $content = [regex]::Replace($content, $pattern, ('"' + $key + '": ' + $valueJson))
        } else {
            # La clave no existe: insertarla como primera entrada del objeto principal
            $trimmed = $content.TrimStart()
            if ($trimmed.StartsWith("{") -and -not [string]::IsNullOrWhiteSpace($trimmed.TrimStart("{").Trim())) {
                $rest = $trimmed.Substring(1)
                $content = "{`n    `"$key`": $valueJson,`n" + $rest
            } elseif ($trimmed.StartsWith("{")) {
                $content = "{ `"$key`": $valueJson }"
            } else {
                $content = "{ `"$key`": $valueJson }"
            }
        }
    }

    if ($content -ne $originalContent) {
        Write-Host "[INFO] Actualizando ruta del compilador en settings.json..." -ForegroundColor DarkGray
        $utf8WithBom = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($settingsJsonPath, $content, $utf8WithBom)
        return $true
    }
    return $false
}

Export-ModuleMember -Function Test-ConflictivePath, Show-PathWarning, Get-PortableHomeName, Set-PortableUvEnvironment, Get-PortablePythonDir, Set-PortableSession, Set-VsCodeCompilerSettings
