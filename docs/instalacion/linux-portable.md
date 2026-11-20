# Linux y WSL: variante portable (`linux/`)

Variante del entorno para GNU/Linux y WSL que se usa **desde un clon del repositorio**,
activando una sesión de Bash. Es la opción para trabajar con el entorno en una carpeta
(por ejemplo, un pendrive) sin tocar tu sistema.

> Si querés instalar el entorno en tu computadora personal con macOS o Linux, la vía
> recomendada es el instalador de una línea: ver [macOS y Linux personal](macos-linux.md).

## Principios

* **No invasiva:** no modifica nada fuera de la carpeta del repositorio.
* **Sin `sudo`:** nunca instala paquetes del sistema ni pide permisos de administrador.
* **HOME aislado:** `$HOME` apunta a `home/` (o al nombre definido en `.env`); historial,
  llaves SSH y credenciales de Git quedan dentro del entorno.
* **Sin residuos:** la activación vale solo para la sesión actual; `deactivate` (o cerrar la
  terminal) deja todo como estaba.

## 1. Revisar las dependencias del sistema

El compilador, Python y demás herramientas vienen de tu distribución. Este diagnóstico, de
solo lectura, te dice qué falta y con qué comando instalarlo:

```bash
linux/bootstrap.sh
```

Detecta el gestor de paquetes (`apt`, `dnf`, `pacman`, `zypper`, `apk`) y clasifica:

* **Obligatorias:** `git`, `gcc`, `g++`, `make`, `cmake`, `ninja`, `python3`, `pip`, `curl`.
* **Recomendadas:** `gdb`, `cppcheck`, `doxygen`, `gh`, `uv`.

Por ejemplo, en Debian/Ubuntu sugiere `sudo apt install build-essential cmake ninja-build python3-pip curl`.

## 2. Activar y desactivar la sesión

```bash
source linux/activate.sh   # activa el entorno en esta terminal
ayuda                      # guía rápida de comandos
deactivate                 # vuelve a tu sesión original
```

Al activarse:

1. `$HOME` pasa a ser la carpeta portable (`$PORTABLE_ROOT/home`).
2. `linux/bin` y `local/bin` se agregan al principio del `PATH`.
3. El toolchain de C resuelve las librerías locales sin tocar `/usr`: `CC=gcc`, `CXX=g++`,
   `CPATH`, `LIBRARY_PATH` y `LD_LIBRARY_PATH` apuntan a `local/`, igual que
   `PKG_CONFIG_PATH` y `CMAKE_PREFIX_PATH`.
4. Se aplica el prompt institucional y se muestra el banner con `ayuda`.

## 3. Comandos disponibles

Los mismos comandos de cátedra que en Windows (ver [Trabajos prácticos](../uso/trabajos-practicos.md)
y la [referencia de scripts](../referencia/scripts.md#5-variante-linux-linux)):
`nuevo-proyecto`, `clonar`, `verificar`, `entregar`, `ripley`, `doctor`, `backup`,
`restaurar`, `soporte`, `install-lib.sh`, `uninstall-lib.sh`, `configure-git.sh`,
`customize-terminal.sh`, `diagnose-env.sh`, `smoke.sh` y `update-env.sh`.

## Actualizar

```bash
update-env.sh      # actualiza los scripts de linux/ desde el repositorio (o git pull)
```

Las herramientas del sistema se actualizan con el gestor de paquetes de tu distribución.

## Problemas frecuentes

* **Dubious ownership:** si Git reclama la propiedad de un repositorio en una unidad
  compartida, ejecutá dentro del entorno `git config --global safe.directory '<ruta-del-repo>'`.
* **pip bloqueado (PEP 668):** usá `pip --user` (con la sesión activa queda dentro del HOME
  portable) o entornos virtuales; `uv venv` los crea directamente.
* **Idioma:** la variante no fuerza el locale; si tu sistema no tiene `es_AR.UTF-8`, los
  mensajes siguen el idioma disponible.

## Calidad

La variante se prueba con [`tests/test_linux_env.sh`](../../tests/test_linux_env.sh) en un
sandbox aislado (activación y restauración del entorno, skel del HOME, librerías locales,
`nuevo-proyecto`, `verificar`, `entregar`, `backup`/`restaurar`, `doctor` y `bootstrap.sh`),
en CI con Ubuntu. Se usa en Fedora, Arch, Ubuntu/Debian, openSUSE y WSL2.
