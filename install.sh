#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
DOTS="$PWD" # Guardo la ruta en una variable para no acceder todo el rato

echo "Instalando"

#sudo cachyos-rate-mirrors                   # Actualizo la lista de servidores
sudo pacman -S --needed  --noconfirm paru   # El descargador de paquetes

echo "Actualizando el sistema"

# Si la actuialización falla por alguna dependencia de toolkit, puede arreglarse consudo pacman -Syu extra/hyprtoolkit
# Esto fuerza a que tanto hyprland como hyprtoolkit se saquen del repositorio "extra"

paru -Syu           # Actualiza el sistema por completo antes de instalar (repos oficiales + AUR)


echo "Instalando paquetes (via pacman)"

sed 's/#.*//' packages.txt | grep -v '^\s*$' \
| xargs -r sudo pacman -S --needed  --noconfirm

#Si quisiera separar Steam (o cualquier otro paquete)
#echo "Steam"
#sed 's/#.*//' packages.txt | grep -v '^\s*$' | grep -vw 'steam' \
#| xargs -r sudo pacman -S --needed --noconfirm
#read -r -p "¿Instalar steam? [s/N] " respuesta
#if [[ "$respuesta" =~ ^[sS]$ ]]; then
#    sudo pacman -S --needed steam
#fi

echo "Instalando paquetes (via paru)"

paru -S --needed --noconfirm visual-studio-code-bin   # Visual code
paru -S --needed --noconfirm claude-desktop           # Claude
paru -S --needed --noconfirm google-chrome            # Chrome
paru -S --needed --noconfirm zen-browser-bin          # Zen

echo "Paquetes no utilizados"

# pacman -Qq comprueba si existe; si no está, la parte de la derecha no se ejecuta y el script sigue como si nada.
pacman -Qq dolphin &>/dev/null && sudo pacman -Rns --noconfirm dolphin || true     # Quito Dolphin porque instalo Nemo como explorador de archivos
pacman -Qq kitty &>/dev/null && sudo pacman -Rns --noconfirm kitty || true         # Quito Kitty porque uso Alacritty como terminal
pacman -Qq meld &>/dev/null && sudo pacman -Rns --noconfirm meld || true           # Quito Meld porque no lo uso
pacman -Qq firefox &>/dev/null && sudo pacman -Rns --noconfirm firefox || true     # Quito firefox porque instalo chrome y zen


echo "Sistema de archivos"

mkdir -p ~/.config/hypr ~/.config/fish ~/.config/alacritty ~/.config/fastfetch ~/.config/Code/User # Creo las carpetas si no existen

# Quickshell se enlaza como carpeta entera (no archivo a archivo) para que los
# widgets nuevos que se añadan al repo aparezcan solos, sin volver a ejecutar esto.
# Si ya existe como carpeta de verdad (instalaciones anteriores enlazaban archivo
# a archivo), se quita antes: si solo tiene enlaces se borra, y si tiene algo más
# se aparta a una copia por si acaso. Lo que guarda Quickshell (tema, fondo,
# medidas...) no vive aquí sino en ~/.local/state/quickshell, así que no se pierde.
if [[ -d ~/.config/quickshell && ! -L ~/.config/quickshell ]]; then
    if [[ -z "$(find ~/.config/quickshell -mindepth 1 -maxdepth 1 ! -type l)" ]]; then   # Solo contiene enlaces
        rm -r ~/.config/quickshell
    else
        backup=~/.config/quickshell.bak-$(date +%Y%m%d-%H%M%S)
        mv ~/.config/quickshell "$backup"
        echo "Aviso: ~/.config/quickshell tenía archivos propios, movidos a $backup"
    fi
fi
ln -sfn "$DOTS/quickshell"                 ~/.config/quickshell   # Incluye scripts/ (usado por Theme.qml para sincronizar Alacritty)
ln -sfn "$DOTS"/hypr/*                     ~/.config/hypr/
ln -sfn "$DOTS/fish/config.fish"           ~/.config/fish/config.fish
ln -sfn "$DOTS/alacritty/alacritty.toml"   ~/.config/alacritty/alacritty.toml
ln -sfn "$DOTS/fastfetch/config.jsonc"     ~/.config/fastfetch/config.jsonc
ln -sfn "$DOTS/vscode/settings.json"       ~/.config/Code/User/settings.json  # Ajustes de Visual Studio Code

mkdir -p ~/Pictures
ln -sfn "$DOTS/Wallpapers"   ~/Pictures/Wallpapers

echo "Escondiendo aplicaciones del launcher"

mkdir -p ~/.local/share/applications

sed 's/#.*//' hidden_apps.txt | grep -v '^\s*$' | while read -r app; do
    src="/usr/share/applications/$app.desktop"
    dest="$HOME/.local/share/applications/$app.desktop"
    if [[ -f "$src" ]]; then
        cp -f "$src" "$dest"
        grep -q '^NoDisplay=' "$dest" \
            && sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$dest" \
            || echo "NoDisplay=true" >> "$dest"
    else
        echo "Aviso: no se encontró $src, se omite $app"
    fi
done

echo "Otras configuraciones"

code --list-extensions | grep -qi '^bbenoist.QML$' \
    || code --install-extension bbenoist.QML                                # Extensión para QML en Visual Studio Code
sudo pacman -S --needed --noconfirm texlive-core texlive-latexextra texlive-binextra    # Paquetes necesarios de LaTeX
code --list-extensions | grep -qi '^James-Yu.latex-workshop$' \
    || code --install-extension James-Yu.latex-workshop                     # Extensión para LaTeX en Visual Studio Code

echo "Reloj (dual boot con Windows)"

# Windows guarda el RTC en hora local; Linux por defecto lo asume en UTC.
# Si no está ya puesto en local, lo activamos para que no se descuadre la hora al alternar entre los dos.
if [[ "$(timedatectl show -p LocalRTC --value)" != "yes" ]]; then
    sudo timedatectl set-local-rtc 1 --adjust-system-clock
fi

echo "Listo"
