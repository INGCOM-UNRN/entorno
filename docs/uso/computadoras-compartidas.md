# Computadoras compartidas

Si usás el entorno desde un pendrive en laboratorios o computadoras ajenas, todo lo tuyo
(historial, llaves SSH, credenciales de Git, configuración de VS Code) queda en el HOME
portable, dentro del pendrive. El entorno no escribe en la carpeta de usuario de la
máquina ni necesita permisos de administrador.

Aun así, antes de irte de una computadora compartida:

1. Cerrá VS Code y las terminales del entorno.
2. Abrí PowerShell en la carpeta del entorno y ejecutá:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force; .\herramientas\clean-shared-host.ps1
   ```
3. Revisá la lista de lo que se va a borrar y confirmá con `s`.

Borra el historial de comandos, las llaves SSH privadas, los tokens y contraseñas de
`.git-credentials`, los datos de usuario y las extensiones personales de VS Code, y limpia
los rastros que pudieran quedar en la máquina (historiales de Windows, credenciales
cacheadas). Tus proyectos, los compiladores y el editor quedan listos para el próximo uso.

> [!TIP]
> Si iniciaste sesión en GitHub, el comando `ayuda` te recuerda ejecutar la limpieza.
> Para no depender de credenciales guardadas, en `configure-git.sh` elegí la caché
> temporal en memoria (expira a la hora) en lugar de `store`.
