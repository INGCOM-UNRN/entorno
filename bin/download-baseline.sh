#!/usr/bin/env bash
# download-baseline.sh - Descarga a la caché local portable los paquetes de pacman del
# módulo de compiladores (para preparar instalaciones sin internet)
# Diseñado para ejecutarse dentro del entorno MSYS2 (UCRT64)

set -e

# Asegurar que PORTABLE_ROOT esté definido, de lo contrario inferir desde la ubicación del script
if [ -z "$PORTABLE_ROOT" ]; then
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    PORTABLE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

CACHE_DIR="${PORTABLE_ROOT}/descargas/pacman_cache"
mkdir -p "$CACHE_DIR"

echo "========================================================"
echo " Descarga de Baseline de Paquetes MSYS2 (UCRT64) "
echo "========================================================"
echo "Directorio de caché: $CACHE_DIR"
echo "Sincronizando base de datos de paquetes..."
pacman -Sy

echo -e "\nDescargando paquetes del baseline y sus dependencias..."
# Fuente única de paquetes: packages-compiladores.txt (la base no usa pacman: git es MinGit)
PKG_FILES=("${PORTABLE_ROOT}/packages-compiladores.txt")
for PKG_FILE in "${PKG_FILES[@]}"; do
    if [ ! -f "$PKG_FILE" ]; then
        echo -e "\e[31m[ERROR] No se encontró $(basename "$PKG_FILE") en ${PORTABLE_ROOT}.\e[0m"
        exit 1
    fi
done
mapfile -t packages < <(sed 's/#.*$//' "${PKG_FILES[@]}" | tr -d ' \t\r' | grep -v '^$')

pkg_string="${packages[*]}"

# Descargar paquetes a la caché local sin instalarlos (-Sw)
pacman -Sw --cachedir "$CACHE_DIR" --noconfirm --needed $pkg_string

echo -e "\n========================================================"
echo " Descarga completada con éxito "
echo " Los paquetes se guardaron en: $CACHE_DIR"
echo "========================================================"
