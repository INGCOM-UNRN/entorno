# Registro de Cambios

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/);
versionado SemVer. La versión del entorno vive en el archivo `VERSION`.

## [Sin publicar]

### Cambiado
* **Instalación de Windows en dos fases: base y módulos opcionales.** `setup.ps1` instala ahora solo la base (MSYS2 con git, uv, Python, GitHub CLI, jonesy, WezTerm y Ripley), que alcanza para usar el entorno en contextos que no compilan C y evita la descarga masiva inicial. El compilador y sus herramientas (`modulos/compiladores.ps1`, paquetes en `packages-compiladores.txt`) y VS Code (`modulos/vscode.ps1`) son módulos independientes: `setup.ps1` pregunta por cada uno al terminar la base, se eligen con `-Modulos compiladores|vscode|todos|ninguno` y se instalan en cualquier momento con `instalar-compiladores.bat`, `instalar-vscode.bat` o el comando `instalar` de la consola. Con `-Yes` y sin `-Modulos` se instala todo, como antes; una actualización actualiza solo los módulos ya instalados. `ayuda` y `doctor` avisan qué módulos faltan, y `doctor` ya no informa la falta de gcc como una falla cuando el módulo no está instalado.
* **uv y Python en la base, sin pacman.** uv se descarga como binario standalone (`bin/uv.exe`, verificado contra el `.sha256` publicado, pin `uv` / `uv_fallback` en `versions.json`) e instala el Python de la base en `python/` (versión menor en la clave `python`) con las dependencias de `requirements-base.txt` (typer y rich para Ripley). `env.common.psm1` agrega ese Python al PATH de la sesión, exporta `MSYS2_PATH_TYPE=inherit` y confina la cache, los intérpretes y las herramientas de uv dentro del entorno (sin `%LOCALAPPDATA%` ni registro de Windows). Python, pip, typer, rich y uv salen de las listas de pacman.
* **Git de la base: MinGit en lugar del git de MSYS2.** MinGit (la distribución mínima de Git for Windows, pensada para uso en consola) se descarga como zip en `mingit/`, verificado con el digest SHA-256 que publica la API de GitHub (pin `mingit` / `mingit_fallback` / `mingit_sha256` en `versions.json`), y su `cmd/` entra al PATH de la sesión. Así la base ya no usa pacman: ni `-Syu` ni elección de espejo, que pasan al módulo de compiladores. Se configura sin credential manager (no guarda tokens en el Administrador de credenciales del equipo) y con `core.autocrlf=input`, como el git de MSYS2.
* **Documentación reorganizada por audiencia.** El README queda como presentación breve con la instalación de una línea por plataforma; el resto pasa a `docs/` con un índice (`docs/README.md`): `instalacion/` (Windows con capturas, módulos, offline, actualización y desinstalación; macOS/Linux personal; Linux portable), `uso/` (primeros pasos, trabajos prácticos, compilación con GCC, librerías de C, personalización, computadoras compartidas), `referencia/` (arquitectura, configuración y scripts, ordenados por carpeta) y `desarrollo/` (plan, mejoras y propuestas, antes en la raíz). Se quitaron las repeticiones entre README, `entorno.md`, `windows.md` y `scripts.md`, y las imágenes en sintaxis MyST que GitHub no mostraba.
* **Raíz del repositorio simplificada:** en la raíz quedan solo los puntos de entrada (instaladores, lanzadores, `instalar-*.bat`, desinstaladores) y los archivos del proyecto. El módulo común de los lanzadores pasa a `lib/env.common.psm1`; `versions.json`, `packages-compiladores.txt`, `requirements-base.txt` y `wezterm.lua.template` a `config/`; las utilidades de mantenimiento (`clean-shared-host.ps1`, `customize-terminal.ps1`, `fix-antivirus.ps1`, `package-env.ps1`, `smoke.ps1`) a `herramientas/`; se quitan los atajos `setup-personal.sh` y `desinstalar-personal.sh` (siguen en `unix/`). En instalaciones sin git, `setup.ps1` borra las copias viejas de la raíz.
* `packages-baseline.txt` pasa a ser `packages-compiladores.txt`: la única lista de pacman, la del módulo de compiladores; `update-packages.sh` y `download-baseline.sh` la leen solo a ella.
* Las funciones compartidas del instalador (descargas con reintentos, caché de la API de GitHub, pines, pacman, SHA-256, espejos) pasan de `setup.ps1` a `lib/instalador.ps1`.
* `package-env.ps1` ya no exige VS Code: empaqueta la base y los módulos que estén instalados.
* Regla de codificación (AGENTS.md, regla 6): los scripts PowerShell (`.ps1`, `.psm1`, `.psd1`) pasan a ser ASCII básico sin BOM, en lugar de UTF-8 con BOM. Se quitó el BOM de `setup.ps1`, `install-offline.ps1` y `tests/test_install_offline.ps1`; `install.ps1` y la autoactualización de `setup.ps1` ya no agregan BOM al escribir scripts; nuevo paso de lint que rechaza BOM o caracteres no ASCII.

