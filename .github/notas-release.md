Imágenes precompiladas del entorno de Windows. `setup.ps1` las usa automáticamente en las
instalaciones nuevas: no hace falta descargarlas a mano para instalar con conexión.

| Archivo | Qué es |
|---|---|
| `entorno-base-windows-x64.zip` | **Entorno completo**: scripts, lanzadores, MSYS2 (bash), MinGit, Python con uv, WezTerm, gh, jonesy y Ripley. Se descomprime y funciona solo. |
| `entorno-compiladores-windows-x64.zip` | **Complemento (no es un entorno)**: solo los archivos de MSYS2 que agrega el módulo de compiladores (gcc, gdb, make, cmake, cppcheck, clang-tools, doxygen). Sin la base no funciona. |
| `SHA256SUMS` | Sumas SHA-256 de los dos archivos. |

La capa de compiladores se arma como diferencia respecto de la base **de este mismo
release**: usala solo sobre `entorno-base` de esta versión, no sobre una base de otra.

## Instalación sin internet

1. Descomprimí `entorno-base-windows-x64.zip` en una carpeta (por ejemplo `C:\dev`).
2. Si vas a compilar, descomprimí `entorno-compiladores-windows-x64.zip` **en la misma
   carpeta**, encima de la base.
3. Abrí `launch.bat` y ejecutá `doctor --fix` una vez: registra los módulos presentes y
   termina de aplicar la capa (borra las versiones viejas de paquetes que reemplaza).

Más detalles en [docs/instalacion/windows.md](https://github.com/INGCOM-UNRN/entorno/blob/main/docs/instalacion/windows.md#instalación-sin-internet).
