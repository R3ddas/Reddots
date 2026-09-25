#!/usr/bin/env bash
# Escribe el nombre del panel interno del portátil ("eDP-1", o "LVDS-1" en hardware
# más antiguo), o nada si no hay (PC de sobremesa). Es el único sitio donde se
# averigua: lo usan hypr/monitors.lua (reglas de monitor y Super+M),
# hypr/scripts/lid-watcher.sh (tapa) y quickshell/shell.qml (pantalla de la barra).
#
# Se saca de los conectores de /sys/class/drm ("card1-eDP-1"...), que existen desde el
# arranque y aunque el panel esté apagado: al cargar hyprland.lua, Hyprland aún no ha
# creado los monitores, y con la tapa cerrada el panel no sale en "hyprctl monitors".

for connector in /sys/class/drm/card*-eDP-* /sys/class/drm/card*-LVDS-*; do
    [[ -e "$connector" ]] || continue       # Sin coincidencias, el patrón llega tal cual
    name="${connector##*/}"                 # card1-eDP-1
    echo "${name#card*-}"                   # eDP-1
    exit 0
done
