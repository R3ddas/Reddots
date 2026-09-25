#!/usr/bin/env python3
"""Genera ~/.config/alacritty/colors.toml a partir de los colores del tema
activo en Theme.qml (Quickshell lo llama solo, ver Theme.qml). No editar a
mano: los cambios se pierden en el próximo cambio de tema.

Recibe los 16 colores Base16 del tema (base00 … base0F) y los reparte como
el estándar de Base16 para terminales: fondo base00, texto base05, y los
acentos base08–0E a rojo, amarillo, verde, cian, azul y morado. Los "bright"
repiten los normales (Base16 no tiene más colores para diferenciarlos).

Donde el reparto estándar se lee mal en algunos temas, se elige el color
que más contraste:
  - Negro: en un tema oscuro, base01 (casi como el fondo, lo normal); en uno
    claro tiene que ser oscuro de verdad (base05), o no se vería.
  - Negro brillante (comentarios, sugerencias de fish): base03 o base04, con
    el mismo criterio que el texto apagado de la barra (ver roles() en Theme.qml).
  - Blanco brillante: base05, base06 o base07, el que más se distinga del fondo
    (en algunos temas base06 y base07 son colores de acento o casi el fondo).
  - Texto seleccionado: sobre base02, el que mejor se lea de base05, base00 y base07.
"""
import sys
from pathlib import Path


def luminance(hex_color):
    """Luminancia relativa (WCAG): 0 = negro, 1 = blanco."""
    def channel(c):
        c = int(c, 16) / 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    h = hex_color.lstrip("#")[-6:]      # Por si llegase con alfa (#aarrggbb)
    r, g, b = (channel(h[i:i + 2]) for i in (0, 2, 4))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    """Contraste WCAG entre dos colores: de 1 (iguales) a 21 (blanco y negro)."""
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def is_light(hex_color):
    """True si el color es claro. Así se sabe si el tema es claro u oscuro sin
    tener que marcarlo en Theme.qml."""
    return luminance(hex_color) > 0.18


def main():
    if len(sys.argv) != 17:
        sys.exit(f"uso: {sys.argv[0]} base00 base01 … base0F   (los 16 colores del tema)")

    b = sys.argv[1:]            # b[0] = base00 … b[15] = base0F
    bg, fg = b[0], b[5]

    black = fg if is_light(bg) else b[1]
    muted_score = lambda c: min(contrast(c, bg), contrast(fg, c))
    bright_black = max(b[3], b[4], key=muted_score)
    bright_white = max(b[5], b[6], b[7], key=lambda c: contrast(c, bg))
    selection_text = max(fg, bg, b[7], key=lambda c: contrast(c, b[2]))

    accents = f"""red     = "{b[8]}"
green   = "{b[11]}"
yellow  = "{b[10]}"
blue    = "{b[13]}"
magenta = "{b[14]}"
cyan    = "{b[12]}\""""

    toml = f"""# Autogenerado por gen-alacritty-colors.py a partir de quickshell/Theme.qml
# No editar a mano: se sobrescribe en cada cambio de tema.

[colors.primary]
background = "{bg}"
foreground = "{fg}"

[colors.cursor]
text   = "{bg}"
cursor = "{fg}"

[colors.selection]
text       = "{selection_text}"
background = "{b[2]}"

[colors.normal]
black   = "{black}"
{accents}
white   = "{fg}"

[colors.bright]
black   = "{bright_black}"
{accents}
white   = "{bright_white}"
"""

    out_path = Path.home() / ".config/alacritty/colors.toml"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = out_path.with_suffix(".toml.tmp")
    tmp_path.write_text(toml)
    tmp_path.replace(out_path)


if __name__ == "__main__":
    main()
