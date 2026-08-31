#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
DOTS="$PWD" # Guardo la ruta en una variable para no acceder todo el rato

echo "Instalando"

echo "Actualizando el sistema"

sudo pacman -Syu # Actualiza el sistema por completo antes de instalar

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

paru -S --needed visual-studio-code-bin   # Visual code
paru -S --needed claude-desktop           # Claude

echo "Paquetes no utilizados"

# pacman -Qq comprueba si existe; si no está, la parte de la derecha no se ejecuta y el script sigue como si nada.
sudo pacman -Qq dolphin &>/dev/null && sudo pacman -Rns --noconfirm dolphin || true     # Quito Dolphin porque instalo Nemo como explorador de archivos
sudo pacman -Qq kitty &>/dev/null && sudo pacman -Rns --noconfirm kitty || true         # Quito Kitty porque uso Alacritty como terminal
sudo pacman -Qq meld &>/dev/null && sudo pacman -Rns --noconfirm meld || true           # Quito Meld porque no lo uso

echo "Sistema de archivos"

mkdir -p ~/.config/quickshell ~/.config/hypr ~/.config/fish ~/.config/alacritty # Creo las carpetas si no existen

ln -sfn "$DOTS"/quickshell/*.qml           ~/.config/quickshell/
ln -sfn "$DOTS"/hypr/*                     ~/.config/hypr/
ln -sfn "$DOTS/fish/config.fish"           ~/.config/fish/config.fish
ln -sfn "$DOTS/alacritty/alacritty.toml"   ~/.config/alacritty/alacritty.toml

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

code --install-extension bbenoist.QML                                       # Extensión para QML en Visual Studio Code
sudo pacman -S --needed texlive-core texlive-latexextra texlive-binextra    # Paquetes necesarios de LaTeX
code --install-extension James-Yu.latex-workshop                            # Extensión para LaTeX en Visual Studio Code

# No he encontrado una forma mejor de evitar el problema del cambio de hora
#timedatectl set-local-rtc 1 --adjust-system-clock # Para que el reloj no se cambie cada vez que arranca windows

echo "Listo"
