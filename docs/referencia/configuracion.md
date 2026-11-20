# Configuración

Archivos que controlan qué se instala y cómo se comporta el entorno de Windows.

## `config/versions.json`: versiones por cuatrimestre

Manifiesto que fija qué versión de cada componente se instala, para que toda la cátedra
tenga lo mismo durante el cuatrimestre. Un valor `null` significa "la última publicada";
`setup.ps1 -Latest` ignora el manifiesto entero.

| Clave | Qué fija |
|---|---|
| `canal` | Nombre del canal (informativo, por ejemplo `2026-c1`). |
| `imagen` | Tag del release cuyas imágenes precompiladas usa `setup.ps1` (`null` = el último release). |
| `msys2`, `msys2_fallback` | URL del instalador de MSYS2 y la que se usa si la API de GitHub no responde. |
| `uv`, `uv_fallback` | URL del zip de uv para Windows. |
| `python` | Versión menor del Python de la base (por ejemplo `3.12`). |
| `mingit`, `mingit_fallback`, `mingit_sha256` | URL del zip de MinGit y su suma esperada. |
| `gh`, `gh_fallback` | GitHub CLI. |
| `wezterm`, `wezterm_fallback` | WezTerm portable. |
| `jonesy`, `jonesy_fallback`, `jonesy_sha256` | jonesy (editor en terminal). |
| `ripley`, `ripley_sha256` | `ripley.pyz`. |
| `vscode` | URL del zip de VS Code (módulo `vscode`). |
| `extensiones` | Extensiones de VS Code: `id` → versión (o `null` para la última). |

Las claves `*_sha256` reemplazan a la suma publicada en el release; sirven para espejos
propios o para fijar una descarga exacta. Política sugerida: fijar las URLs al inicio de
cada cuatrimestre y revisar los fallbacks.

## `.env`: configuración local

Archivo de la carpeta del entorno, no versionado. `setup.ps1` mantiene `HOME_DIR_NAME` y
conserva el resto de las claves.

| Clave | Efecto |
|---|---|
| `HOME_DIR_NAME` | Carpeta que hace de HOME portable (la fija `setup.ps1 -HomeDirName`). |
| `CHANNEL` | Rama o tag desde el que `setup.ps1` y `update-env.sh` actualizan los scripts en instalaciones sin git (por defecto `main`). Sirve para congelar los scripts durante el cuatrimestre. |

## Listas de paquetes

| Archivo | Uso |
|---|---|
| `config/packages-compiladores.txt` | Paquetes de pacman del módulo `compiladores`. Lo leen `modulos/compiladores.ps1`, `update-packages.sh` y `download-baseline.sh`. Un paquete por línea, admite comentarios con `#`. |
| `config/requirements-base.txt` | Paquetes de Python que `setup.ps1` instala con uv en el Python de la base (los que necesita `ripley.pyz`). |

La base no usa pacman: git es MinGit y Python viene de uv.

## Otras plantillas

| Archivo | Uso |
|---|---|
| `config/wezterm.lua.template` | Configuración de WezTerm; `launch.ps1` genera `wezterm.lua` a partir de ella. |
| `config/gdb/gdbinit` | `.gdbinit` de la cátedra (comandos `explicar`, `dashboard` y `vars`); lo instala `doctor --fix`. |

## Versión del entorno

El archivo `VERSION` de la raíz tiene la versión (SemVer) que muestran `ayuda`, el diagnóstico
y el log de instalación. Los cambios se registran en [CHANGELOG.md](../../CHANGELOG.md).
