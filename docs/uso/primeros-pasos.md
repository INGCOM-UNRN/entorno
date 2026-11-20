# Primeros pasos

Qué hacer después de instalar el entorno. Los comandos se escriben en la consola del
entorno: en Windows, la que abre `launch.bat`; en macOS/Linux, la terminal (o `~/p1/entrar`
en modo separado, o `source linux/activate.sh` en la variante portable).

## Abrir el entorno (Windows)

| Lanzador | Qué abre |
|---|---|
| `launch.bat` | La consola: WezTerm con bash, el PATH del entorno y tu HOME portable. Si WezTerm no está, abre bash en la consola clásica de Windows. |
| `launch-vscode.bat` | VS Code (módulo `vscode`), con el compilador, Python y Git del entorno en su terminal integrada. |

Los dos cargan la misma sesión: al cerrarlos, tu Windows queda como estaba.

> [!TIP]
> **Lanzadores sin ventana negra:** `build-launcher.sh` compila `launch.exe` y
> `launch-vscode.exe` (requiere el módulo `compiladores`), que abren la consola y el editor
> sin la ventana intermedia de CMD.

## 1. Verificar que todo funcione

```bash
doctor
```

Compila un programa de prueba, revisa Python, Git y las herramientas de build. Si algo
falta, `doctor --fix` regenera la configuración base sin tocar tus archivos. En Windows,
si el compilador no está instalado lo avisa: se instala con `instalar compiladores`.

## 2. Configurar Git y GitHub

```bash
configure-git.sh
```

Te pide nombre y correo, inicia sesión en GitHub con `gh auth login` y deja las
credenciales dentro de tu HOME portable (nunca en la configuración de la máquina). Es
obligatorio para entregar trabajos con Git.

## 3. Crear tu primer proyecto

```bash
nuevo-proyecto tp01
cd tp01
make
```

Genera `main.c`, un Makefile de cátedra (objetivos `debug`, `asan`, `test` y `ripley`),
`.clang-format` y la configuración de depuración (F5) para VS Code. Más en
[Trabajos prácticos](trabajos-practicos.md).

## 4. Consultar la ayuda

```bash
ayuda
```

Lista los comandos del entorno y, en Windows, los módulos opcionales que todavía no
instalaste.

## Qué hay en el entorno

| Herramienta | Comando | Origen en Windows |
|---|---|---|
| Consola | bash, coreutils, grep, sed, awk, tar | base (MSYS2) |
| Control de versiones | `git`, `gh` | base (MinGit, GitHub CLI) |
| Python | `python`, `pip`, `uv` | base (uv) |
| Editor en terminal | `jonesy` | base |
| Análisis de código C | `ripley` | base |
| Compilador y depurador | `gcc`, `g++`, `gdb` | módulo `compiladores` |
| Build | `make`, `cmake`, `ninja` | módulo `compiladores` |
| Análisis y formato | `cppcheck`, `clang-format`, `clang-tidy`, `doxygen` | módulo `compiladores` |
| Editor gráfico | VS Code | módulo `vscode` |

## VS Code en español

VS Code se instala en inglés. Para cambiarlo:

1. Abrí VS Code con `launch-vscode.bat` y presioná `Ctrl + Shift + X`.
2. Buscá **Spanish Language Pack for Visual Studio Code** (de Microsoft) e instalalo.
3. Aceptá **Change Language and Restart** en la notificación.
