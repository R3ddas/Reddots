#!/usr/bin/env bash
# Lo que tiene que cumplirse siempre para que Reddots funcione: el sistema al día, los
# paquetes que necesita la config (packages.txt), los servicios y los enlaces de la config.
# No instala ni quita nada que no sea de Reddots (las apps de packages_opt.txt, Firefox...):
# eso solo lo hace install.sh, que empieza ejecutando este mismo script.
# Lo lanza el botón "Actualizar" de la barra (scripts/update-reddots.sh), justo después de
# bajar los cambios del repo. Se puede ejecutar tantas veces como se quiera.
set -euo pipefail
# Con BASH_SOURCE y no con $0: install.sh lo carga con source, y ahí $0 es install.sh
cd "$(dirname "${BASH_SOURCE[0]}")"
DOTS="$PWD" # Guardo la ruta en una variable para no acceder todo el rato

# Los nombres de una de las listas del repo (packages*.txt; también lo usa install.sh),
# uno por línea: sin comentarios (lo que va tras #), sin líneas vacías y sin espacios
listFile() { sed 's/#.*//' "$1" | awk 'NF { print $1 }'; }

echo "Instalando paru"

sudo pacman -S --needed  --noconfirm paru   # El descargador de paquetes (aquí y no en packages.txt: hace falta ya para instalarlo y para el "paru -Syu" de abajo)

echo "Actualizando el sistema"

paru -Syu --noconfirm   # Actualiza el sistema por completo antes de instalar (repos oficiales + AUR)


echo "Instalando paquetes"

# Con paru y no con pacman: así packages.txt puede tener tanto paquetes de los repos como de
# AUR (los de los repos, paru se los pasa a pacman). En una sola llamada y no con xargs, para
# que paru siga teniendo el terminal (sudo pide ahí la contraseña al instalar los de AUR)
mapfile -t packages < <(listFile packages.txt)
paru -S --needed --noconfirm "${packages[@]}"

echo "Servicios"

# El agente de polkit (la ventana que pide la contraseña al montar un disco, etc.) es
# ahora quickshell/windows/PolkitDialog.qml. Solo puede haber uno por sesión, y hyprpolkitagent
# viene instalado y activado de serie: arrancaría antes que Quickshell y le quitaría el
# sitio. Se para y se desactiva antes de desinstalarlo, porque quitar el paquete no
# detiene el que ya está en marcha en esta sesión.
if pacman -Qq hyprpolkitagent &>/dev/null; then
    systemctl --user disable --now hyprpolkitagent.service &>/dev/null || true
    systemctl --user reset-failed hyprpolkitagent.service &>/dev/null || true
    sudo pacman -Rns --noconfirm hyprpolkitagent
fi

echo "Sistema de archivos"

# Enlaza "$1" (del repo) en "$2", creando antes la carpeta que lo contiene si aún no existe
link() { mkdir -p "$(dirname "$2")"; ln -sfn "$1" "$2"; }

# Quickshell se enlaza como carpeta entera (no archivo a archivo) para que los
# widgets nuevos que se añadan al repo aparezcan solos, sin volver a ejecutar esto.
# Si ya existe como carpeta de verdad (la config de otra shell de Quickshell), ln
# metería el enlace dentro en vez de sustituirla: se aparta antes a una copia. Lo que
# guarda Quickshell (tema, fondo, medidas...) no vive aquí sino en
# ~/.local/state/quickshell, así que no se pierde.
if [[ -d ~/.config/quickshell && ! -L ~/.config/quickshell ]]; then
    backup=~/.config/quickshell.bak-$(date +%Y%m%d-%H%M%S)
    mv ~/.config/quickshell "$backup"
    echo "Aviso: ~/.config/quickshell era una carpeta propia, movida a $backup"
fi
link "$DOTS/quickshell"                      ~/.config/quickshell   # Incluye scripts/ (los que lanza la barra)
for file in "$DOTS"/hypr/*; do link "$file"  ~/.config/hypr/"${file##*/}"; done
link "$DOTS/apps/fish/config.fish"           ~/.config/fish/config.fish
link "$DOTS/apps/alacritty/alacritty.toml"   ~/.config/alacritty/alacritty.toml
link "$DOTS/apps/fastfetch/config.jsonc"     ~/.config/fastfetch/config.jsonc
link "$DOTS/apps/vscode/settings.json"       ~/.config/Code/User/settings.json  # Ajustes de Visual Studio Code

# Restos de una config de Hyprland anterior (la que trae CachyOS, o archivos que
# ya no están en el repo): se apartan a una copia para que no se mezclen con la
# de verdad. Se queda lo que es un enlace (lo de arriba) y lo que genera
# Quickshell fuera del repo (ver hypr/hyprland.lua); todo lo demás se mueve.
mapfile -t restos < <(find ~/.config/hypr -mindepth 1 -maxdepth 1 ! -type l \
    ! -name shellOverrides.lua ! -name shellTheme.lua)
if (( ${#restos[@]} )); then
    backup=~/.config/hypr.bak-$(date +%Y%m%d-%H%M%S)
    mkdir -p "$backup"
    mv "${restos[@]}" "$backup"/
    echo "Aviso: ~/.config/hypr tenía restos de otra config, movidos a $backup"
fi

# Los fondos van a la carpeta de imágenes del sistema (~/Imágenes en español), la misma
# que las capturas de pantalla. xdg-user-dirs-update la crea si aún no existe.
xdg-user-dirs-update
link "$DOTS/wallpapers" "$(xdg-user-dir PICTURES)/Wallpapers"

# Solo si se ha lanzado directamente: cargado desde install.sh, aún queda su parte. Con if
# y no con "[[ ]] && ...": con source, un último comando que falla cortaría install.sh (set -e)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Listo"
fi