### Agregado
* **Imágenes precompiladas en los releases** (workflow `release-imagenes.yml`, al publicar un tag `v*` o a mano): `entorno-base-windows-x64.zip` (scripts + base instalada: MSYS2, MinGit, Python, uv, WezTerm, gh, jonesy, Ripley) y `entorno-compiladores-windows-x64.zip` (capa de `msys64` con el módulo de compiladores, incluida la base de datos de pacman), con `SHA256SUMS` y una prueba de humo que las extrae en otra carpeta y compila. `setup.ps1` usa la imagen base en las instalaciones nuevas (una descarga verificada en lugar de una por componente; `-SinImagen` para evitarlo, pin `imagen` en `versions.json`) y el módulo de compiladores usa la capa solo si la base vino de la imagen del mismo release (si no, pacman). Las imágenes también sirven para distribuir sin internet. No incluyen el llavero de pacman, para no publicar ni compartir su clave privada. Armado en `herramientas/construir-imagenes.ps1`.
* Instalador `install.sh` para macOS y Linux vía `curl | bash`: instala en `~/p1/entorno` con espacio de trabajo `~/p1/dev` y pregunta (por la terminal, no por stdin) entre modo **separado** (HOME aislado con `~/p1/entrar`, sin tocar la configuración del usuario) o **integrado** (bloque delimitado en `~/.bashrc` / `~/.zshrc`). Descarga por git o tarball, actualización idempotente conservando `local/` y proyectos, `uv` y `gh` locales en `~/p1/entorno/local/bin`, advertencias de rutas con espacios/no ASCII/carpetas sincronizadas.
* `desinstalar.sh`: quita la integración, `~/p1/entorno` y el atajo; conserva `~/p1/dev` salvo `--borrar-dev`.
* CI `Unix (Linux y macOS)`: matriz ubuntu-24.04 / macOS arm64 / macOS Intel con `/bin/bash` 3.2, suite `tests/test_instalador_unix.sh` (incluye descarga real de uv/gh) y `tests/test_personal_unix.sh`, que antes no corría en CI.

