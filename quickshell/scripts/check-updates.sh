#!/usr/bin/env bash
# Actualizaciones pendientes para Updates.qml, una por línea:
#   repos|paquete versión -> nueva     (repos oficiales, con checkupdates de pacman-contrib)
#   aur|paquete versión -> nueva       (AUR, con paru -Qua)
# y una última línea "ok" si se ha podido consultar. Sin ella (p.ej. sin red), la barra
# se queda con lo que sabía en vez de creer que no hay nada pendiente.
# checkupdates usa una copia de la base de datos de pacman: no toca la del sistema ni pide sudo.

repos=$(checkupdates 2>/dev/null)
code=$?
(( code == 1 )) && exit 1        # 0 = hay alguna, 2 = ninguna, 1 = no se ha podido consultar
[[ -n "$repos" ]] && sed 's/^/repos|/' <<< "$repos"

# Los de AUR que están en IgnorePkg salen marcados "[ignored]": esos no cuentan
if command -v paru >/dev/null; then
    paru -Qua 2>/dev/null | grep -v '\[ignored\]' | sed 's/^/aur|/'
fi

echo ok
