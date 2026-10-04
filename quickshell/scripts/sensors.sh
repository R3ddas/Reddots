#!/usr/bin/env bash
# Dónde leer los sensores para services/SystemMonitor.qml, uno por línea:
#   temp|<nombre>|<archivo>     temperatura en milésimas de °C  ("temp|Procesador|/sys/class/hwmon/hwmon2/temp1_input")
#   gpu|busy|<archivo>          uso de la gráfica, en %
#   gpu|vramUsed|<archivo>      memoria de vídeo usada, en bytes
#   gpu|vramTotal|<archivo>     memoria de vídeo total, en bytes
# Solo dice DÓNDE leer: SystemMonitor.qml lo lanza una vez al arrancar y luego lee esos
# archivos directamente (con FileView, sin lanzar procesos), igual que /proc/stat y
# /proc/meminfo. Lo que no haya en el equipo no sale, y el panel no pinta esa línea.
# Todo sale de /sys: no hace falta instalar nada ni permisos especiales.

# --- Temperaturas ---
# En /sys/class/hwmon cada chip tiene un "name" que dice qué es. De cada uno se coge el
# sensor que mejor lo representa (su etiqueta), o el primero si no tiene etiquetas.
temp() {    # temp <nombre a mostrar> <carpeta hwmon> <etiquetas preferidas...>
    local label="$1" dir="$2"; shift 2
    local want f
    for want in "$@"; do
        for f in "$dir"/temp*_label; do
            [[ -f "$f" && "$(< "$f")" == "$want" ]] && { echo "temp|$label|${f%_label}_input"; return; }
        done
    done
    [[ -f "$dir/temp1_input" ]] && echo "temp|$label|$dir/temp1_input"
}

for dir in /sys/class/hwmon/hwmon*; do
    case "$(< "$dir/name")" in
        k10temp|zenpower) temp "Procesador" "$dir" Tctl Tdie ;;        # AMD
        coretemp)         temp "Procesador" "$dir" "Package id 0" ;;   # Intel
        amdgpu|nouveau)   temp "Gráfica" "$dir" edge ;;
        nvme)             temp "Disco" "$dir" Composite ;;
    esac
done

# --- Uso de la gráfica ---
# Solo las AMD (driver amdgpu) lo dan en archivos. Con NVIDIA haría falta lanzar nvidia-smi
# en cada lectura, y con Intel, intel_gpu_top (que pide permisos): en esos equipos no sale
# nada y el panel no muestra la gráfica (NVIDIA no está hecho a propósito: cómo se haría,
# en services/SystemMonitor.qml, junto a "gpuFiles"). Se coge la primera tarjeta que lo dé.
for card in /sys/class/drm/card*; do
    [[ "${card##*/}" =~ ^card[0-9]+$ && -f "$card/device/gpu_busy_percent" ]] || continue   # "card1", no sus conectores ("card1-DP-2")
    dev="$card/device"
    echo "gpu|busy|$dev/gpu_busy_percent"
    if [[ -f "$dev/mem_info_vram_used" && -f "$dev/mem_info_vram_total" ]]; then
        echo "gpu|vramUsed|$dev/mem_info_vram_used"
        echo "gpu|vramTotal|$dev/mem_info_vram_total"
    fi
    break
done
