# Referencia de scripts

Detalle técnico de cada script del entorno: propósito, parámetros y funcionamiento
interno. Para el uso cotidiano, ver las [guías de uso](../README.md#uso).

---

## 1. Raíz: instalación y lanzadores (Windows)

### `setup.ps1`
* **Propósito:** Instala, repara y actualiza la **base** del entorno y coordina los **módulos opcionales** (compiladores y VS Code).
* **Uso:** `powershell -File setup.ps1 [-ImportHostConfig] [-SkipUpdate] [-Yes] [-Latest] [-Modulos <lista>]`
* **Parámetros:**
  * `-ImportHostConfig`: Si se pasa este modificador, copia la clave SSH privada, la configuración global de Git (`.gitconfig`) y el archivo `settings.json` de la instalación de VS Code del host local hacia el directorio `home/` portable.
  * `-SkipUpdate`: Saltea la fase de autodescarga e instalación de scripts actualizados de GitHub. Útil cuando se ejecuta localmente durante tareas de depuración o de actualización fuera de línea.
  * `-Yes`: Modo desatendido: acepta automáticamente todas las preguntas (actualizaciones de componentes, advertencia de ruta conflictiva). Pensado para despliegues masivos en laboratorios.
  * `-Latest`: Ignora los pines de `config/versions.json` e instala las últimas versiones disponibles de cada componente. Por defecto el manifiesto manda (reproducibilidad por cuatrimestre); los fallbacks también viven en el manifiesto.
  * `-SinImagen`: No usa la imagen base precompilada del release; instala cada componente por separado (también implícito con `-Latest`).
  * `-Modulos <lista>`: Módulos opcionales a instalar después de la base: `compiladores`, `vscode`, `todos` o `ninguno` (se aceptan varios separados por coma). Sin el parámetro, una instalación nueva pregunta por cada módulo (con `-Yes` instala todos, como antes) y una actualización actualiza solo los módulos ya instalados.
* **Canal de scripts:** En instalaciones standalone, la variable `CHANNEL=<rama-o-tag>` dentro de `.env` define desde qué canal se descargan los scripts; en repos Git rige la rama local (`git pull`).
* **Funcionamiento Interno:**
  1. Valida si la ruta de instalación posee espacios o caracteres no ASCII.
  2. Descarga el snapshot ZIP más reciente del repositorio de GitHub (`INGCOM-UNRN/entorno`) y extrae los scripts en la raíz y carpetas de utilidad.
  3. **Imagen base:** en una instalación nueva, descarga `entorno-base-windows-x64.zip` del release (último o el tag `imagen` de `config/versions.json`), lo verifica contra su `SHA256SUMS` y mueve sus componentes al entorno; registra el tag en `.imagen`. Los pasos siguientes encuentran esos componentes instalados y solo completan lo que falte.
  4. **Base:** comprueba, descarga e inicializa MSYS2 (`msys64/`) sin usar pacman, y descarga MinGit (`mingit/`) como git de la base, verificado con el digest SHA-256 de la API de GitHub.
  5. **Base:** descarga `uv` como binario standalone (`bin/uv.exe`, verificado contra el `.sha256` publicado) e instala con él el Python de la base en `python/` (versión menor en `config/versions.json`, clave `python`) más las dependencias de `config/requirements-base.txt` (typer y rich para Ripley). Cache, intérpretes y herramientas de uv quedan dentro del entorno.
  6. **Base:** descarga GitHub CLI (`gh`), jonesy, WezTerm y el zipapp `ripley.pyz`.
  7. **Módulos:** ejecuta los módulos elegidos (ver `-Modulos`). Si un módulo falla, la base queda instalada y el módulo se reintenta con `instalar-<módulo>.bat`.
  8. En instalaciones sin git, borra de la raíz las copias viejas de archivos que se movieron (`env.common.psm1`, `versions.json`, utilidades que pasaron a `herramientas/`...).
  9. Genera los marcadores de verificación (`.install_complete` para la base, `.msys_complete`, `.gh_complete`, `.wezterm_complete`; los módulos agregan `.compiladores_complete` y `.vscode_complete`).
* **Funciones compartidas:** las descargas con reintentos, la caché de la API de GitHub, los pines de `config/versions.json`, pacman con reintentos y la verificación SHA-256 viven en `lib/instalador.ps1` (ver abajo), que cargan `setup.ps1` y los módulos.
* **Salidas:** Generación de archivos de estado y el archivo de log central `install.log`.

### Módulos opcionales: `modulos/compiladores.ps1` y `modulos/vscode.ps1`
* **Propósito:** Separar de la base las descargas grandes que no todos los contextos necesitan.
* **Uso:** `instalar-compiladores.bat` / `instalar-vscode.bat` (doble clic), `instalar compiladores|vscode` desde la consola del entorno, o `setup.ps1 -Modulos ...`.
* **`compiladores`:** si la base vino de una imagen (`.imagen`), la primera vez extrae la capa `entorno-compiladores-windows-x64.zip` del mismo release (`-SinImagen` lo evita); si no, elige el espejo de pacman más rápido (la primera vez), sincroniza y actualiza pacman (`-Syu` y `-Su`) e instala `config/packages-compiladores.txt` (toolchain GCC/GDB/make, cmake, ninja, cppcheck, clang-tools-extra, doxygen y librerías comunes); crea `make.exe` en `ucrt64/bin`. Es idempotente. Requiere la base instalada.
* **`vscode`:** descarga VS Code en modo portable (`vscode/data/`), configura `settings.json` (UCRT64 Bash como terminal, telemetría e IA desactivadas) e instala las extensiones de `config/versions.json`. Con `-Actualizar` busca una versión nueva (lo pasa `setup.ps1` en modo actualización); `-Yes` y `-Latest` como en `setup.ps1`.
* **Ejecutados por separado** dejan su propio log (`modulo-compiladores.log`, `modulo-vscode.log`); desde `setup.ps1` escriben en `install.log`.

### `launch.ps1` y `launch.bat`
* **Propósito:** Lanzador unificado de la terminal portable WezTerm con todo el toolchain inyectado.
* **Funcionamiento Interno:**
  1. El archivo `.bat` es un delegador que ejecuta `powershell -File launch.ps1 %*`.
  2. El script `.ps1` calcula de forma dinámica el directorio raíz portable (`PORTABLE_ROOT`) y carga la configuración personalizada de directorio local de usuario desde `.env` (por defecto `home/`).
  3. Prepara el entorno inicializando los archivos de perfil `.bashrc` y `.bash_profile` en el HOME portable si no existen.
  4. Inyecta y exporta las variables de entorno locales de sesión (`PORTABLE_ROOT`, `HOME`, `MSYSTEM = UCRT64`, `CHERE_INVOKING = 1`, `LANG = es_AR.UTF-8`).
  5. Prepende al `PATH` de sesión las carpetas de scripts locales, el Python de la base y el compilador (`bin;python\<cpython>;python\<cpython>\Scripts;mingit\cmd;msys64\ucrt64\bin;msys64\usr\bin`), exporta `MSYS2_PATH_TYPE=inherit` para que bash herede ese PATH y confina uv al entorno (`UV_CACHE_DIR`, `UV_PYTHON_INSTALL_DIR`, `UV_TOOL_DIR`...).
  6. Define variables específicas de compiladores de C/C++ (`CC=gcc`, `CXX=g++`, `PKG_CONFIG_PATH`, `CMAKE_PREFIX_PATH`).
  7. Sanea o genera el archivo `wezterm.lua` (desde `config/wezterm.lua.template`) para asegurar que WezTerm levante MSYS2 Bash de forma nativa apuntando a las rutas dinámicas.
  8. Lanza `wezterm-gui.exe` / `wezterm.exe`. Si WezTerm no está disponible, cae de vuelta de forma segura lanzando `bash.exe` en la consola clásica de Windows para evitar bloqueos del alumno.

### `launch-vscode.ps1` y `launch-vscode.bat`
* **Propósito:** Lanzador de VS Code con el toolchain e integraciones de terminal configuradas.
* **Funcionamiento Interno:**
  1. El archivo `.bat` delega al cargador `.ps1` para evitar problemas sintácticos en el host.
  2. El script `.ps1` carga el directorio HOME y las variables de sesión del compilador de C y Python a través del módulo común `lib/env.common.psm1` (idéntico a `launch.ps1`).
  3. Comprueba si `vscode/Code.exe` existe. En caso de no existir, muestra una ventana de error que indica instalar el módulo con `instalar-vscode.bat`.
  4. Ejecuta el proceso de VS Code pasándole los argumentos de la línea de comandos (ej: abrir una carpeta específica o archivo) sin la bandera `-NoNewWindow` para asegurar que el editor se abra de forma visible.

### `install-offline.ps1`
* **Propósito:** Instalar el paquete `portable-env-offline.zip` en una máquina destino.
* **Funcionamiento:** Extrae con `tar.exe` (fallback Expand-Archive) al destino indicado, valida que exista `launch.bat`, advierte rutas conflictivas y opcionalmente abre el terminal (`-Ejecutar`). No requiere internet ni permisos de administrador.

### `desinstalar.ps1`
* **Propósito:** Eliminar por completo los componentes generados del entorno (MSYS2, MinGit, Python, VS Code, WezTerm, HOME portable, `local/`, cachés y marcadores), conservando los scripts del repositorio y la carpeta `.git`.
* **Funcionamiento:** Muestra el detalle de lo que va a borrar, pide confirmación irreversible y procede. No requiere permisos de administrador.

---

## 2. Código compartido (`lib/`)

### `lib/instalador.ps1`
* **Propósito:** Funciones compartidas por `setup.ps1` y los módulos (se carga con dot-sourcing).
* **Funcionamiento:** `Read-VersionManifest` y `Get-Pinned` (pines de `config/versions.json`), `Get-GitHubApiCached` (respuestas de la API de GitHub cacheadas 24 h en `descargas/api_cache`, con la copia vencida como respaldo ante el límite por IP), `Invoke-DownloadWithRetry`, `Assert-ReleaseSha256` (contra el `SHA256SUMS` del release), `Select-PacmanMirrorByLatency`, `Invoke-PacmanWithRetry`, `Get-PackageList`, `Assert-FreeSpace`, `Test-InteractiveConsole` e `Invoke-NativeQuiet`. Cubierto por `tests/test_windows_logic.ps1`.

### `lib/env.common.psm1`
* **Propósito:** Módulo PowerShell compartido por ambos lanzadores (fuente única de la lógica común).
* **Funcionamiento:** Exporta `Test-ConflictivePath` (espacios, no-ASCII y carpetas sincronizadas), `Show-PathWarning`, `Get-PortableHomeName` (lectura validada de `HOME_DIR_NAME` en `.env`) `Set-PortableUvEnvironment` (cache, intérpretes y herramientas de uv dentro del entorno), `Get-PortablePythonDir` (carpeta del Python de la base, registrada en `python/ACTUAL`) y `Set-PortableSession` (creación del HOME portable, PATH con `bin/`, Python, `mingit/cmd`, UCRT64 y `usr/bin`, `MSYS2_PATH_TYPE=inherit`, variables del toolchain de C/C++, `VSCODE_ROOT`/`WEZTERM_ROOT`). Compatible con Windows PowerShell 5.1 y pwsh; cubierto por `tests/test_env_common.ps1`.

---

## 3. Herramientas de mantenimiento (`herramientas/`)

Se ejecutan desde PowerShell (`.\herramientas\<script>.ps1`); resuelven la raíz del entorno como su carpeta padre.

### `clean-shared-host.ps1`
* **Propósito:** Sanea credenciales, historiales y archivos temporales para seguridad en computadoras compartidas.
* **Funcionamiento Interno:**
  1. Cierra procesos abiertos del entorno (`Code.exe`, `wezterm.exe`, `bash.exe`).
  2. Borra las claves de registro del historial de ejecución de comandos de Windows (historial de Ejecutar, de PowerShell y CMD).
  3. Limpia las claves de host cargadas en el agente SSH de la computadora compartida.
  4. Borra credenciales de Git cacheadas temporalmente fuera de la carpeta portable en el sistema host.
  5. Restablece la configuración del terminal integrado del VS Code del host (si se hubieran alterado archivos globales).

### `customize-terminal.ps1` (y `customize-terminal.bat` en la raíz)
* **Propósito:** Script interactivo de PowerShell para personalizar WezTerm.
* **Funcionamiento Interno:**
  1. Pregunta de forma interactiva sobre la configuración estética de WezTerm.
  2. Carga los valores activos del archivo `wezterm.lua` si existe (tema, tamaño de letra, opacidad de fondo).
  3. Permite elegir esquemas de color premium predefinidos (Tokyo Night, Dracula, Gruvbox, Nord, One Half Dark).
  4. Permite elegir el tamaño de fuente (8-24) y opacidad (transparencia de la ventana).
  5. Permite habilitar o deshabilitar la barra superior de múltiples pestañas (tabs).
  6. Escribe y regenera el archivo `wezterm.lua` mediante reintentos automáticos para evitar conflictos de bloqueo de archivos.

### `fix-antivirus.ps1`
* **Propósito:** Evitar que Windows Defender bloquee la compilación (falsos positivos y errores `VirtualProtect failed with code 0x5af`).
* **Funcionamiento:** Agrega la carpeta del entorno a las exclusiones de Windows Defender. Requiere ejecutarse como administrador.

### `package-env.ps1`
* **Propósito:** Empaqueta el entorno portable en un archivo ZIP listo para distribución offline.
* **Parámetros:**
  * `-Compact`: Poda documentación y locales no esenciales de MSYS2 en la copia a empaquetar (reduce tamaño sensiblemente).
  * `-ConExtensiones`: Descarga los `.vsix` de las extensiones instaladas (pineadas a su versión) hacia `offline-extensions/` dentro del paquete y genera `instalar-extensiones-offline.ps1`, habilitando aulas sin internet.
  * `-IncluirLibs`: Conserva el prefijo `local/` de librerías propias; por defecto se excluye para que el paquete sea neutro entre estudiantes.
* **Funcionamiento Interno:**
  1. Excluye carpetas voluminosas no necesarias para la ejecución (logs, temporales, caché de pacman en `downloads/`).
  2. Exige solo la base instalada: incluye los módulos opcionales que estén instalados en la máquina.
  3. Copia el entorno bajo una carpeta raíz `entorno` y lo comprime en `portable-env-offline.zip`, en la raíz del entorno.

### `construir-imagenes.ps1`
* **Propósito:** Armar las imágenes precompiladas que publica el workflow `release-imagenes.yml`.
* **Uso:** sobre un entorno recién instalado desde un clon: `setup.ps1 -Yes -SkipUpdate -SinImagen -Modulos ninguno`, luego `construir-imagenes.ps1 -Etapa base -Salida <dir>`, `modulos\compiladores.ps1 -SinImagen` y `construir-imagenes.ps1 -Etapa compiladores -Salida <dir>`.
* **Funcionamiento:** la etapa `base` comprime con `tar.exe` los archivos versionados (sin `.github/` ni `tests/`) y los componentes de la base, y guarda un inventario de `msys64` (tamaño y fecha de cada archivo). La etapa `compiladores` compara el inventario con el estado posterior al módulo y comprime solo lo nuevo o cambiado. Excluye el HOME, temporales, la caché y el llavero de pacman, y la documentación de MSYS2.

### `smoke.ps1` y `bin/smoke.sh`
* **Propósito:** Automatizar las pruebas de aceptación sin GUI del [plan](../desarrollo/plan.md) (A, B, C, E-local, F-check).
* **Funcionamiento:** Compila/ejecuta C y corre cppcheck; verifica python/pip/uv con instalación aislada en venv dentro del HOME portable; configura y compila un proyecto CMake+Ninja; instala/desinstala una librería fixture vía manifiesto; chequea identidad de Git. Código de salida 0 solo si no hay fallos. `herramientas/smoke.ps1` lo lanza desde PowerShell con la sesión del entorno (lo usa el CI).

---

## 4. Comandos de la consola (`bin/`, en el PATH)

### `ayuda`
* **Propósito:** Comando de referencia rápida de herramientas Bash.
* **Funcionamiento:** Imprime un resumen de los comandos, compiladores y utilidades del PATH con formato y color en la consola de MSYS2, y avisa qué módulos opcionales faltan.

### `backup [destino.zip]`
* **Propósito:** Resguardar los datos del alumno ante pérdida o corrupción del pendrive.
* **Funcionamiento:** Empaqueta el HOME portable completo (excluyendo `.cache`, `__pycache__`, `*.pyc`) junto con `.env`, `VERSION` y los manifiestos de `local/portable-libs` en `entorno-backup-<fecha>.zip`. Por defecto el ZIP se crea FUERA de la carpeta del entorno; el script recuerda guardarlo en un segundo medio.

### `build-launcher.sh`
* **Propósito:** Compilar los lanzadores ejecutables de Windows a partir del código fuente.
* **Funcionamiento:** Descarga `launcher.c` y su `Makefile` si no existen y ejecuta `make` (o `mingw32-make` como fallback) o directamente GCC de UCRT64 para compilar los ejecutables `launch-vscode.exe` y `launch-wezterm.exe` en la raíz, removiendo antiguos ejecutables obsoletos. Los lanzadores re-quoten cada argumento según las reglas de línea de comandos de Windows (rutas con espacios, comillas o barras invertidas viajan como un único argumento) y esperan al proceso hijo con un tope de 10 minutos como guarda contra cuelgues.

### `clonar <url | owner/repo> [destino]`
* **Propósito:** Flujo GitHub Classroom: clonar el trabajo práctico listo para programar.
* **Funcionamiento:** Clona la URL indicada (acepta atajo `owner/repo` de GitHub) en `$HOME/proyectos/<repo>` dentro del HOME portable, fija el upstream para que `git push` funcione sin argumentos y advierte si falta sesión de GitHub CLI para repos privados. Rechaza clonar sobre una carpeta existente.

### `configure-git.sh`
* **Propósito:** Configurar identidad de Git e iniciar sesión en GitHub CLI.
* **Funcionamiento:** Registra `user.name` y `user.email` de forma global aislada en la carpeta `home/`. Configura el helper de credenciales Git (el de `gh`) de forma portable para que comparta el inicio de sesión de `gh` con VS Code y con la consola.

### `customize-bash.sh`
* **Propósito:** Personalizar el mensaje de bienvenida y colores en la consola.
* **Funcionamiento:** Permite al alumno seleccionar temas del banner de bienvenida (Minimalista, Motivacional, Comandos rápidos, Libre o Limpio) y modificar el color de visualización del texto escribiendo las marcas correspondientes en `home/.bashrc`. Exporta y lee la variable del bloque mediante `ENVIRON` en `awk` para evitar pérdidas de secuencias de escape ANSI.

### `diagnose-env.sh`
* **Propósito:** Genera reporte técnico del estado del entorno.
* **Funcionamiento:** Vuelca las versiones de gcc, make, ninja, python, git, pacman y la lista física de ejecutables locales a `diagnose.log`.

### `doctor [--fix]`
* **Propósito:** Verificación rápida de salud post-instalación y autorreparación ligera.
* **Funcionamiento:** Compila, enlaza y ejecuta un programa mínimo (en Windows, si el módulo de compiladores no está instalado lo avisa sin contarlo como falla); valida make/cmake/ninja, Python, identidad de Git, sesión de gh y presencia de los directorios del entorno en el PATH. Código de salida 0 solo si no hay fallos.
* **Modo `--fix`:** regenera únicamente lo que falta, sin reinstalar componentes: el skel del HOME portable (`.bashrc`/`.bash_profile` con la variante canónica de cada plataforma), el `.gdbinit` pedagógico del c-debug-companion (comandos `explicar`, `dashboard` y `vars` dentro de GDB, copiado desde `config/gdb/gdbinit`), los marcadores de estado (`.msys_complete`, `.compiladores_complete`, `.vscode_complete`, `.gh_complete`, `.wezterm_complete`, `.install_complete`, solo si el componente correspondiente existe en disco) y el `settings.json` base de VS Code. Nunca sobrescribe archivos del usuario; funciona incluso sin sesión activa resolviendo la raíz desde su propia ubicación.

### `download-baseline.sh`
* **Propósito:** Precargar caché de pacman para instalaciones offline.
* **Funcionamiento:** Ejecuta `pacman -Sw` para descargar localmente a `descargas/pacman_cache` los paquetes de `config/packages-compiladores.txt` (la base no usa pacman).

### `entregar [directorio]`
* **Propósito:** Empaquetar el trabajo práctico para entrega.
* **Funcionamiento:** Compila el proyecto vía Makefile (validación previa a la entrega), ejecuta el corrector local si existen pruebas (`verificar`) y, en proyectos con manifiesto de Ripley (`ripley.toml` / `.ripkg`), pre-valida con `ripley check . --strict` antes de empacar. Genera `ENTREGA_<proyecto>_<fecha>.zip` con solo fuentes, excluyendo binarios, `.o`, builds y `.git`, usando Python para máxima portabilidad. Si el TP vive en un repositorio Git con remoto, ofrece publicar los cambios con commit + push (confirmación explícita del alumno).

### `instalar <módulo>`
* **Propósito:** Instalar un módulo opcional desde la consola (`instalar compiladores`, `instalar vscode`).
* **Funcionamiento:** Abre `instalar-<módulo>.bat` en una ventana aparte, porque si pacman actualiza el núcleo de MSYS2 cierra las consolas abiertas. Solo para Windows; en Linux/macOS indica usar el gestor de paquetes del sistema.

### `install-lib.sh`
* **Propósito:** Compilar e instalar dependencias externas de C desde GitHub de forma portable.
* **Funcionamiento:** Clona el repositorio indicado en una carpeta temporal y detecta el motor de construcción o la especificación (especificación estructurada `library.spec`, receta personalizada `.portable-recipe.sh`, CMakeLists.txt o Makefile estándar). Compila de forma aislada y copia las cabeceras e instalables resultantes en el prefijo portable del entorno (`/ucrt64`).

### `nuevo-proyecto [--tipo plano|tp|lib] <nombre>`
* **Propósito:** Crear la estructura inicial de un proyecto de cátedra.
* **Funcionamiento:** Genera la carpeta con `main.c` (hola mundo parametrizado), `Makefile` de cátedra (`make` / `mingw32-make`) y `.gitignore`, validando el nombre y colisiones. Además deja la depuración lista: `.vscode/tasks.json` (compilación con Ctrl+Shift+B) y `.vscode/launch.json` (F5 compila y lanza con GDB, resolviendo el binario y el debugger según plataforma), más `.clang-format` (Shift+Alt+F) y `.editorconfig`.
* **Tipos de proyecto (`--tipo`):**
  * `plano` (predeterminado): proyecto monoprograma. El Makefile incluye los objetivos `debug` (símbolos sin optimizar), `asan` (AddressSanitizer + UBSan), `test` (corre los casos `tests/caso_NN.in/.out`) y `ripley` (auditoría con el motor de análisis).
  * `tp`: clona la plantilla oficial de Trabajo Práctico modular (`libs/`, `ejercicios/`, gestor `./tp.sh`) desde GitHub; la URL puede personalizarse con la variable `PLANTILLA_TP_URL`.
  * `lib`: clona la plantilla estándar de biblioteca estática (`include/`, `src/`, `tests/`, `manage.sh`); URL personalizable con `PLANTILLA_LIB_URL`.

### `restaurar [archivo.zip]`
* **Propósito:** Recuperar un respaldo de `backup`.
* **Funcionamiento:** Toma el ZIP indicado (o el más reciente disponible), pide confirmación, extrae `home/…` sobre el HOME portable actual, restaura `.env` si faltaba e informa qué librerías hay que reinstalar con `install-lib.sh` según los manifiestos recuperados.

### `ripley <comando> [argumentos]`
* **Propósito:** Motor pedagógico de análisis de código C (linters AST, reglas P1, AddressSanitizer, traducción de errores GCC).
* **Funcionamiento:** Lanzador que ejecuta el zipapp autocontenido `bin/ripley.pyz` aprovisionado por `setup.ps1` / `update-env.sh` desde los Releases de GitHub; si no existe, delega en una instalación nativa (`uv tool install`). Comandos típicos: `ripley doctor` (diagnóstico), `ripley check .` (verificación del proyecto) y `ripley explain log.txt`.

### `soporte`
* **Propósito:** Estandarizar la consulta al docente con un único archivo adjunto.
* **Funcionamiento:** Genera `soporte-<fecha>.txt` en la raíz del entorno con el diagnóstico de `doctor` (sin colores), versiones de herramientas, estado de marcadores y carpetas, espacio libre y las últimas 60 líneas de `install.log`. Anonimiza automáticamente rutas del entorno, nombre de usuario, equipo e identidad de Git (reemplazados por `<entorno>`, `<usuario>`, `<equipo>`, `<nombre-git>`).

### `uninstall-lib.sh`
* **Propósito:** Desinstalar librerías registradas por `install-lib.sh`.
* **Funcionamiento:** Lee los manifiestos en `<prefijo>/portable-libs/*.files`, elimina los archivos registrados, poda directorios vacíos y reporta las librerías instaladas vía CMake/make install que solo tienen notas parciales.

### `update-packages.sh`
* **Propósito:** Actualización unificada de paquetes del entorno (MSYS2).
* **Funcionamiento:** Sincroniza la base de pacman, actualiza el sistema y si el módulo de compiladores está instalado, garantiza los paquetes de `config/packages-compiladores.txt`, usando `descargas/pacman_cache` como caché portátil.

### `update-env.sh`
* **Propósito:** Actualizar el entorno desde la consola.
* **Funcionamiento:** Descarga el snapshot del canal configurado (`CHANNEL` en `.env`, por defecto `main`) y lo copia completo sobre el entorno, actualiza `ripley.pyz` (verificado contra el `SHA256SUMS` del release) y ofrece relanzar `setup.ps1 -SkipUpdate` para actualizar la base y los módulos instalados.

### `verificar [directorio]`
* **Propósito:** Corrector local: autoevaluación con las pruebas de cátedra antes de la entrega.
* **Funcionamiento:** Si el proyecto declara un manifiesto de Ripley (`ripley.toml` o un paquete `.ripkg`), delega en `ripley check .` (análisis estático, AddressSanitizer y diagnóstico pedagógico); sin Ripley disponible, avisa y continúa en modo clásico. En modo clásico compila el proyecto y compara la salida del binario contra los casos `tests/caso_NN.in` / `.out` (tolerando diferencias de espacios finales); si el Makefile define un objetivo `test:` tiene prioridad. Reporta cada caso con su salida esperada vs. obtenida y devuelve código de salida distinto de cero si algo falla. `nuevo-proyecto` deja un caso funcionando como ejemplo de la convención.

---

## 5. Variante Linux (`linux/`)

Entorno por activación de sesión, sin modificaciones al host ni permisos de administrador.

### `linux/activate.sh`
* **Propósito:** Activar el entorno en la sesión actual de Bash (`source linux/activate.sh`).
* **Funcionamiento:** Resuelve el nombre del HOME portable desde `.env`, crea el skel base (`.bashrc`/`.bash_profile`), redirige `$HOME`, antepone `linux/bin` y `local/bin` al PATH (con guardia anti-duplicación) y exporta variables del toolchain hacia `local/`. Define la función `deactivate` que restaura la sesión original.

### `linux/bootstrap.sh`
* **Propósito:** Diagnóstico de dependencias del sistema.
* **Funcionamiento:** Solo lectura: detecta gestor de paquetes (apt/dnf/yum/pacman/zypper/apk), informa herramientas presentes/faltantes y sugiere comandos; nunca instala ni usa sudo. Rechaza explícitamente el modo de instalación automática eliminado.

### Scripts en `linux/bin/`
*   `configure-git.sh`: configuración guiada de Git (identidad validada, preferencias, credential helpers de gh y fallback elegible: caché temporal en memoria con expiración de 1 hora por defecto, o `store` persistente en texto plano) aislada en el HOME portable.
*   `customize-terminal.sh`: asistente de banner de bienvenida y prompt de PS1 entre marcas en `.bashrc`.
*   `install-lib.sh`: port Linux del instalador de librerías (library.spec, recetas, CMake+Ninja o Makefiles, header-only) hacia `$PORTABLE_PREFIX` (`local/`), con manifiesto para desinstalación.
*   `uninstall-lib.sh`: desinstalador basado en manifiestos (idéntico al de Windows).
*   `ayuda`: guía rápida adaptada a la variante Linux.
