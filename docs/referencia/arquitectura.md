# Arquitectura del entorno

Cómo está armado el entorno portable de Windows y cómo se organiza el repositorio. Las
variantes de macOS/Linux reutilizan los mismos comandos de cátedra (`bin/`, `linux/bin/`,
`unix/`) sobre las herramientas del sistema.

![Arquitectura del Entorno Portable](../images/arquitectura_entorno.svg)

## Principios

* **Aislamiento:** nada se escribe en la carpeta de usuario ni en el registro de la máquina.
  El HOME portable (`home/`) guarda configuración, historial, llaves y credenciales; uv,
  Python, Git y las cachés viven dentro de la carpeta del entorno.
* **Sesión, no instalación:** los lanzadores arman el entorno (PATH y variables) solo para
  los procesos que abren; al cerrarlos, Windows queda como estaba.
* **Base liviana y módulos:** la base alcanza para la consola, Git y Python; lo pesado
  (compilador, VS Code) se instala aparte.
* **Reproducibilidad:** `config/versions.json` fija versiones por cuatrimestre y todo lo
  descargado se verifica con SHA-256.

## Componentes en Windows

| Componente | Carpeta | Fase | Origen |
|---|---|---|---|
| Userland Unix (bash, coreutils) | `msys64/usr/bin` | base | instalador de MSYS2 |
| Git | `mingit/` | base | MinGit (Git for Windows) |
| uv | `bin/uv.exe` | base | release de Astral |
| Python + dependencias de la cátedra | `python/` | base | `uv python install` + `config/requirements-base.txt` |
| GitHub CLI, jonesy | `bin/` | base | releases de GitHub |
| Ripley | `bin/ripley.pyz` | base | release de la cátedra |
| Terminal | `wezterm/` | base | WezTerm portable |
| Compilador, depurador, build, análisis | `msys64/ucrt64/bin` | módulo `compiladores` | pacman (`config/packages-compiladores.txt`) |
| Editor | `vscode/` (datos en `vscode/data/`) | módulo `vscode` | VS Code portable |

Cada fase deja un marcador en la raíz: `.install_complete` (base), `.msys_complete`,
`.gh_complete`, `.wezterm_complete`, `.compiladores_complete` y `.vscode_complete`.
`setup.ps1` los usa para retomar instalaciones incompletas y `doctor --fix` los regenera.

## La sesión

`launch.ps1` y `launch-vscode.ps1` cargan `lib/env.common.psm1`, que:

1. Resuelve el HOME portable (`HOME_DIR_NAME` en `.env`) y lo exporta como `HOME`.
2. Antepone al `PATH`, en este orden: `bin/`, el Python de la base (y su `Scripts/`),
   `mingit/cmd/`, `msys64/ucrt64/bin` y `msys64/usr/bin`.
3. Exporta `MSYS2_PATH_TYPE=inherit` para que bash herede ese PATH, y las variables del
   toolchain (`CC`, `CXX`, `CFLAGS`, `PKG_CONFIG_PATH`, `CMAKE_PREFIX_PATH`).
4. Confina uv al entorno (`UV_CACHE_DIR`, `UV_PYTHON_INSTALL_DIR`, `UV_TOOL_DIR`, sin
   registro de Windows).

Después `launch.ps1` genera `wezterm.lua` desde `config/wezterm.lua.template` y abre WezTerm
(o bash en la consola clásica si WezTerm falta); `launch-vscode.ps1` ajusta en
`settings.json` la ruta del compilador y abre VS Code.

## Instalación y actualización

* `install.ps1` (la línea de `irm ... | iex`) descarga `setup.ps1` y lo ejecuta.
* `setup.ps1` primero se actualiza: `git pull` si la carpeta es un repositorio, o descarga
  del snapshot del canal configurado (`CHANNEL` en `.env`). Después instala o actualiza la
  base y ejecuta los módulos elegidos (`modulos/compiladores.ps1`, `modulos/vscode.ps1`).
* `lib/instalador.ps1` reúne lo común a la base y los módulos: descargas con reintentos,
  caché de la API de GitHub (para el límite por IP de las aulas), pines de
  `versions.json`, pacman con reintentos, elección de espejo y verificación SHA-256.

Verificación de lo que se descarga:

| Artefacto | Contra qué se verifica |
|---|---|
| MSYS2 | `.sha256` publicado junto al instalador |
| uv | `.sha256` publicado por Astral |
| MinGit | digest SHA-256 de la API de GitHub, o `mingit_sha256` |
| `ripley.pyz`, jonesy y (en macOS/Linux) `mother.pyz` | `SHA256SUMS` del mismo release (o `*_sha256` en `versions.json`) |

Si una suma no coincide, la instalación de ese componente se cancela.

## Estructura del repositorio

| Ruta | Contenido |
|---|---|
| `setup.ps1`, `install.ps1` | Instalador de Windows y su bootstrap de una línea. |
| `install.sh`, `desinstalar.sh` | Instalador y desinstalador de macOS/Linux (`~/p1`). |
| `install-offline.ps1` | Instala el paquete offline en otra máquina. |
| `launch*.bat`, `launch*.ps1` | Lanzadores de la consola y de VS Code. |
| `instalar-compiladores.bat`, `instalar-vscode.bat` | Instalan los módulos opcionales. |
| `customize-terminal.bat`, `desinstalar.ps1` | Personalizar WezTerm y quitar el entorno. |
| `bin/` | Comandos del entorno en Windows (en el PATH). |
| `linux/` | Variante portable de Linux: `activate.sh`, `bootstrap.sh` y `bin/`. |
| `unix/` | Comandos y scripts de la instalación personal de macOS/Linux. |
| `modulos/` | Módulos opcionales de Windows. |
| `lib/` | Código PowerShell compartido (`instalador.ps1`, `env.common.psm1`). |
| `config/` | Manifiesto de versiones, listas de paquetes, plantilla de WezTerm, `gdbinit`. |
| `herramientas/` | Utilidades de mantenimiento: limpieza, antivirus, empaquetado, smoke. |
| `launcher/` | Fuente en C de los lanzadores `.exe` sin ventana. |
| `tests/` | Pruebas (bash, PowerShell y C) que corre el CI. |
| `docs/` | Esta documentación. |

Carpetas que genera la instalación (excluidas de git): `msys64/`, `mingit/`, `python/`,
`wezterm/`, `vscode/`, `home/`, `local/` (librerías propias) y `descargas/` (caché).
