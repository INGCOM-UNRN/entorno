# Trabajos prácticos

Flujo completo de un trabajo práctico con los comandos de la cátedra, desde crearlo hasta
entregarlo. Funcionan igual en Windows, macOS y Linux.

## Resumen

```bash
nuevo-proyecto tp01             # crea tp01/ con main.c, Makefile y pruebas de ejemplo
nuevo-proyecto --tipo tp tp02   # plantilla modular (libs/ + ejercicios/ + ./tp.sh)
clonar <url-del-tp>             # o clonar el TP de GitHub Classroom
cd tp01 && make                 # compilar (make debug / make asan)
make ripley                     # auditar el código con Ripley
verificar                       # correr las pruebas de la cátedra
entregar                        # validar y armar el ZIP de entrega
```

## Crear o clonar el proyecto

* **`nuevo-proyecto <nombre>`** crea la estructura lista para compilar: `main.c`, Makefile de
  cátedra, `.gitignore`, un caso de prueba de ejemplo y la configuración de VS Code
  (Ctrl+Shift+B compila, F5 depura con GDB). Con `--tipo` elegís la plantilla:
  * `plano` (por defecto): un programa con los objetivos `debug` (símbolos sin optimizar),
    `asan` (AddressSanitizer + UBSan), `test` (corre `tests/caso_NN.in/.out`) y `ripley`.
  * `tp`: plantilla oficial de TP modular (`libs/`, `ejercicios/`, gestor `./tp.sh`).
  * `lib`: plantilla de biblioteca estática (`include/`, `src/`, `tests/`, `manage.sh`).
* **`clonar <url | owner/repo>`** clona el TP (por ejemplo, de GitHub Classroom) en
  `~/proyectos/<repo>` y deja configurado el upstream para que `git push` funcione sin
  argumentos.

## Compilar y depurar

```bash
make            # compilación normal
make debug      # con símbolos, para gdb
make asan       # detecta errores de memoria en tiempo de ejecución
gdb ./programa  # depurador
```

`doctor --fix` instala en tu HOME el `.gdbinit` de la cátedra, que agrega a GDB los comandos
`explicar`, `dashboard` y `vars`.

En Windows esto requiere el módulo `compiladores`. Para entender cada fase de la
compilación, ver [Compilación con GCC](compilacion-gcc.md).

## Verificar antes de entregar

* **`ripley check .`** (o `make ripley`): el motor de análisis de la cátedra revisa el código
  con reglas de Programación 1, lo compila con AddressSanitizer y explica los errores de GCC
  en lenguaje claro. `ripley doctor` diagnostica el propio motor.
* **`verificar`**: si el proyecto declara un manifiesto de Ripley (`ripley.toml` o un paquete
  `.ripkg`), delega en `ripley check .`; si no, compila y compara la salida del programa con
  los casos `tests/caso_NN.in` / `.out`, mostrando la salida esperada y la obtenida.

## Entregar

```bash
entregar
```

Compila, corre las pruebas (y `ripley check . --strict` si hay manifiesto) y genera
`ENTREGA_<proyecto>_<fecha>.zip` solo con los fuentes. Si el proyecto es un repositorio con
remoto, ofrece hacer commit y push, siempre con tu confirmación.

## Resguardar tu trabajo

```bash
backup            # ZIP fechado con tu HOME portable, fuera de la carpeta del entorno
restaurar         # recupera el último respaldo (o el ZIP que indiques)
```

Guardá el respaldo en otro medio: si el pendrive falla, el respaldo no puede estar en él.

## Pedir ayuda

```bash
soporte
```

Genera `soporte-<fecha>.txt` con el diagnóstico del entorno, sin datos personales (rutas,
usuario, equipo e identidad de Git se anonimizan). Adjuntalo en tu consulta al docente.
