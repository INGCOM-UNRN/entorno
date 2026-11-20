# Personalizar la consola

## Apariencia de la terminal (WezTerm, Windows)

Hacé doble clic en `customize-terminal.bat` (en la carpeta del entorno). El asistente
permite elegir:

* **Esquema de colores:** Tokyo Night (por defecto), Dracula, Gruvbox, Nord u One Half Dark.
* **Tamaño de letra** (de 8 a 24).
* **Opacidad del fondo** (transparencia de la ventana).
* **Barra de pestañas:** habilitarla para trabajar con varias terminales en una ventana.

Los cambios se guardan en `wezterm.lua` (generado desde `config/wezterm.lua.template`). Si
la terminal tiene el archivo abierto, el asistente reintenta hasta poder escribirlo.

## Mensaje de bienvenida de bash

```bash
customize-bash.sh          # Windows
customize-terminal.sh      # Linux portable
```

Elegí una plantilla para el banner (saludo con tu nombre, frase de programación al azar,
resumen de comandos útiles), escribí uno propio o desactivalo, y elegí el color (celeste,
verde, amarillo, violeta o blanco). La personalización se guarda entre marcas en tu
`.bashrc`, así que no pisa tus propios agregados.
