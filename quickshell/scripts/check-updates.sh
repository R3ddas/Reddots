#!/usr/bin/env bash
# Actualizaciones pendientes para Updates.qml, una por línea:
#   repos|paquete versión -> nueva     (repos oficiales, con checkupdates de pacman-contrib)
#   aur|paquete versión -> nueva       (AUR, con paru -Qua)
# y una última línea "ok" si se ha podido consultar. Sin ella (p.ej. sin red), la barra
# se queda con lo que sabía en vez de creer que no hay nada pendiente.
# checkupdates usa una copia de la base de datos de pacman: no toca la del sistema ni pide sudo.
#
# Cada consulta lleva un tiempo máximo (timeout): si se queda colgada (red caída a
# medias, un mirror que no responde...), Updates.qml esperaría para siempre a que
# terminase y no volvería a mirar nunca. Si se corta, sale sin "ok", como si no se
# hubiera podido consultar.
limit=60        # Segundos para cada consulta

repos=$(timeout "$limit" checkupdates 2>/dev/null)
code=$?
(( code != 0 && code != 2 )) && exit 1      # 0 = hay alguna, 2 = ninguna, 1 = no se ha podido consultar, 124 = timeout
[[ -n "$repos" ]] && sed 's/^/repos|/' <<< "$repos"

# Los de AUR que están en IgnorePkg salen marcados "[ignored]": esos no cuentan
if command -v paru >/dev/null; then
    aur=$(timeout "$limit" paru -Qua 2>/dev/null)
    (( $? == 124 )) && exit 1               # Cortado por el timeout (sin nada pendiente, paru sale con 1: eso no es un fallo)
    [[ -n "$aur" ]] && grep -v '\[ignored\]' <<< "$aur" | sed 's/^/aur|/'
fi

echo ok
