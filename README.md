# Reddots

Primero hay que instalar Cachyos con Hyprland (sin Noctalia)

Para descargarlo:

git clone https://github.com/R3ddas/Reddots.git ~/Reddots

Para instalarlo:

cd ~/Reddots
chmod +x install.sh
./install.sh

## Qué hay en cada carpeta

- `hypr/`: configuración de Hyprland (en Lua) y sus scripts.
- `quickshell/`: la interfaz (barra, lanzador, notificaciones, fondo...). Todo arranca en `shell.qml`.
  - `bar/`: la barra lateral (`Bar.qml`) y sus widgets; en `bar/settings/`, los ajustes del engranaje.
  - `windows/`: ventanas y capas sueltas: fondo, borde, lanzador, portapapeles, notificaciones...
  - `services/`: singletons con el estado compartido (tema, medidas, fondo, uso del sistema...), sin nada visible.
  - `components/`: piezas comunes con las que se montan las demás (icono de la barra, desplegable, slider...).
  - `scripts/`: los scripts que lanza la interfaz.
- `apps/`: configuración de cada programa, una carpeta por programa (`alacritty/`, `fish/`, `fastfetch/`, `vscode/`).
- `wallpapers/`: los fondos de pantalla.
- `packages.txt` y `hidden_apps.txt`: los paquetes que instala `install.sh` y las apps que se ocultan del lanzador.
