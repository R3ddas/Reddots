#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
DOTS="$PWD" # Guardo la ruta en una variable para no acceder todo el rato

# Los nombres de una de las listas del repo (packages.txt, packages_opt.txt),
# uno por línea: sin comentarios (lo que va tras #), sin líneas vacías y sin espacios
listFile() { sed 's/#.*//' "$1" | awk 'NF { print $1 }'; }

echo "Instalando"

sudo pacman -S --needed  --noconfirm paru   # El descargador de paquetes (aquí y no en packages.txt: hace falta ya para instalarlo y para el "paru -Syu" de abajo)

echo "Actualizando el sistema"

paru -Syu --noconfirm   # Actualiza el sistema por completo antes de instalar (repos oficiales + AUR)


echo "Instalando paquetes"

# Con paru y no con pacman: así packages.txt puede tener tanto paquetes de los repos como de
# AUR (los de los repos, paru se los pasa a pacman). En una sola llamada y no con xargs, para
# que paru siga teniendo el terminal (sudo pide ahí la contraseña al instalar los de AUR)
mapfile -t packages < <(listFile packages.txt)
paru -S --needed --noconfirm "${packages[@]}"

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

echo "Inicio de sesión"

# No hay gestor de inicio de sesión (SDDM, GDM...): en la TTY1 se entra solo, sin pedir
# usuario ni contraseña, y apps/fish/config.fish arranca Hyprland con la pantalla ya
# bloqueada. La contraseña la pide el bloqueo de Quickshell (quickshell/windows/Lock.qml),
# así que el inicio de sesión tiene el mismo fondo y los mismos colores que el escritorio.
# Ojo: la sesión arranca un instante antes de que aparezca el bloqueo (y el disco no va
# cifrado), así que esto protege igual que un bloqueo de pantalla, no más.
#
# Con la credencial agetty.autologin (agetty la lee desde util-linux 2.40) y no cambiando
# el ExecStart de getty@.service: así no se copia la línea de agetty, que cambia entre
# versiones de systemd. Para volver a pedir usuario y contraseña en la TTY, basta con
# borrar este archivo (y "sudo systemctl daemon-reload").
# Solo se aplica en el siguiente arranque: reiniciar ahora getty@tty1 cerraría la sesión,
# que vive en esa misma TTY.
autologinConf=/etc/systemd/system/getty@tty1.service.d/autologin.conf
autologinText="[Service]
SetCredential=agetty.autologin:$USER"
if [[ "$(cat "$autologinConf" 2>/dev/null)" != "$autologinText" ]]; then
    sudo mkdir -p "$(dirname "$autologinConf")"
    printf '%s\n' "$autologinText" | sudo tee "$autologinConf" > /dev/null
    sudo systemctl daemon-reload
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

echo "Arranque sin texto"

# "quiet" en la línea del kernel, junto al "splash" de Plymouth: así tampoco salen los
# mensajes del kernel ni los "[ OK ] Started…" de systemd en los momentos en que Plymouth
# no tapa la pantalla (antes de que arranque y al cerrarse, justo antes del login). Es solo
# estético, no acelera el arranque, y vale para cualquier equipo y gráfica.
# Solo si el equipo arranca con GRUB (otro gestor de arranque tiene su propia config), y
# grub.cfg solo se regenera si "quiet" no estaba ya: el resto de veces no se toca nada.
grubConf=/etc/default/grub
if [[ -f "$grubConf" ]] && ! grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT=.*\bquiet\b' "$grubConf"; then
    # Se añade al final, dentro de las comillas (simples o dobles) que cierran el valor
    sudo sed -i -E "/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/(['\"])\$/ quiet\1/" "$grubConf"
    if grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT=.*\bquiet\b' "$grubConf"; then
        sudo grub-mkconfig -o /boot/grub/grub.cfg
    else
        echo "Aviso: no se pudo añadir quiet a GRUB_CMDLINE_LINUX_DEFAULT en $grubConf (¿sin comillas?)"
    fi
fi

echo "Listo"
