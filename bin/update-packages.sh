#!/usr/bin/env bash
# update-packages.sh - Actualiza los paquetes del entorno portable de forma unificada.
# Ejecuta la sincronización/actualización de pacman y garantiza que todos los paquetes
# del entorno estén instalados: los de la base (packages-base.txt) y, si el módulo
# opcional de compiladores está instalado, los de packages-compiladores.txt. Usa la caché
# local portátil como almacenamiento de descargas.
#
# Diseñado para ejecutarse dentro del terminal portable de Windows (MSYS2/UCRT64).

set -eu

RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; CYAN='\033[36m'; RESET='\033[0m'

if [ -z "${PORTABLE_ROOT:-}" ]; then
    echo -e "${RED}[ERROR] No estás dentro de la consola del entorno portable.${RESET}"
    echo "Por favor, ejecutá 'launch.bat' antes de correr este script."
    exit 1
fi

CACHE_DIR="${PORTABLE_ROOT}/descargas/pacman_cache"
PKG_FILES=("${PORTABLE_ROOT}/packages-base.txt")
if [ -f "${PORTABLE_ROOT}/.compiladores_complete" ]; then
    PKG_FILES+=("${PORTABLE_ROOT}/packages-compiladores.txt")
fi

for PKG_FILE in "${PKG_FILES[@]}"; do
    if [ ! -f "$PKG_FILE" ]; then
        echo -e "${RED}[ERROR] No se encontró $(basename "$PKG_FILE") en ${PORTABLE_ROOT}.${RESET}"
        exit 1
    fi
done

mapfile -t packages < <(sed 's/#.*$//' "${PKG_FILES[@]}" | tr -d ' \t\r' | grep -v '^$')
pkg_string="${packages[*]}"

mkdir -p "$CACHE_DIR"

echo -e "${CYAN}======================================================================${RESET}"
echo -e "${CYAN}     Actualización Unificada de Paquetes del Entorno Portable${RESET}"
echo -e "${CYAN}======================================================================${RESET}"
echo "Paquetes del entorno: ${#packages[@]} (de: $(for F in "${PKG_FILES[@]}"; do printf '%s ' "$(basename "$F")"; done))"
[ -f "${PORTABLE_ROOT}/.compiladores_complete" ] || echo "Módulo de compiladores no instalado: se omite (instalalo con: instalar compiladores)."
echo ""

echo -e "${CYAN}-> Sincronizando base de datos de pacman...${RESET}"
pacman -Sy --cachedir "$CACHE_DIR" --noconfirm

echo ""
echo -e "${CYAN}-> Actualizando el sistema base...${RESET}"
pacman -Su --cachedir "$CACHE_DIR" --noconfirm || {
    echo -e "${YELLOW}[AVISO] La actualización del sistema reportó errores; se continúa con los paquetes del entorno.${RESET}"
}

echo ""
echo -e "${CYAN}-> Instalando/verificando paquetes obligatorios...${RESET}"
pacman -S --needed --cachedir "$CACHE_DIR" --noconfirm $pkg_string

echo ""
echo -e "${GREEN}[ÉXITO] Entorno actualizado: sistema al día y paquetes completos.${RESET}"
echo "Sugerencia: ejecutá 'doctor' para validar la salud del entorno."
