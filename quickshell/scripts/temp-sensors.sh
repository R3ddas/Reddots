#!/usr/bin/env bash
# Sensores de temperatura para services/SystemMonitor.qml, uno por línea:
#   <nombre>|<archivo>        p.ej. "Procesador|/sys/class/hwmon/hwmon2/temp1_input"
# Solo dice DÓNDE leer: SystemMonitor.qml lo lanza una vez al arrancar y luego lee esos
# archivos directamente (con FileView, sin lanzar procesos), igual que /proc/stat y
# /proc/meminfo. El archivo da la temperatura en milésimas de °C.
# Todo sale de /sys: no hace falta instalar nada ni permisos especiales.

# En /sys/class/hwmon cada chip tiene un "name" que dice qué es. De cada uno se coge el
# sensor que mejor lo representa (su etiqueta), o el primero si no tiene etiquetas.
temp() {    # temp <nombre a mostrar> <carpeta hwmon> <etiquetas preferidas...>
    local label="$1" dir="$2"; shift 2
    local want f
    for want in "$@"; do
        for f in "$dir"/temp*_label; do
            [[ -f "$f" && "$(< "$f")" == "$want" ]] && { echo "$label|${f%_label}_input"; return; }
        done
    done
    [[ -f "$dir/temp1_input" ]] && echo "$label|$dir/temp1_input"
}

for dir in /sys/class/hwmon/hwmon*; do
    case "$(< "$dir/name")" in
        k10temp|zenpower) temp "Procesador" "$dir" Tctl Tdie ;;        # AMD
        coretemp)         temp "Procesador" "$dir" "Package id 0" ;;   # Intel
        amdgpu|nouveau)   temp "Gráfica" "$dir" edge ;;
        nvme)             temp "Disco" "$dir" Composite ;;
    esac
done
