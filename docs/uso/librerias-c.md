# Librerías de C

`install-lib.sh` descarga, compila e instala librerías de C desde GitHub dentro del
entorno, sin rutas manuales: después de instalarla, `#include <libreria.h>` funciona y el
enlazador la encuentra.

| Plataforma | Dónde se instala |
|---|---|
| Windows | prefijo portable de MSYS2 (`/ucrt64`); requiere el módulo `compiladores` |
| Linux portable | `local/` del entorno (`$PORTABLE_PREFIX`) |

## Instalar

```bash
install-lib.sh <usuario/repositorio> [rama_o_tag]
```

Ejemplos:

```bash
install-lib.sh immediate-mode-ui/nuklear          # librería de solo cabeceras
install-lib.sh davidsiaw/inih r29                 # proyecto con CMake, en un tag
install-lib.sh mi-usuario/mi-libreria-matematica  # plantilla de la cátedra (library.spec)
```

El script detecta cómo construir el proyecto, en este orden: especificación
`library.spec` (plantilla de librería de la cátedra), receta `.portable-recipe.sh`,
`CMakeLists.txt` o `Makefile`; las librerías de solo cabeceras se copian directamente.
Registra cada archivo instalado en un manifiesto.

## Desinstalar

```bash
uninstall-lib.sh             # lista las librerías instaladas
uninstall-lib.sh <nombre>    # quita sus archivos usando el manifiesto
```

Las librerías instaladas con CMake o `make install` sin un manifiesto detallado solo quedan
anotadas: el script avisa que no puede quitarlas automáticamente.

## Respaldos

`backup` guarda los manifiestos de las librerías instaladas; al recuperar un respaldo,
`restaurar` indica cuáles volver a instalar con `install-lib.sh`. El paquete offline
(`package-env.ps1`) no las incluye salvo que uses `-IncluirLibs`.