### Corregido
* El repositorio del entorno pasó de `INGCOM-UNRN-P1/entorno` a `INGCOM-UNRN/entorno`: se actualizan las URLs de instalación (`install.ps1`, `install.sh`, `desinstalar.sh`), la autoactualización (`setup.ps1`, `update-env.sh`), `build-launcher.sh`, las imágenes precompiladas y la documentación, sin depender de la redirección de GitHub. `ripley`, `jonesy`, `mother` y las plantillas siguen en `INGCOM-UNRN-P1`.
* El alias `pip` de la consola de Windows pasa a ser `python3 -m pip`: los `pip.exe` / `pip3.exe` que genera pip guardan la ruta absoluta de `python.exe` y dejaban de funcionar al mover el entorno de carpeta o de unidad (y en las imágenes precompiladas).
* **La ventana ya no desaparece al terminar.** `install.ps1` terminaba con `exit`, y como corre con `irm | iex` dentro de la consola del usuario, la cerraba al finalizar la instalación; además informaba cualquier falla de `setup.ps1` como error de descarga. Ahora no usa `exit` ni deja cambiada `$ErrorActionPreference` en la sesión. `setup.ps1` atiende cualquier error con un `trap` que lo muestra y espera una tecla, y también espera al terminar bien (avisando si algún módulo falló); solo pausa la ejecución externa y nunca con `-Yes` ni en CI. `desinstalar.ps1` y `clean-shared-host.ps1` esperan al terminar, `launch.bat` / `launch-vscode.bat` pausan si el lanzador falla, y WezTerm queda abierto si bash termina con error (`exit_behavior = "CloseOnCleanExit"`, también en los `wezterm.lua` ya generados).
* `setup.ps1` sobrescribía `.env` con solo `HOME_DIR_NAME` y borraba `CHANNEL`: un entorno fijado a un canal estable volvía a `main` en la ejecución siguiente. Ahora conserva las demás claves.
* La autoactualización de `setup.ps1` y `bin/update-env.sh` copiaba una lista fija de archivos que había quedado desactualizada (faltaban `verificar`, `clonar`, `soporte` y casi todo `linux/bin/`): una instalación sin git nunca recibía esas correcciones. Ahora copian el snapshot completo. Si el `setup.ps1` viejo deja afuera `lib/` o `modulos/`, el nuevo los descarga aunque se haya pedido `-SkipUpdate` (una sola vez por ejecución).
* Al relanzarse tras la autoactualización, `setup.ps1` perdía `-Yes` y `-Latest`: una instalación desatendida quedaba esperando respuestas.
* Lanzador `ripley` (`bin/ripley`, `linux/bin/ripley`): sin `ripley.pyz`, nunca llegaba al ripley nativo (instalado con `mother`, `uv tool` o `pip`) y fallaba con «No encontré el motor Ripley». Lo buscaba con `command -v ripley`, que devuelve el propio lanzador porque está primero en el PATH. Ahora recorre el PATH salteando el lanzador y sus copias (en Windows `bin/` y `linux/bin/` están los dos en el PATH, y saltear sólo el propio archivo los haría llamarse en bucle). Tres pruebas nuevas en `tests/test_linux_env.sh`.
* `e2e-windows` nunca terminaba: `install-offline.ps1` esperaba una tecla (`ReadKey`) en su pausa final y el job agotaba el límite de 2h30. Nuevo switch `-Yes` y detección de consola no interactiva (CI, entrada redirigida) que omite preguntas y pausa; límites de tiempo por paso; acciones migradas a Node 24 (`checkout@v7`, `upload-artifact@v7`); prueba de regresión `tests/test_install_offline.ps1` en cada push.
* `unix/setup-personal.sh`: `UV_INSTALL_DIR` se pasaba a `curl` y no al instalador de uv; la detección de zsh comparaba `$SHELL` contra un patrón literal y nunca coincidía.
* Lint: la sintaxis y shellcheck ahora cubren también los scripts sin extensión (`bin/*`, `linux/bin/*`, `unix/bin/*`), y se verifican permisos de ejecución y fin de línea LF (`.gitattributes` fuerza LF en esos scripts).
* Módulo común `env.common.psm1` para los lanzadores (`launch.ps1`, `launch-vscode.ps1`): advertencia de ruta conflictiva, resolución del HOME portable desde `.env` e inyección de la sesión/toolchain en una sola fuente, con suite propia en CI.
* `configure-git.sh`: las credenciales de respaldo para otros servidores ahora se eligen entre caché temporal en memoria (expira a la hora; recomendado en compartidas) o `store` persistente en texto plano.
* Cobertura de pruebas ampliada: 53 pruebas bash (backup/restaurar, uninstall-lib, doctor --fix, verificar avanzado, exclusiones de entregar, diagnose-env, integridad de fuentes únicas), parcheo quirúrgico de settings bajo prueba, manifiesto de versiones (`Get-Pinned`) y quoting del lanzador C verificado contra reglas MSVCRT en cada push.
* `diagnose-env.sh` disponible también en la variante Linux (prefijo portable, informe en la raíz).
* **Integración con el motor Ripley** (Fase 3): aprovisionamiento automático del zipapp `ripley.pyz` desde GitHub Releases en `setup.ps1` (sección 6.5, pin vía clave `ripley` en `versions.json`, descarga con reintentos y validación) y en `update-env.sh`; lanzador `bin/ripley` que resuelve el zipapp portable o una instalación nativa; dependencias `python-typer` / `python-rich` agregadas al baseline pacman.
* `nuevo-proyecto --tipo plano|tp|lib`: modalidades de proyecto (plano por defecto para retrocompatibilidad). El tipo `plano` genera un Makefile de cátedra con targets `debug`, `asan`, `test` (itera los casos con tolerancia a CRLF) y `ripley`; los tipos `tp`/`lib` clonan las plantillas oficiales (URLs sobreescribibles con `PLANTILLA_TP_URL` / `PLANTILLA_LIB_URL`) sin historial Git y con tarea de build de VS Code.
* `bin/verificar` como adaptador: delega en `ripley check .` cuando el proyecto declara `ripley.toml` o un paquete `.ripkg`; sin motor disponible avisa y continúa con el corrector clásico.
* `bin/entregar` pre-valida con `ripley check . --strict` antes de empacar en proyectos con manifiesto Ripley (aceptación explícita de observaciones).
* Suite Linux ampliada a 67 pruebas: adaptadores verificar/entregar con stub de ripley, objetivos nuevos del Makefile generado, multitipo de nuevo-proyecto contra plantillas locales herméticas.

### Cambiado
* Documentación migrada a rutas relativas: se eliminaron los 41 enlaces absolutos heredados (`file:///home/mrtin/dev/p1/...`) del README; los manuales ahora funcionan desde cualquier ubicación del clon.

## [1.1.0] - 2026-08-23

