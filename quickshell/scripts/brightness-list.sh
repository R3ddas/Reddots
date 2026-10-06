#!/usr/bin/env bash
# Lista las pantallas con brillo regulable para services/BrightnessMonitor.qml, una por línea:
#   tipo|objetivo|nombre|porcentaje|máximo
# tipo "backlight" = panel del portátil (objetivo = dispositivo de brightnessctl)
# tipo "ddc"       = monitor externo por DDC/CI (objetivo = número de bus i2c de ddcutil)

# Panel interno: brightnessctl, solo la clase backlight (sin ella, en un PC devuelve un LED del teclado)
brightnessctl -l -m -c backlight 2>/dev/null | while IFS=, read -r dev _ _ pct max; do
    echo "backlight|$dev|Pantalla del portátil|${pct%\%}|$max"
done

# Monitores externos: ddcutil, código VCP 10 (brillo). Cada consulta tarda ~0,1 s (ddcutil
# guarda en ~/.cache/ddcutil lo que tarda cada monitor en responder, y así no espera de más).
#
# El panel del portátil también sale en "ddcutil detect" (como "Invalid display"), pero nunca
# responde por DDC: su brillo va por brightnessctl, arriba. Preguntarle igualmente costaba más
# que todo lo demás (~0,25 s esperando a que fallase), así que se salta por su conector, que
# ddcutil da en cada pantalla ("DRM connector: card1-eDP-1"): eDP, o LVDS en hardware antiguo.
# Es el mismo criterio que usa hypr/scripts/internal-panel.sh para saber cuál es el panel.
command -v ddcutil >/dev/null || exit 0
ddcutil detect --brief 2>/dev/null | awk '
    /I2C bus:/       { bus = $3; sub("/dev/i2c-", "", bus); internal = 0 }   # Empieza una pantalla nueva
    /DRM connector:/ { internal = ($3 ~ /-(eDP|LVDS)-/) }                    # "card1-eDP-1": el panel del portátil
    /Monitor:/       { if (internal) next; sub(/^[^:]*:[ \t]*/, ""); split($0, m, ":"); print bus "|" m[2] }   # "MSI:MSI MAG274QRF:serie" -> "MSI MAG274QRF"
' | while IFS='|' read -r bus name; do
    read -r _ _ _ cur max < <(ddcutil --bus "$bus" getvcp 10 --brief 2>/dev/null)   # Salida: "VCP 10 C actual máximo"
    [[ "$max" =~ ^[0-9]+$ && "$max" -gt 0 ]] || continue                             # No responde por DDC (algunas teles, o el DDC/CI apagado en el menú del monitor): se omite
    echo "ddc|$bus|$name|$(( cur * 100 / max ))|$max"
done
