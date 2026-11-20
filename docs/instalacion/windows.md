# Instalación en Windows

Guía para instalar, actualizar y quitar el entorno portable en Windows 10 y 11. El
paso a paso tiene capturas; al final están las opciones para laboratorios,
instalación sin internet y mantenimiento.

---

## Requisitos

* **Sistema:** Windows 10 (1903 o superior) u 11, de 64 bits.
* **Permisos:** no hace falta ser administrador; todo queda dentro de la carpeta del entorno.
* **Conexión:** solo para la instalación (o usá el [paquete offline](#instalación-sin-internet)).
* **Ruta:** la carpeta **no debe tener espacios, tildes ni estar dentro de OneDrive/Dropbox**
  (por ejemplo `C:\dev\entorno` o `D:\entorno_p1`). El instalador avisa si la ruta es conflictiva.

## Dos fases: base y módulos

La instalación está dividida para que el entorno esté listo rápido y sirva también en
contextos que no compilan C:

| Fase | Qué instala | Cómo se instala |
|---|---|---|
| **Base** | Consola (WezTerm + bash de MSYS2), **Git** (MinGit), **uv**, **Python** con las dependencias de las herramientas de la cátedra, GitHub CLI, jonesy y Ripley | `setup.ps1` |
| **Módulo `compiladores`** | gcc, gdb, make, cmake, ninja, cppcheck, clang-format/clang-tidy, doxygen y librerías comunes (descarga grande, vía pacman) | al final de `setup.ps1`, o después con `instalar-compiladores.bat` |
| **Módulo `vscode`** | VS Code portable con las extensiones de C/C++ y Python | al final de `setup.ps1`, o después con `instalar-vscode.bat` |

La base no usa pacman. En una instalación nueva llega como **imagen precompilada**: el CI
publica en cada release la base ya instalada y una capa con los compiladores, y `setup.ps1`
las descarga en un solo paso cada una (verificadas con SHA-256) en lugar de bajar cada
componente por separado. Si la imagen no está disponible, instala componente por componente.

Al terminar la base, `setup.ps1` pregunta por cada módulo (Enter = sí).
Los que no instales se pueden agregar en cualquier momento con su `.bat` o, desde la
consola del entorno, con `instalar compiladores` / `instalar vscode`; el comando `ayuda`
te recuerda cuáles faltan.

---

## Paso a paso

### 1. Abrir Windows PowerShell

Presioná la tecla `Windows`, escribí **PowerShell** y abrí **Windows PowerShell**. No hace
falta "Ejecutar como administrador".

![Búsqueda de Windows PowerShell en el Menú Inicio](../capturas/1_inicio.png)

La consola arranca en tu carpeta personal (por ejemplo `PS C:\Users\marti>`):

![Línea de comandos inicial de Windows PowerShell](../capturas/2_powershell.png)

### 2. Crear la carpeta del entorno

```powershell
mkdir entorno
cd entorno
```

![Creación y navegación al directorio de instalación](../capturas/3_ruta.png)

> [!IMPORTANT]
> Verificá que la ruta que aparece antes del `>` no tenga espacios ni acentos. No
> instales directamente en tu carpeta personal (`C:\Users\<vos>`): el instalador lo
> rechaza para no mezclar el entorno con tus archivos.

### 3. Ejecutar el instalador

Copiá la línea completa, pegala en la consola y presioná `Enter`:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/INGCOM-UNRN-P1/entorno/main/install.ps1 | iex
```

![Ejecución del comando de instalación en PowerShell](../capturas/4_instalacion.png)

* `Set-ExecutionPolicy Bypass -Scope Process` habilita scripts solo para esta ventana; no
  cambia la política del sistema.
* `irm ... | iex` descarga `install.ps1`, que baja `setup.ps1` a la carpeta y lo ejecuta.

### 4. Esperar la instalación de la base

El instalador muestra cada paso y lo registra en `install.log`:

![Log en tiempo real del proceso de instalación](../capturas/5_instalando.png)

1. Actualiza los scripts del entorno a la última versión publicada.
2. Descarga la imagen base del último release: MSYS2 (bash y el userland Unix), **MinGit**,
   **uv**, **Python** con sus dependencias, GitHub CLI, jonesy, WezTerm y el motor Ripley.
   Si no hay imagen, descarga cada uno por separado.
3. Completa la configuración local (consola, HOME portable).
4. Pregunta por los módulos opcionales (`compiladores`, `vscode`) e instala los elegidos;
   el de compiladores usa la capa precompilada del mismo release.

Todas las descargas se verifican (SHA-256) antes de usarse.

### 5. Abrir la consola

En la carpeta del entorno quedan los lanzadores:

![Archivos instalados en la carpeta entorno y cargadores](../capturas/6_lanzamiento.png)

| Archivo | Para qué sirve |
|---|---|
| `launch.bat` | Abre la consola (WezTerm con bash). |
| `launch-vscode.bat` | Abre VS Code (si instalaste el módulo). |
| `instalar-compiladores.bat`, `instalar-vscode.bat` | Instalan los módulos opcionales. |
| `setup.ps1` | Actualiza o repara el entorno. |
| `desinstalar.ps1` | Quita todo lo instalado. |

Hacé doble clic en **`launch.bat`**:

![Terminal WezTerm con banner institucional y comandos de cátedra](../capturas/7_terminal.png)

Seguí con [Primeros pasos](../uso/primeros-pasos.md).

---

## Opciones de `setup.ps1`

Si ya tenés `setup.ps1` en la carpeta (por ejemplo, porque clonaste el repositorio), podés
ejecutarlo directamente con parámetros:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; .\setup.ps1 -Modulos compiladores
```

| Parámetro | Efecto |
|---|---|
| `-Modulos <lista>` | Módulos a instalar después de la base: `compiladores`, `vscode`, `todos` o `ninguno` (varios separados por coma). Sin el parámetro, una instalación nueva pregunta y una actualización actualiza solo los ya instalados. |
| `-Yes` | Sin preguntas (laboratorios, CI). Sin `-Modulos`, instala todos los módulos. |
| `-HomeDirName <nombre>` | Nombre de la carpeta que hace de HOME portable (por defecto `home`). |
| `-ImportHostConfig` | Copia al entorno tu configuración de SSH, Git y VS Code de la máquina. |
| `-Latest` | Ignora los pines de `config/versions.json` e instala lo último publicado. |
| `-SkipUpdate` | No descarga versiones nuevas de los scripts antes de instalar. |
| `-SinImagen` | No usa las imágenes precompiladas: descarga cada componente (también con `-Latest`). |

Ejemplos:

```powershell
.\setup.ps1 -Modulos ninguno            # solo la base (Python, git, consola)
.\setup.ps1 -Yes                        # laboratorio: todo, sin preguntas
.\setup.ps1 -Yes -Modulos compiladores  # sin preguntas, sin VS Code
```

Para fijar la versión de los scripts durante el cuatrimestre, agregá `CHANNEL=<tag-o-rama>`
al archivo `.env` de la carpeta (ver [Configuración](../referencia/configuracion.md)).

---

## Actualizar

* **Todo el entorno:** volvé a ejecutar `setup.ps1` (o `update-env.sh` desde la consola).
  Actualiza los scripts, la base y los módulos que ya tengas instalados; tus datos de
  `home/` y la configuración de VS Code (`vscode/data`) se conservan.
* **Solo los paquetes del compilador:** `update-packages.sh` desde la consola.
* **Agregar un módulo:** `instalar-compiladores.bat` / `instalar-vscode.bat`.

## Instalación sin internet

**Con las imágenes del release** (la forma más simple): descargá de la página de
[releases](https://github.com/INGCOM-UNRN-P1/entorno/releases) `entorno-base-windows-x64.zip`
y, si hace falta compilar, `entorno-compiladores-windows-x64.zip`. En la máquina destino
descomprimí los dos **en la misma carpeta** (primero la base) y abrí `launch.bat`. Ejecutá
`doctor --fix` una vez para registrar los módulos presentes.

**Con un paquete propio** (incluye VS Code y lo que tengas instalado), en una máquina con
conexión y el entorno ya instalado:

```powershell
.\herramientas\package-env.ps1            # genera portable-env-offline.zip en la raíz
```

Opciones: `-Compact` poda documentación y traducciones de MSYS2; `-ConExtensiones` incluye
las extensiones de VS Code con un instalador offline; `-IncluirLibs` conserva las librerías
de `local/`. El paquete lleva la base y los módulos instalados en esa máquina.

En la máquina destino, copiá el ZIP junto con `install-offline.ps1` y ejecutá:

```powershell
.\install-offline.ps1 -Destino C:\dev     # el entorno queda en C:\dev\entorno
```

El paquete trae todo bajo una carpeta `entorno`, que se crea dentro de `-Destino`. Extrae, valida la estructura y deja el entorno
listo para `launch.bat`, sin internet ni permisos de administrador.

## Quitar el entorno

* **Todo lo instalado:** `desinstalar.ps1` muestra lo que va a borrar (MSYS2, MinGit,
  Python, VS Code, WezTerm, HOME portable, cachés) y pide confirmación. Los scripts del
  repositorio no se tocan.
* **Empezar de cero:** después de `desinstalar.ps1`, volvé a ejecutar `setup.ps1`.

## Problemas frecuentes

| Síntoma | Qué hacer |
|---|---|
| El antivirus bloquea la compilación (`VirtualProtect failed with code 0x5af`) | Ejecutá `herramientas\fix-antivirus.ps1` como administrador: agrega la carpeta a las exclusiones de Windows Defender. |
| `gcc: command not found` | El módulo de compiladores no está instalado: `instalar compiladores`. |
| Algo dejó de funcionar | En la consola: `doctor` (diagnóstico) y `doctor --fix` (repara lo que falte). Para consultar al docente: `soporte`. |
| La instalación falló a mitad | Volvé a ejecutar `setup.ps1`: retoma lo pendiente y reutiliza lo descargado. Revisá `install.log`. |
