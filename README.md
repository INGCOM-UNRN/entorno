# Entorno de Desarrollo Portable en C y Python

Entorno de desarrollo unificado y autocontenido para la cátedra de Programación 1 (UNRN
Andina): las mismas herramientas y comandos para todos los estudiantes, sin tocar la
configuración de la computadora.

## Instalación

### Windows

En PowerShell, dentro de una carpeta vacía y sin espacios ni acentos en la ruta (por
ejemplo `C:\dev\entorno`):

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/INGCOM-UNRN-P1/entorno/main/install.ps1 | iex
```

Instala la **base** (consola WezTerm con bash, Git, Python con uv, GitHub CLI, jonesy y
Ripley), en una sola descarga desde la imagen precompilada del último release, y ofrece los **módulos opcionales**: `compiladores` (gcc, gdb, make, cmake y
herramientas de análisis) y `vscode`. Los módulos se pueden agregar después con
`instalar-compiladores.bat` / `instalar-vscode.bat`. Después, abrí la consola con `launch.bat`.

Guía completa: [Instalación en Windows](docs/instalacion/windows.md).

### macOS y Linux

```bash
curl -fsSL https://raw.githubusercontent.com/INGCOM-UNRN-P1/entorno/main/install.sh | bash
```

Instala en `~/p1/entorno`, con espacio de trabajo `~/p1/dev`, sin `sudo`. El compilador y
Python vienen del sistema (el instalador indica cómo instalarlos si faltan). Guía:
[macOS y Linux](docs/instalacion/macos-linux.md). Para usarlo desde un clon sin instalar
nada: [Linux y WSL portable](docs/instalacion/linux-portable.md).

## Uso

```bash
doctor                    # verificar que todo funcione
configure-git.sh          # identidad de Git y sesión de GitHub
nuevo-proyecto tp01       # crear un proyecto (o: clonar <url-del-tp>)
make && verificar         # compilar y correr las pruebas de la cátedra
entregar                  # validar y armar la entrega
ayuda                     # todos los comandos
```

Ver [Primeros pasos](docs/uso/primeros-pasos.md) y [Trabajos prácticos](docs/uso/trabajos-practicos.md).

## Documentación

Todo está en [`docs/`](docs/README.md): instalación por plataforma, guías de uso
(compilación, librerías de C, personalización, computadoras compartidas) y referencia
técnica (arquitectura, configuración y scripts).

## Alcance

* **Cubre:** el aprovisionamiento y mantenimiento de un entorno de C y Python para Windows
  (portable, sobre MSYS2 UCRT64), macOS, Linux y WSL; los comandos de cátedra para trabajos
  prácticos; la instalación de las herramientas de la cátedra (`ripley` y el perfil
  estudiante de `mother`) y el autodiagnóstico (`doctor`, `soporte`).
* **No cubre:** la calificación ni la gestión de aulas (a cargo de `dredd` y `sulaco`), ni
  las reglas de análisis de código: el entorno instala y ejecuta esas herramientas, no las
  implementa.

## Desarrollo

Las reglas del repositorio están en [AGENTS.md](AGENTS.md) y los cambios en
[CHANGELOG.md](CHANGELOG.md). El CI corre linters, las pruebas de `tests/` y una
instalación completa en Windows.

## Licencia y contacto

[MIT](LICENSE). Martín René Vilugrón - mrvilugron@unrn.edu.ar - Ingeniería en Computación UNRN Andina
