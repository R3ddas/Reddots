#!/usr/bin/env bash
# Lo lanza el botón de actualizar de la barra (Reddots.qml) dentro de un Alacritty:
# baja los cambios del repo, ejecuta install.sh y, si el pull ha traído algo, reinicia
# Quickshell y/o recarga Hyprland. Va en un terminal porque install.sh pide la
# contraseña con sudo y paru -Syu puede hacer preguntas.
#
# Mientras git escribe los archivos, ni Quickshell ni Hyprland deben estar mirándolos:
# git no reescribe un archivo por encima, lo borra y lo crea de nuevo, y en ese hueco
# el archivo no existe. Los dos vigilan su configuración y se recargan solos al verla
# cambiar, así que podían recargarse a medias: Hyprland sacaba la barra roja de
# "cannot open .../hyprland.lua" y Quickshell se quedaba con la barra rota ("Theme is
# not defined") hasta el final del script, después de install.sh. Por eso, antes de
# bajar los cambios, se cierra Quickshell y se pausa la recarga automática de Hyprland,
# solo si el pull va a tocar sus archivos.

# La carpeta del repo se saca de dónde está este script (Reddots/quickshell/scripts),
# siguiendo el enlace de ~/.config/quickshell: así vale esté donde esté el repo.
repo="$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")"
cd "$repo" || { echo "No se encuentra el repo"; exec "${SHELL:-bash}"; }

echo "Repo: $repo"
echo
echo "Bajando cambios (git pull)"

# El "git pull" va en dos pasos (fetch + merge, que es lo mismo que hace él por dentro)
# para saber qué archivos va a cambiar ANTES de escribirlos, y así preparar solo lo
# que haga falta. El fetch solo baja los cambios a .git: no toca los archivos del repo.
git fetch || echo "Aviso: no se ha podido hacer git fetch (¿sin red?)"
# Archivos que traerá el merge: los que han cambiado en el remoto (@{u}) desde el punto
# en que se separó de la copia local (los tres puntos). Vacío si no hay nada nuevo.
incoming=$(git diff --name-only 'HEAD...@{u}' 2>/dev/null)

# Quickshell no tiene forma de dejar de vigilar sus archivos, así que se cierra mientras
# se escriben (la barra desaparece unos segundos) y se vuelve a lanzar justo después.
# Este terminal no se cierra con él: la barra lo lanzó como proceso aparte (execDetached).
shellStopped=false
if grep -q '^quickshell/' <<< "$incoming"; then
    echo "Cerrando Quickshell mientras se escriben los archivos de la barra"
    qs kill >/dev/null
    shellStopped=true
fi

# A Hyprland basta con pausarle la recarga automática. Se vuelve a activar sola con el
# "hyprctl reload" del final (hyprland.lua no pone disable_autoreload, así que vuelve a
# false); hasta entonces sigue en pausa también durante install.sh, que puede crear
# enlaces nuevos en ~/.config/hypr que hyprland.lua necesite (un require() nuevo).
autoreloadPaused=false
if grep -q '^hypr/' <<< "$incoming"; then
    hyprctl eval 'hl.config({ misc = { disable_autoreload = true } })' >/dev/null
    autoreloadPaused=true
fi

# --ff-only: si hay cambios locales que chocan o las ramas han divergido, no mezcla
# nada y falla sin tocar el repo; en ese caso se sigue con lo que hay.
before=$(git rev-parse HEAD)
git merge --ff-only '@{u}' || echo "Aviso: no se ha podido hacer git pull, se instala lo que hay ahora en el repo"
after=$(git rev-parse HEAD)
changed=$(git diff --name-only "$before" "$after")    # Archivos que ha traído el pull (vacío si no ha traído nada)

# Quickshell vuelve ya, sin esperar a install.sh (que con paru -Syu puede tardar
# minutos): toda la carpeta quickshell/ está enlazada, así que no le hace falta nada
# de install.sh para ver los archivos nuevos. Se relanza aunque el merge haya fallado,
# porque se cerró antes. Desde Hyprland, para que no dependa de este terminal.
if $shellStopped; then
    echo "Volviendo a lanzar Quickshell"
    sleep 0.5       # Como antes: por si el merge ha sido tan rápido que el Quickshell viejo aún no ha terminado de cerrarse
    hyprctl dispatch 'hl.dsp.exec_cmd("quickshell")' >/dev/null
fi
echo

./install.sh
code=$?     # Se guarda ya: cualquier comando posterior (hasta un echo) lo sobrescribe
echo
if (( code == 0 )); then
    echo "Instalación terminada"
else
    echo "install.sh ha fallado (código $code): revisa los mensajes de arriba"
fi

# Aplicar a Hyprland lo que ha traído el pull, ahora que install.sh ya ha creado los
# enlaces nuevos. Se hace aunque install.sh haya fallado, porque el repo ya ha cambiado.
# (Quickshell ya se relanzó justo después del pull, más arriba.)
if grep -q '^hypr/' <<< "$changed"; then
    echo
    echo "Recargando Hyprland (han cambiado archivos de hypr/)"
    # Ojo: el reload vuelve a aplicar hyprland.lua entero, así que deshace el mirror
    # de Super+M y, con la tapa cerrada, probablemente vuelva a encender el panel del portátil.
    # También reactiva la recarga automática que se pausó antes del pull.
    hyprctl reload >/dev/null
elif $autoreloadPaused; then
    # Se pausó pero el merge falló (no ha cambiado nada): no hace falta recargar,
    # solo volver a activar la recarga automática
    hyprctl eval 'hl.config({ misc = { disable_autoreload = false } })' >/dev/null
fi

# Que el contador de actualizaciones de la barra (Updates.qml) vuelva a mirar, ahora
# que ya se ha actualizado. Si Quickshell se acaba de reiniciar, ya mirará cuando se despliegue el engranaje.
qs ipc call updates refresh >/dev/null 2>&1

# El terminal no se cierra al terminar: se queda con tu shell abierta en el repo,
# para poder revisar la salida o seguir trabajando. Se cierra como cualquier otro.
echo
exec "${SHELL:-bash}"
