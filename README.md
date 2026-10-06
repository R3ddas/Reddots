# Reddots

Primero hay que instalar CachyOS con Hyprland (sin Noctalia).

Para descargarlo:

```bash
git clone https://github.com/R3ddas/Reddots.git ~/Reddots
```

Para instalarlo:

```bash
cd ~/Reddots
chmod +x install.sh
./install.sh
```

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

- **Prefieres que la TTY1 vuelva a pedir usuario y contraseña.** Quita el inicio automático (lo vuelve a poner `install.sh`; la pantalla de bloqueo saldría igual después de entrar):

  ```bash
  sudo rm /etc/systemd/system/getty@tty1.service.d/autologin.conf
  ```

## Qué hay en cada carpeta

- `hypr/`: configuración de Hyprland (en Lua: `hyprland.lua` y los atajos en `keybinds.lua`) y sus scripts.
- `quickshell/`: la interfaz (barra, lanzador, notificaciones, fondo...). Todo arranca en `shell.qml`.
  - `bar/`: la barra lateral (`Bar.qml`) y sus widgets; en `bar/settings/`, el engranaje y todo lo que se pliega con él (uso del sistema, capturas, medidas, tema y brillo, y fondo).
  - `windows/`: ventanas y capas sueltas: fondo, borde, lanzador, portapapeles, notificaciones, pantalla de bloqueo (Super + L)...
  - `services/`: singletons con el estado compartido (tema, medidas, fondo, uso del sistema...), sin nada visible.
  - `components/`: piezas comunes con las que se montan las demás (icono de la barra, desplegable, slider...).
  - `scripts/`: los scripts que lanza la interfaz.
  - `assets/`: el icono de Reddots y la configuración de PAM con la que la pantalla de bloqueo comprueba la contraseña (`assets/pam/lock`).
- `apps/`: configuración de cada programa, una carpeta por programa (`alacritty/`, `fish/`, `fastfetch/`, `vscode/`).
- `wallpapers/`: los fondos de pantalla.
- `packages.txt` y `packages_opt.txt`: los paquetes que instala `install.sh` y los opcionales (pregunta antes de instalarlos). Las apps que no salen en el lanzador se eligen desde él, con la rueda junto al buscador.
