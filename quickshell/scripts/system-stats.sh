#!/usr/bin/env bash
# Uso del sistema para SystemStats.qml, que lo lanza cada 2 s mientras su panel está abierto:
#   cpu <user> <nice> <system> <idle> <iowait> <irq> <softirq> <steal>   (contadores de /proc/stat:
#        el % de uso sale de la diferencia entre dos lecturas, eso lo calcula SystemStats.qml)
#   mem <total> <disponible>          (kB, de /proc/meminfo)
#   swap <total> <libre>              (kB)
#   temp|<nombre>|<milésimas de °C>   (una por sensor encontrado)
# Todo sale de /proc y /sys: no hace falta instalar nada ni permisos especiales.

head -1 /proc/stat | awk '{print "cpu", $2, $3, $4, $5, $6, $7, $8, $9}'
awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} /^SwapTotal:/ {st=$2} /^SwapFree:/ {sf=$2}
     END {print "mem", t, a; print "swap", st, sf}' /proc/meminfo

# Temperaturas: en /sys/class/hwmon cada chip tiene un "name" que dice qué es. De cada uno
# se coge el sensor que mejor lo representa (su etiqueta), o el primero si no tiene etiquetas.
temp() {    # temp <nombre a mostrar> <carpeta hwmon> <etiquetas preferidas...>
    local label="$1" dir="$2"; shift 2
    local want f
    for want in "$@"; do
        for f in "$dir"/temp*_label; do
            [[ -f "$f" && "$(< "$f")" == "$want" ]] && { echo "temp|$label|$(< "${f%_label}_input")"; return; }
        done
    done
    [[ -f "$dir/temp1_input" ]] && echo "temp|$label|$(< "$dir/temp1_input")"
}

for dir in /sys/class/hwmon/hwmon*; do
    case "$(< "$dir/name")" in
        k10temp|zenpower) temp "Procesador" "$dir" Tctl Tdie ;;        # AMD
        coretemp)         temp "Procesador" "$dir" "Package id 0" ;;   # Intel
        amdgpu|nouveau)   temp "Gráfica" "$dir" edge ;;
        nvme)             temp "Disco" "$dir" Composite ;;
    esac
done
