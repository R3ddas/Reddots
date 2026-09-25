#!/usr/bin/env bash
# Lo lanza el botón de actualizar de la barra (Reddots.qml) dentro de un Alacritty:
# baja los cambios del repo, ejecuta install.sh y, si el pull ha traído algo, reinicia
# Quickshell y/o recarga Hyprland. Va en un terminal porque install.sh pide la
# contraseña con sudo y paru -Syu puede hacer preguntas.

# La carpeta del repo se saca de dónde está este script (Reddots/quickshell/scripts),
# siguiendo el enlace de ~/.config/quickshell: así vale esté donde esté el repo.
repo="$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")"
cd "$repo" || { echo "No se encuentra el repo"; exec "${SHELL:-bash}"; }

echo "Repo: $repo"
echo
echo "Bajando cambios (git pull)"

# --ff-only: si hay cambios locales que chocan o las ramas han divergido, no mezcla
# nada y falla sin tocar el repo; en ese caso se sigue con lo que hay.
before=$(git rev-parse HEAD)
git pull --ff-only || echo "Aviso: no se ha podido hacer git pull, se instala lo que hay ahora en el repo"
after=$(git rev-parse HEAD)
changed=$(git diff --name-only "$before" "$after")    # Archivos que ha traído el pull (vacío si no ha traído nada)
echo

./install.sh
code=$?     # Se guarda ya: cualquier comando posterior (hasta un echo) lo sobrescribe
echo
if (( code == 0 )); then
    echo "Instalación terminada"
else
    echo "install.sh ha fallado (código $code): revisa los mensajes de arriba"
fi

# Aplicar lo que ha traído el pull. Ni Quickshell ni Hyprland lo ven solos: vigilan
# los enlaces de ~/.config y pierden de vista su destino cuando git reescribe los
# archivos del repo. Se hace aunque install.sh haya fallado, porque el repo ya ha cambiado.
if grep -q '^quickshell/' <<< "$changed"; then
    echo
    echo "Reiniciando Quickshell (han cambiado archivos de la barra)"
    # Este terminal no se cierra con él: la barra lo lanzó como proceso aparte.
    # El nuevo se lanza desde Hyprland para que tampoco dependa de este terminal.
    qs kill >/dev/null
    sleep 0.5
    hyprctl dispatch 'hl.dsp.exec_cmd("quickshell")' >/dev/null
fi
if grep -q '^hypr/' <<< "$changed"; then
    echo
    echo "Recargando Hyprland (han cambiado archivos de hypr/)"
    # Ojo: el reload vuelve a aplicar hyprland.lua entero, así que deshace el mirror
    # de Super+M y, con la tapa cerrada, probablemente vuelva a encender el panel del portátil.
    hyprctl reload >/dev/null
fi

# El terminal no se cierra al terminar: se queda con tu shell abierta en el repo,
# para poder revisar la salida o seguir trabajando. Se cierra como cualquier otro.
echo
exec "${SHELL:-bash}"
