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

## Qué hay en cada carpeta

- `hypr/`: configuración de Hyprland (en Lua: `hyprland.lua` y los atajos en `keybinds.lua`) y sus scripts.
- `quickshell/`: la interfaz (barra, lanzador, notificaciones, fondo...). Todo arranca en `shell.qml`.
  - `bar/`: la barra lateral (`Bar.qml`) y sus widgets; en `bar/settings/`, el engranaje y todo lo que se pliega con él (uso del sistema, capturas, brillo, medidas, tema y fondo).
  - `windows/`: ventanas y capas sueltas: fondo, borde, lanzador, portapapeles, notificaciones...
  - `services/`: singletons con el estado compartido (tema, medidas, fondo, uso del sistema...), sin nada visible.
  - `components/`: piezas comunes con las que se montan las demás (icono de la barra, desplegable, slider...).
  - `scripts/`: los scripts que lanza la interfaz.
- `apps/`: configuración de cada programa, una carpeta por programa (`alacritty/`, `fish/`, `fastfetch/`, `vscode/`).
- `wallpapers/`: los fondos de pantalla.
- `packages.txt`, `packages_opt.txt` y `hidden_apps.txt`: los paquetes que instala `install.sh`, los opcionales (pregunta antes de instalarlos) y las apps que se ocultan del lanzador.
