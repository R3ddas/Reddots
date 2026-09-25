#!/bin/bash
# Apaga el panel del portátil al cerrar la tapa, para que todo se vuelque al
# monitor externo con su resolución nativa; lo reactiva al abrirla.
#
# systemd-logind ya no suspende el equipo al cerrar la tapa mientras haya un
# monitor externo conectado (queda "Docked", ver HandleLidSwitchDocked=ignore
# en logind.conf, que es el valor por defecto), pero SIN monitor externo sí
# suspende por defecto (HandleLidSwitch=suspend). Para que este script mande
# siempre, sin tocar /etc/systemd/logind.conf, nos reejecutamos bajo un
# inhibitor lock de tipo "handle-lid-switch" en modo "block": eso le dice a
# logind que no actúe él solo al cerrar la tapa (ni suspenda ni nada), pero
# la señal LidClosed nos sigue llegando igual más abajo. Los inhibitor locks
# de este tipo no piden contraseña para un usuario con sesión activa.
if [ -z "${LID_WATCHER_INHIBITED:-}" ]; then
    export LID_WATCHER_INHIBITED=1
    exec systemd-inhibit --what=handle-lid-switch --mode=block \
        --who="Reddots lid-watcher" \
        --why="El script apaga el panel a mano, no queremos que logind suspenda" \
        "$0" "$@"
fi
#
# No hace falta reiniciar quickshell tras cada cambio: shell.qml envuelve sus
# ventanas en un Variants atado a la pantalla del portátil, así que se
# destruyen y recrean solas cuando esa pantalla desaparece/vuelve.

# Nombre del panel interno ("eDP-1"...), una sola vez: el equipo no cambia de panel.
# Lo averigua internal-panel.sh, el mismo que usan hypr/monitors.lua y la barra.
output=$(bash "$(dirname "$0")/internal-panel.sh")
[ -z "$output" ] && exit 0   # No hay panel interno en esta máquina (sobremesa): nada que vigilar

apply_state() {
    local lid
    lid=$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
        org.freedesktop.login1.Manager LidClosed 2>/dev/null | awk '{print $2}')

    if [ "$lid" = "true" ]; then
        hyprctl eval "hl.monitor({ output = \"$output\", disabled = true })" >/dev/null 2>&1
    else
        hyprctl eval "hl.monitor({ output = \"$output\", disabled = false, mode = \"highres\", position = \"0x0\", scale = \"1\" })" >/dev/null 2>&1   # Los mismos valores que la regla del panel en hypr/hyprland.lua
    fi
}

# Sincroniza el estado al arrancar, por si Hyprland se lanza con la tapa ya cerrada
apply_state

dbus-monitor --system \
    "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='/org/freedesktop/login1'" 2>/dev/null |
while read -r line; do
    case "$line" in
        *LidClosed*) apply_state ;;
    esac
done
