# Reddots

Primero hay que instalar CachyOS con Hyprland (sin Noctalia).

Para descargarlo:

```bash
git clone https://github.com/R3ddas/Reddots.git ~/Reddots
```

Para instalarlo:

```bash
cd ~/Reddots
chmod +x install.sh update.sh
./install.sh
```

Para actualizarlo, usa **Actualizar Reddots** en el menú del icono de Reddots (arriba de la barra). Baja los cambios del repo y ejecuta `update.sh`, que actualiza el sistema y se asegura de que esté todo lo que necesita Reddots (`packages.txt`, enlaces de la config...). No instala ni quita ninguna otra app: si has desinstalado algo de `packages_opt.txt` o has vuelto a instalar Firefox, se queda así. Desde un terminal es lo mismo que:

```bash
git pull
./update.sh
```

**Instalar Reddots**, en el mismo menú, baja los cambios y vuelve a pasar `install.sh` entero: pregunta por los opcionales que no tengas y vuelve a quitar los que sobran.

## Si algo falla

- **La actualización del sistema (`paru -Syu`) falla por una dependencia de toolkit.** Fuerza a que Hyprland y hyprtoolkit salgan los dos del repositorio `extra`:

  ```bash
  sudo pacman -Syu extra/hyprtoolkit
  ```

- **Las descargas van muy lentas.** Actualiza la lista de servidores de CachyOS por los más rápidos desde donde estés:

  ```bash
  sudo cachyos-rate-mirrors
  ```

- **La pantalla de bloqueo no deja entrar (o se queda de un color liso).** No hay gestor de inicio de sesión: el equipo entra solo en la TTY1 y la contraseña la pide la pantalla de bloqueo de Quickshell. Si falla, pasa a otra TTY con `Ctrl + Alt + F2`, entra con tu usuario y vuelve a lanzar Quickshell en la sesión de Hyprland (vuelve a pedir la contraseña):

  ```bash
  hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("quickshell")'
  ```

- **Prefieres que la TTY1 vuelva a pedir usuario y contraseña.** Quita el inicio automático (solo lo vuelve a poner `install.sh`, no las actualizaciones; la pantalla de bloqueo saldría igual después de entrar):

  ```bash
  sudo rm /etc/systemd/system/getty@tty1.service.d/autologin.conf
  ```

- **No quieres que el idioma del sistema cambie con el de Reddots.** Al cambiar el idioma en el menú del icono de Reddots también cambian los textos del sistema (solo los textos: fechas, números y moneda siguen igual), del todo al reiniciar la sesión. Para que el sistema vuelva a su idioma de siempre, borra el archivo donde se apunta y reinicia la sesión:

  ```bash
  rm ~/.local/state/reddots/lc_messages
  ```

## Qué hay en cada carpeta

- `hypr/`: configuración de Hyprland (en Lua: `hyprland.lua` y los atajos en `keybinds.lua`).
- `quickshell/`: la interfaz (barra, lanzador, notificaciones, fondo...). Todo arranca en `shell.qml`.
  - `bar/`: la barra lateral (`Bar.qml`) y sus widgets; en `bar/settings/`, el engranaje y todo lo que se pliega con él (uso del sistema, capturas, medidas, tema y brillo, y fondo).
  - `windows/`: ventanas y capas sueltas: fondo, borde, lanzador, portapapeles, notificaciones, pantalla de bloqueo (Super + L)...
  - `services/`: singletons con el estado compartido (tema, medidas, fondo, uso del sistema, idioma...), sin nada visible. Las traducciones al inglés están en `services/en.json`: la interfaz se pasa de español a inglés desde el menú del icono de Reddots.
  - `components/`: piezas comunes con las que se montan las demás (icono de la barra, desplegable, slider...).
  - `scripts/`: los scripts que lanza la interfaz.
  - `assets/`: el icono de Reddots y la configuración de PAM con la que la pantalla de bloqueo comprueba la contraseña (`assets/pam/lock`).
- `apps/`: configuración de cada programa, una carpeta por programa (`alacritty/`, `fish/`, `fastfetch/`, `vscode/`). En `vscode/extensions.txt` están sus extensiones: si VS Code está instalado, `install.sh` las instala todas sin preguntar.
- `wallpapers/`: los fondos de pantalla.
- `lib.sh`: funciones que comparten `update.sh`, `install.sh` y los scripts de la barra.
- `packages.txt`: los paquetes que necesita Reddots; los instala `update.sh`, así que vuelven en cada actualización.
- `packages_opt.txt`: las apps (Chrome, VS Code, LaTeX, Steam...); solo las ofrece `install.sh`, que pregunta antes de instalarlas.
- `packages_remove.txt`: los que sobran (Firefox, Kitty, Dolphin...); solo los quita `install.sh`. Las apps que no salen en el lanzador se eligen desde él, con la rueda junto al buscador.
