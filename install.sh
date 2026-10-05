#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
DOTS="$PWD" # Guardo la ruta en una variable para no acceder todo el rato

# Los nombres de una de las listas del repo (packages.txt, packages_opt.txt),
# uno por línea: sin comentarios (lo que va tras #), sin líneas vacías y sin espacios
listFile() { sed 's/#.*//' "$1" | awk 'NF { print $1 }'; }

echo "Instalando"

sudo pacman -S --needed  --noconfirm paru   # El descargador de paquetes (aquí y no en packages.txt: hace falta ya para el "paru -Syu" de abajo)

echo "Actualizando el sistema"

paru -Syu --noconfirm   # Actualiza el sistema por completo antes de instalar (repos oficiales + AUR)


echo "Instalando paquetes (via pacman)"

listFile packages.txt | xargs -r sudo pacman -S --needed  --noconfirm

echo "Instalando paquetes (via paru)"

paru -S --needed --noconfirm visual-studio-code-bin   # Visual code
paru -S --needed --noconfirm claude-desktop           # Claude
paru -S --needed --noconfirm google-chrome            # Chrome
paru -S --needed --noconfirm zen-browser-bin          # Zen

echo "Paquetes opcionales"

# Los de packages_opt.txt que aún no están instalados: los que ya están no se preguntan
# (ni se reinstalan), así que al actualizar con update-reddots.sh solo se pregunta por los que faltan
optional=()
while read -r pkg; do
    pacman -Qq "$pkg" &>/dev/null || optional+=("$pkg")
done < <(listFile packages_opt.txt)

chosen=()   # Los que se van a instalar
if (( ${#optional[@]} == 0 )); then
    echo "Todos los opcionales están ya instalados"
elif [[ ! -t 0 ]]; then
    # Sin terminal (lanzado desde otro script sin entrada) read no puede preguntar y,
    # con set -e, cortaría la instalación: se sigue sin instalar ninguno
    echo "Sin terminal para preguntar: no se instala ninguno (${optional[*]})"
else
    echo "Sin instalar: ${optional[*]}"
    while true; do      # Se repite hasta una respuesta válida; Intro a secas = ninguno, como el [s/N] de abajo
        read -r -p "¿Instalarlos? [t]odos, [N]inguno o [u]no a uno: " mode
        case "$mode" in
            [tT]) chosen=("${optional[@]}"); break ;;
            [nN]|"") break ;;
            [uU])
                for pkg in "${optional[@]}"; do
                    read -r -p "¿Instalar $pkg? [s/N] " answer
                    # Con if y no con "[[ ]] && ...": con set -e, un "no" en el último paquete
                    # dejaría el bucle con código 1 y cortaría el script
                    if [[ "$answer" =~ ^[sS]$ ]]; then chosen+=("$pkg"); fi
                done
                break ;;
            *) echo "Responde t, n o u" ;;
        esac
    done
fi

