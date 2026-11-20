# shellcheck shell=sh
# p1-entorno.sh - Perfil de MSYS2 del entorno portable (Windows).
#
# Lo copia lib/env.common.psm1 a msys64/etc/profile.d/ en cada inicio de sesión (lanzadores,
# VS Code): no hay que editarlo ahí, se pisa. /etc/profile de MSYS2 (UCRT64) antepone
# /ucrt64/bin y /usr/bin al PATH heredado; este perfil vuelve a poner adelante, en el orden de
# la sesión, los comandos del entorno (bin/), el Python de la base y el Git de la base
# (MinGit). Así una instalación anterior que todavía tiene el Python o el git de pacman usa
# igual los de la base, como VS Code.

if [ -n "${PORTABLE_ROOT:-}" ] && command -v cygpath >/dev/null 2>&1; then
    _p1_root="$(cygpath -u "$PORTABLE_ROOT")"
    _p1_pre="$_p1_root/bin"
    if [ -n "${P1_PYTHON_DIR:-}" ]; then
        _p1_py="$(cygpath -u "$P1_PYTHON_DIR")"
        _p1_pre="$_p1_pre:$_p1_py:$_p1_py/Scripts"
    fi
    if [ -x "$_p1_root/mingit/cmd/git.exe" ]; then
        _p1_pre="$_p1_pre:$_p1_root/mingit/cmd"
    fi
    # Shells anidados: el PATH ya empieza con estos directorios
    case ":$PATH:" in
        ":$_p1_pre:"*) ;;
        *) PATH="$_p1_pre:$PATH" ;;
    esac
    export PATH
    unset _p1_root _p1_py _p1_pre
fi
