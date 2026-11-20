# Documentación del entorno

## Instalación

| Guía | Para quién |
|---|---|
| [Windows](instalacion/windows.md) | Entorno portable completo, paso a paso con capturas; módulos opcionales, laboratorios, instalación sin internet, actualización y desinstalación. |
| [macOS y Linux (computadora personal)](instalacion/macos-linux.md) | Instalador de una línea en `~/p1`, modos separado e integrado. |
| [Linux y WSL portable](instalacion/linux-portable.md) | Usar el entorno desde un clon, activando una sesión, sin tocar el sistema. |

## Uso

| Guía | Contenido |
|---|---|
| [Primeros pasos](uso/primeros-pasos.md) | Abrir el entorno, verificarlo, configurar Git y crear el primer proyecto. |
| [Trabajos prácticos](uso/trabajos-practicos.md) | `nuevo-proyecto`, `clonar`, `verificar`, `ripley`, `entregar`, respaldos y soporte. |
| [Compilación con GCC](uso/compilacion-gcc.md) | Fases de la compilación, advertencias, optimización y proyectos multiarchivo. |
| [Librerías de C](uso/librerias-c.md) | Instalar y quitar librerías desde GitHub con `install-lib.sh`. |
| [Personalizar la consola](uso/personalizacion.md) | Colores de WezTerm y mensaje de bienvenida de bash. |
| [Computadoras compartidas](uso/computadoras-compartidas.md) | Limpieza de credenciales e historial antes de irte. |

## Referencia

| Documento | Contenido |
|---|---|
| [Arquitectura](referencia/arquitectura.md) | Componentes, sesión, instalación en fases, verificación de descargas y estructura del repositorio. |
| [Configuración](referencia/configuracion.md) | `config/versions.json`, `.env`, listas de paquetes y plantillas. |
| [Scripts](referencia/scripts.md) | Funcionamiento interno de cada script. |
| [Casos de uso](casos-de-uso.md) | Problemas de la cátedra que resuelve el entorno. |

## Desarrollo del entorno

| Documento | Contenido |
|---|---|
| [AGENTS.md](../AGENTS.md) | Reglas obligatorias del repositorio (commits, aislamiento, codificación). |
| [CHANGELOG.md](../CHANGELOG.md) | Registro de cambios por versión. |
| [Plan de trabajo](desarrollo/plan.md) | Hoja de ruta por fases. |
| [Mejoras y problemas](desarrollo/mejoras-y-problemas.md) | Relevamiento de problemas detectados y su resolución. |
| [Propuesta: prompt de bash](desarrollo/propuesta-prompt-bash.md) | Diseño pendiente de un prompt pedagógico. |