# Con paru y no con pacman: así un opcional puede ser tanto de los repos como de AUR
if (( ${#chosen[@]} > 0 )); then
    paru -S --needed --noconfirm "${chosen[@]}"
fi

echo "Paquetes no utilizados"

# pacman -Qq comprueba si existe; si no está, la parte de la derecha no se ejecuta y el script sigue como si nada.
pacman -Qq dolphin &>/dev/null && sudo pacman -Rns --noconfirm dolphin || true     # Quito Dolphin porque instalo Nemo como explorador de archivos
pacman -Qq kitty &>/dev/null && sudo pacman -Rns --noconfirm kitty || true         # Quito Kitty porque uso Alacritty como terminal
pacman -Qq meld &>/dev/null && sudo pacman -Rns --noconfirm meld || true           # Quito Meld porque no lo uso
pacman -Qq firefox &>/dev/null && sudo pacman -Rns --noconfirm firefox || true     # Quito firefox porque instalo chrome y zen
pacman -Qq hyprpaper &>/dev/null && sudo pacman -Rns --noconfirm hyprpaper || true # Quito hyprpaper porque el fondo lo pinta Quickshell (quickshell/windows/Background.qml)
pacman -Qq polkit-gnome &>/dev/null && sudo pacman -Rns --noconfirm polkit-gnome || true # Quito polkit-gnome: otro agente de polkit, y el que se usa es el de Quickshell (quickshell/windows/PolkitDialog.qml)


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

mkdir -p ~/.config/hypr ~/.config/fish ~/.config/alacritty ~/.config/fastfetch ~/.config/Code/User # Creo las carpetas si no existen

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
ln -sfn "$DOTS/quickshell"                 ~/.config/quickshell   # Incluye scripts/ (los que lanza la barra)
ln -sfn "$DOTS"/hypr/*                     ~/.config/hypr/
ln -sfn "$DOTS/apps/fish/config.fish"           ~/.config/fish/config.fish
ln -sfn "$DOTS/apps/alacritty/alacritty.toml"   ~/.config/alacritty/alacritty.toml
ln -sfn "$DOTS/apps/fastfetch/config.jsonc"     ~/.config/fastfetch/config.jsonc
ln -sfn "$DOTS/apps/vscode/settings.json"       ~/.config/Code/User/settings.json  # Ajustes de Visual Studio Code

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
pictures="$(xdg-user-dir PICTURES)"
mkdir -p "$pictures"
ln -sfn "$DOTS/wallpapers"   "$pictures/Wallpapers"

echo "Apps ocultas del launcher"

# Antes las ocultaba este script (lista hidden_apps.txt) con un .desktop mínimo con
# NoDisplay=true en ~/.local/share/applications. Ahora se eligen con la rueda del propio
# launcher y se guardan en su launcher.json (ver quickshell/windows/Launcher.qml).
# Migración (se puede quitar cuando todos los equipos hayan pasado por aquí): las que
# estaban ocultas así pasan a la lista del launcher y se borran esos .desktop. Solo los
# que son exactamente uno de aquellos (ningún .desktop de verdad es así, sin Exec), nunca
# otro .desktop que haya en esa carpeta.
apps="$HOME/.local/share/applications"
hiddenDesktop() { printf '[Desktop Entry]\nType=Application\nName=%s\nNoDisplay=true\n' "$1"; }

migrated=()
for file in "$apps"/*.desktop; do
    app="$(basename "$file" .desktop)"
    [[ -f "$file" && "$(< "$file")" == "$(hiddenDesktop "$app")" ]] && migrated+=("$app")
done

# launcher.json está en la carpeta de estado de Quickshell, en una subcarpeta con un hash de
# la ruta de la config: se busca en vez de calcularlo. Si aún no existe (nunca se ha abierto
# nada desde el launcher), los .desktop se dejan: borrarlos haría que volvieran a salir.
states=(~/.local/state/quickshell/by-shell/*/launcher.json)
if (( ${#migrated[@]} )) && [[ -f "${states[0]}" ]]; then
    ids="$(printf '%s\n' "${migrated[@]}" | jq -R . | jq -s .)"
    for state in "${states[@]}"; do
        # Se reescribe el mismo archivo (cat >, no mv): Quickshell lo está vigilando y, si
        # se cambiara por otro, dejaría de ver los cambios y luego lo pisaría sin "hidden"
        merged="$(jq --argjson ids "$ids" '.hidden = ((.hidden // []) + $ids | unique)' "$state")"
        printf '%s\n' "$merged" > "$state"
    done
    for app in "${migrated[@]}"; do rm "$apps/$app.desktop"; done
    echo "Pasadas a la lista del launcher: ${migrated[*]}"
fi

echo "Otras configuraciones"

# Extensiones de Visual Studio Code, todas en una sola llamada a "code" (cada una tarda en
# arrancar). No hace falta mirar antes si ya están: las que lo están solo dan un aviso
# ("already installed") y no se reinstalan ni se actualizan.
vscodeExtensions=(
    bbenoist.QML                # QML
    James-Yu.latex-workshop     # LaTeX
    ms-python.python            # Python
)
vscodeArgs=()
for ext in "${vscodeExtensions[@]}"; do vscodeArgs+=(--install-extension "$ext"); done
code "${vscodeArgs[@]}"

echo "Reloj (dual boot con Windows)"

# Windows guarda el RTC en hora local; Linux por defecto lo asume en UTC.
# Si no está ya puesto en local, lo activamos para que no se descuadre la hora al alternar entre los dos.
if [[ "$(timedatectl show -p LocalRTC --value)" != "yes" ]]; then
    sudo timedatectl set-local-rtc 1 --adjust-system-clock
fi

echo "Listo"
