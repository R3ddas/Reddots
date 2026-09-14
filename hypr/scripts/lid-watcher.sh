#!/bin/bash
# Apaga el panel del portátil al cerrar la tapa, para que todo se vuelque al
# monitor externo con su resolución nativa; lo reactiva al abrirla.
#
# systemd-logind ya no suspende el equipo al cerrar la tapa mientras haya un
# monitor externo conectado (queda "Docked", ver HandleLidSwitchDocked=ignore
# en logind.conf, que es el valor por defecto), así que solo falta esto.
#
# Reiniciamos quickshell tras cada cambio porque su PanelWindow no se
# reengancha solo cuando la pantalla a la que está anclado desaparece/vuelve.

# El panel interno casi siempre usa el prefijo "eDP" (a veces "LVDS" en hardware
# más antiguo). Usamos "monitors all" porque un monitor deshabilitado no sale
# en "monitors" a secas, y necesitamos su nombre para poder reactivarlo luego.
laptop_output() {
    hyprctl monitors all 2>/dev/null | awk '/^Monitor (eDP|LVDS)/ {print $2; exit}'
}

restart_quickshell() {
    pkill -x quickshell
    sleep 0.3
    nohup quickshell >/tmp/quickshell.log 2>&1 &
    disown
}

apply_state() {
    local output
    output=$(laptop_output)
    [ -z "$output" ] && return   # No hay panel interno en esta máquina: nada que hacer

    local lid
    lid=$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
        org.freedesktop.login1.Manager LidClosed 2>/dev/null | awk '{print $2}')

    if [ "$lid" = "true" ]; then
        hyprctl eval "hl.monitor({ output = \"$output\", disabled = true })" >/dev/null 2>&1
    else
        hyprctl eval "hl.monitor({ output = \"$output\", disabled = false, mode = \"preferred\", position = \"0x0\", scale = \"1\" })" >/dev/null 2>&1
    fi

    restart_quickshell
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