### Agregado
* Plantilla física única `wezterm.lua.template` consumida por setup y lanzadores (fin de la triplicación y de la migración por regex masiva).
* Verificación activa de SHA256 sobre descargas cacheadas (VS Code / gh / WezTerm).
* `update-packages.sh`: actualización unificada de pacman + baseline desde fuente única.
* `smoke.sh` (+ wrapper `smoke.ps1`): automatización de las pruebas de aceptación A/B/C/E-local/F-check.
* `install-offline.ps1`: instalador asistido del paquete offline (tar.exe rápido, validación, `-Ejecutar`).
* Depuración lista en `nuevo-proyecto`: `.vscode/` con F5+GDB por plataforma, `.clang-format` y `.editorconfig`; Makefile con símbolos `-g`.
* `backup` / `restaurar`: respaldo y recuperación del HOME portable y manifiestos de librerías.
* Recordatorio de higiene en la ayuda cuando existe sesión activa de GitHub (equipos compartidos) y tip al configurar Git.
* `doctor --fix`: autorreparación ligera que regenera skel del HOME portable, marcadores de estado y `settings.json` base cuando falten, sin reinstalar componentes ni sobrescribir archivos del usuario.
* Flujo GitHub Classroom: comando `clonar <url>` (copia el TP a `~/proyectos` con upstream listo) y publicación opcional commit+push al final de `entregar`.
* Corrector local: comando `verificar` ejecuta los casos `tests/caso_NN.in/.out` (o `make test`) con tolerancia a espacios finales; `entregar` lo corre antes de empacar y bloquea la entrega fallida salvo confirmación explícita. `nuevo-proyecto` incluye un caso de ejemplo.
* Comando `soporte`: informe único anonimizado (doctor + versiones + estado + cola de install.log) para adjuntar en consultas al docente.
* Caché local de respuestas de la API de GitHub en `setup.ps1` (`descargas/api_cache`, vencimiento 24 h): evita el agotamiento del límite de consultas por IP en aulas con NAT compartido y permite seguir instalando con la última copia si la API cae.
* Espejo regional de pacman: durante la inicialización se mide la latencia contra candidatos (con prioridad sudamericana) y el más rápido pasa a ser el primer servidor de las listas de repositorios.
* `uv` como motor predeterminado de entornos virtuales (fallback automático a `python -m venv`); `smoke.sh` informa qué motor usó.
* CI semanal y manual sobre `windows-latest` con la cadena completa: `setup.ps1 -Yes`, smoke, empaquetado `-Compact` y roundtrip de instalación del paquete en otra carpeta.

### Cambiado
* Fase 9 de plan.md reescrita: automatizada por smoke; residual manual explícito (D/G/H/E-GUI).
* Distribución formal habilitada: licencia MIT del proyecto y CHANGELOG.
* Reintentos de descarga de componentes y selección de espejo pacman consolidados en funciones únicas, con suite de pruebas de lógica ejecutable en CI (`tests/test_windows_logic.ps1`).
* `setup.ps1` informa su compatibilidad al ejecutarse bajo PowerShell 7 (pwsh) con la recomendación de usar Windows PowerShell 5.1.

## [1.0.0] - 2026-08-22

Primera versión etiquetada tras la consolidación de las dos variantes de la plataforma.

### Windows
* Instalador desatendido (`setup.ps1`) con canal de versiones reproducible (`versions.json`, flag `-Latest`), modo no interactivo (`-Yes`), actualizaciones atómicas de VS Code/WezTerm, preflight de espacio/rutas, reintentos de descarga y pacman paralelo.
* Terminal WezTerm + MSYS2 UCRT64, VS Code portable con parcheo quirúrgico de settings.json, GitHub CLI y plantilla canónica compartida en los tres generadores de configuración.
* Empaquetado offline con poda `-Compact`, extensiones `.vsix` offline (`-ConExtensiones`) y política explícita del prefijo `local/`.
* Herramientas en consola: gestión de librerías C con manifiesto (`install-lib.sh`/`uninstall-lib.sh`), scaffolding académico (`nuevo-proyecto`, `entregar`), diagnóstico (`doctor`, `diagnose-env.sh`, `bootstrap`), configuración guiada de Git/GitHub CLI.
* Seguridad: limpieza para hosts compartidos corregida, exclusiones granulares de Defender con detección de antivirus de terceros, paquete sin datos personales.

### Linux
* Variante nativa por activación de sesión (`source linux/activate.sh`) con HOME portable y cero modificaciones al host ni permisos de administrador.
* Bootstrap solo diagnóstico, paridad de scripts (`configure-git`, `customize-terminal`, install/uninstall-lib, doctor, nuevo-proyecto, entregar, update-env) y suite propia de pruebas en CI.

### Infraestructura
* CI con PSScriptAnalyzer, shellcheck, bash -n y pruebas de la variante Linux.
* Reglas de agente unificadas en AGENTS.md; VERSION visible; CHANGELOG (este archivo).

### Pendiente conocido
* Validación completa en host Windows de la tanda reciente de cambios de PowerShell.
