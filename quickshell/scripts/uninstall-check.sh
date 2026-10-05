#!/usr/bin/env bash
# Antes de desinstalar una app desde el launcher (windows/Launcher.qml): de qué paquete es
# y qué pasaría al quitarlo. Recibe el id del .desktop ("btop", "org.kde.kwrite"...) y
# saca una línea por dato:
#   id|<id>                     el mismo que recibe: si se pide otra mientras tanto, para no
#                               confundir la respuesta de una con la de otra
#   pkg|<paquete>               el paquete de pacman que instala la app
#   remove|<paquete>            lo que se quitaría con él (él mismo y las dependencias que ya
#                               no necesita nadie), uno por línea
#   app|<id>                    otros .desktop del mismo paquete, que también desaparecen
#   repo|<archivo>              lo instala el repo (packages.txt, packages_opt.txt o install.sh):
#                               al volver a pasar install.sh volvería
#   blocked|<paquete>           otro paquete lo necesita: pacman no deja quitarlo, uno por línea
#   error|<mensaje>             no se puede ni mirar (no hay .desktop, no es de ningún paquete...)
# No cambia nada ni pide contraseña: "pacman -Rsp" solo simula la desinstalación.

id="$1"
export LC_ALL=C     # Los mensajes de pacman en inglés, para poder buscar "required by"
echo "id|$id"

# --- El .desktop y su paquete ---
# Quickshell no dice de qué archivo sale cada app: se busca igual que él, en las carpetas
# de aplicaciones de XDG. Puede haber varios con el mismo nombre (uno en ~/.local que tapa
# al del sistema): vale el primero que sea de un paquete.
pkg=""
IFS=: read -ra dirs <<< "${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
for dir in "${dirs[@]}"; do
    file="$dir/applications/$id.desktop"
    [[ -f "$file" ]] && pkg="$(pacman -Qqo "$file" 2>/dev/null)" && break
done
if [[ -z "$pkg" ]]; then
    # Las que no son de ningún paquete las ha puesto otra app o se han hecho a mano (las de
    # ~/.local/share/applications): no hay nada que desinstalar con pacman
    echo "error|No es de ningún paquete de pacman: no se puede desinstalar desde aquí"
    exit 0
fi
echo "pkg|$pkg"

# --- ¿Lo instala el repo? ---
# La carpeta de Quickshell es un enlace al repo (lo crea install.sh): siguiéndolo se llega
# a las listas de paquetes, dos carpetas por encima de este script
dots="$(dirname "$(realpath "$0")")/../.."
listFile() { sed 's/#.*//' "$1" | awk 'NF { print $1 }'; }     # Igual que en install.sh
listFile "$dots/packages.txt"     | grep -qxF "$pkg" && echo "repo|packages.txt"
listFile "$dots/packages_opt.txt" | grep -qxF "$pkg" && echo "repo|packages_opt.txt"
# Los de AUR van uno por línea en install.sh: "paru -S --needed --noconfirm <paquete>"
sed 's/#.*//' "$dots/install.sh" | awk '$1 == "paru" && $2 == "-S" { print $NF }' \
    | grep -qxF "$pkg" && echo "repo|install.sh"

# --- Otras apps del mismo paquete ---
# Al quitar el paquete se van todas (qv4l2 y qvidcap son los dos de v4l-utils)
pacman -Qlq "$pkg" | grep -E '/applications/[^/]+\.desktop$' | while read -r f; do
    other="$(basename "$f" .desktop)"
    [[ "$other" != "$id" ]] && echo "app|$other"
done

# --- Simulación ---
# -Rsp: qué se quitaría (con -s, también las dependencias que se quedan sin uso) sin quitar
# nada. Si otro paquete lo necesita, pacman se niega y dice quién:
#   ":: removing vim breaks dependency 'vim' required by cachyos-zsh-config"
if out="$(pacman -Rsp --print-format '%n' "$pkg" 2>&1)"; then
    sed 's/^/remove|/' <<< "$out"
elif grep -q 'required by' <<< "$out"; then
    grep -o 'required by .*' <<< "$out" | awk '{ print "blocked|" $3 }' | sort -u
else
    # Ha fallado por otra cosa (la base de datos bloqueada porque otro pacman está en marcha...):
    # se enseña lo último que ha dicho
    echo "error|pacman: $(tail -n 1 <<< "$out")"
fi
exit 0
