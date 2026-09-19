#!/usr/bin/env python3
"""Genera ~/.config/alacritty/colors.toml a partir de los colores del tema
activo en Theme.qml (Quickshell lo llama solo, ver Theme.qml). No editar a
mano: los cambios se pierden en el próximo cambio de tema.

Theme.qml solo define 10 colores por tema (sin rojo/verde/amarillo/azul/
magenta/cian "de verdad"), así que cada color que pide Alacritty se mapea
aquí directamente a uno de esos 10, sin inventar ni calcular ninguno nuevo.
Como solo hay tres acentos (extra1/2/3) más textSelected para seis huecos,
algunos se repiten (ANSI_MAP) — y al no haber más colores para diferenciar
"normal" de "bright" en los acentos, bright usa los mismos valores.
"""
import sys
from pathlib import Path

FIELDS = [
    "background", "textActive", "textSelected", "textDisabled",
    "surface", "surfaceHover", "border", "extra1", "extra2", "extra3",
]

# Cada color ANSI -> el color del tema que se le asigna (se repiten a propósito)
ANSI_MAP = {
    "red":     "extra1",
    "green":   "extra2",
    "yellow":  "extra1",
    "blue":    "extra3",
    "magenta": "textSelected",
    "cyan":    "extra2",
}


def main():
    if len(sys.argv) != len(FIELDS) + 1:
        sys.exit(f"uso: {sys.argv[0]} " + " ".join(FIELDS))

    c = dict(zip(FIELDS, sys.argv[1:]))
    ansi = {name: c[prop] for name, prop in ANSI_MAP.items()}

    toml = f"""# Autogenerado por gen-alacritty-colors.py a partir de quickshell/Theme.qml
# No editar a mano: se sobrescribe en cada cambio de tema.

[colors.primary]
background = "{c['background']}"
foreground = "{c['textActive']}"

[colors.cursor]
text   = "{c['background']}"
cursor = "{c['textActive']}"

[colors.selection]
text       = "{c['background']}"
background = "{c['surfaceHover']}"

[colors.normal]
black   = "{c['background']}"
red     = "{ansi['red']}"
green   = "{ansi['green']}"
yellow  = "{ansi['yellow']}"
blue    = "{ansi['blue']}"
magenta = "{ansi['magenta']}"
cyan    = "{ansi['cyan']}"
white   = "{c['surfaceHover']}"

[colors.bright]
black   = "{c['textDisabled']}"
red     = "{ansi['red']}"
green   = "{ansi['green']}"
yellow  = "{ansi['yellow']}"
blue    = "{ansi['blue']}"
magenta = "{ansi['magenta']}"
cyan    = "{ansi['cyan']}"
white   = "{c['textActive']}"
"""

    out_path = Path.home() / ".config/alacritty/colors.toml"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = out_path.with_suffix(".toml.tmp")
    tmp_path.write_text(toml)
    tmp_path.replace(out_path)


if __name__ == "__main__":
    main()
