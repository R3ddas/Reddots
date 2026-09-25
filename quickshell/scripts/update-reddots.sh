#!/usr/bin/env bash
# Lo lanza el botón de actualizar de la barra (Install.qml) dentro de un Alacritty:
# baja los cambios del repo y ejecuta install.sh. Va en un terminal porque install.sh
# pide la contraseña con sudo y paru -Syu puede hacer preguntas.

# La carpeta del repo se saca de dónde está este script (Reddots/quickshell/scripts),
# siguiendo el enlace de ~/.config/quickshell: así vale esté donde esté el repo.
repo="$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")"
cd "$repo" || { echo "No se encuentra el repo"; exec "${SHELL:-bash}"; }

echo "Repo: $repo"
echo
echo "Bajando cambios (git pull)"

# --ff-only: si hay cambios locales que chocan o las ramas han divergido, no mezcla
# nada y falla sin tocar el repo; en ese caso se sigue con lo que hay.
git pull --ff-only || echo "Aviso: no se ha podido hacer git pull, se instala lo que hay ahora en el repo"
echo

./install.sh
code=$?     # Se guarda ya: cualquier comando posterior (hasta un echo) lo sobrescribe
echo
if (( code == 0 )); then
    echo "Instalación terminada"
else
    echo "install.sh ha fallado (código $code): revisa los mensajes de arriba"
fi

# El terminal no se cierra al terminar: se queda con tu shell abierta en el repo,
# para poder revisar la salida o seguir trabajando. Se cierra como cualquier otro.
echo
exec "${SHELL:-bash}"
