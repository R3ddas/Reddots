#!/usr/bin/env bash
# Instalación completa de Reddots: lo mismo que update.sh (que se ejecuta primero) y, además,
# lo que es solo de la primera vez y no se repite al actualizar: preguntar por las apps de
# packages_opt.txt, instalar las extensiones de VS Code (sin preguntar), quitar las que sobran
# (Firefox, Kitty...), el inicio de sesión automático, el reloj para el dual boot, el arranque
# sin texto y, si Secure Boot ya está activo, el hook que mantiene GRUB firmado.
# Se puede volver a lanzar (también desde la barra, con "Instalar"): pregunta otra vez por
# los opcionales que no estén instalados y vuelve a quitar los que sobran.
set -euo pipefail
cd "$(dirname "$0")"

# Con source y no ./update.sh: así se comparten DOTS y listFile (de lib.sh). Si algo falla ahí, la
# instalación se corta igual (set -e).
source ./update.sh

echo "Paquetes opcionales"

# Los de packages_opt.txt que aún no están instalados: los que ya están no se preguntan
# (ni se reinstalan). update.sh no pasa por aquí, así que al actualizar no se pregunta nada.
# Uno a uno se pregunta por cada paquete, salvo los de un grupo: los que van tras una
# cabecera "## Nombre" (una sola palabra), hasta la siguiente línea vacía, se preguntan
# juntos. optList saca una línea "grupo|paquete" por paquete (grupo vacío si va suelto).
optList() {
    awk '/^##/ { group = $2; next }     # Empieza un grupo
         !NF   { group = ""; next }     # Una línea vacía lo termina
         { sub(/#.*/, "") } NF { print group "|" $1 }' packages_opt.txt
}

optional=()     # Todos los que faltan, para "todos"
units=()        # Por lo que se pregunta uno a uno: un paquete, o los de un grupo separados por espacios
groups=()       # El grupo de cada uno de units (vacío si es un paquete suelto)
while IFS='|' read -r group pkg; do
    if pacman -Qq "$pkg" &>/dev/null; then continue; fi
    optional+=("$pkg")
    if [[ -n "$group" ]] && (( ${#groups[@]} )) && [[ "${groups[-1]}" == "$group" ]]; then
        units[-1]+=" $pkg"      # Otro del mismo grupo: va con los anteriores
    else
        units+=("$pkg"); groups+=("$group")
    fi
done < <(optList)

# Cómo se nombra cada uno al preguntar: el paquete, o el grupo con los suyos
labels=()
for i in "${!units[@]}"; do
    if [[ -n "${groups[i]}" ]]; then labels+=("${groups[i]} (${units[i]})"); else labels+=("${units[i]}"); fi
done

chosen=()   # Los que se van a instalar
if (( ${#optional[@]} == 0 )); then
    echo "Todos los opcionales están ya instalados"
elif [[ ! -t 0 ]]; then
    # Sin terminal (lanzado desde otro script sin entrada) read no puede preguntar y,
    # con set -e, cortaría la instalación: se sigue sin instalar ninguno
    echo "Sin terminal para preguntar: no se instala ninguno (${optional[*]})"
else
    echo "Sin instalar: ${optional[*]}"
    while true; do      # Se repite hasta una respuesta válida; Intro a secas = ninguno, como el [s/N] de abajo
        read -r -p "¿Instalarlos? [t]odos, [N]inguno o [u]no a uno: " mode
        case "$mode" in
            [tT]) chosen=("${optional[@]}"); break ;;
            [nN]|"") break ;;
            [uU])
                for i in "${!units[@]}"; do
                    read -r -p "¿Instalar ${labels[i]}? [s/N] " answer
                    # Con if y no con "[[ ]] && ...": con set -e, un "no" en el último paquete
                    # dejaría el bucle con código 1 y cortaría el script. read -a separa los
                    # de un grupo en paquetes sueltos para paru
                    if [[ "$answer" =~ ^[sS]$ ]]; then read -ra pkgs <<< "${units[i]}"; chosen+=("${pkgs[@]}"); fi
                done
                break ;;
            *) echo "Responde t, n o u" ;;
        esac
    done
fi

# Con paru y no con pacman: así un opcional puede ser tanto de los repos como de AUR
if (( ${#chosen[@]} > 0 )); then
    paru -S --needed --noconfirm "${chosen[@]}"
fi

echo "Extensiones de Visual Studio Code"

# Si VS Code está (ya lo estaba o se acaba de instalar), todas sus extensiones, sin preguntar.
# En una sola llamada a code (cada una tarda en arrancar); las que ya están las deja como están
if command -v code &>/dev/null; then
    mapfile -t extensions < <(listFile apps/vscode/extensions.txt)
    vscodeArgs=()
    for ext in "${extensions[@]}"; do vscodeArgs+=(--install-extension "$ext"); done
    code "${vscodeArgs[@]}"
fi

echo "Paquetes no utilizados"

# Los de packages_remove.txt que están instalados (pacman -Qq escribe los que encuentra y se
# queja de los demás: esa queja se descarta), todos en una sola llamada. Si pacman no puede
# quitarlos (otro paquete depende de alguno), se avisa y se sigue: no merece la pena cortar la
# instalación por esto. Ojo: con la lista vacía no se llama a pacman, porque "pacman -Qq" sin
# nada más saca TODOS los paquetes instalados, y se quitarían todos
mapfile -t unwanted < <(listFile packages_remove.txt)
installed=()
if (( ${#unwanted[@]} )); then
    mapfile -t installed < <(pacman -Qq "${unwanted[@]}" 2>/dev/null)
fi
if (( ${#installed[@]} )); then
    sudo pacman -Rns --noconfirm "${installed[@]}" || echo "Aviso: no se han podido quitar ${installed[*]}"
fi


echo "Inicio de sesión"

# No hay gestor de inicio de sesión (SDDM, GDM...): en la TTY1 se entra solo, sin pedir
# usuario ni contraseña, y apps/fish/config.fish arranca Hyprland con la pantalla ya
# bloqueada. La contraseña la pide el bloqueo de Quickshell (quickshell/windows/Lock.qml),
# así que el inicio de sesión tiene el mismo fondo y los mismos colores que el escritorio.
# Ojo: la sesión arranca un instante antes de que aparezca el bloqueo (y el disco no va
# cifrado), así que esto protege igual que un bloqueo de pantalla, no más.
#
# Con la credencial agetty.autologin (agetty la lee desde util-linux 2.40) y no cambiando
# el ExecStart de getty@.service: así no se copia la línea de agetty, que cambia entre
# versiones de systemd. Para volver a pedir usuario y contraseña en la TTY, basta con
# borrar este archivo (y "sudo systemctl daemon-reload").
# Solo se aplica en el siguiente arranque: reiniciar ahora getty@tty1 cerraría la sesión,
# que vive en esa misma TTY.
autologinConf=/etc/systemd/system/getty@tty1.service.d/autologin.conf
autologinText="[Service]
SetCredential=agetty.autologin:$USER"
if [[ "$(cat "$autologinConf" 2>/dev/null)" != "$autologinText" ]]; then
    sudo mkdir -p "$(dirname "$autologinConf")"
    printf '%s\n' "$autologinText" | sudo tee "$autologinConf" > /dev/null
    sudo systemctl daemon-reload
fi

echo "Reloj (dual boot con Windows)"

# Windows guarda el RTC en hora local; Linux por defecto lo asume en UTC.
# Si no está ya puesto en local, lo activamos para que no se descuadre la hora al alternar entre los dos.
if [[ "$(timedatectl show -p LocalRTC --value)" != "yes" ]]; then
    sudo timedatectl set-local-rtc 1 --adjust-system-clock
fi

echo "Arranque sin texto"

# "quiet" en la línea del kernel, junto al "splash" de Plymouth: así tampoco salen los
# mensajes del kernel ni los "[ OK ] Started…" de systemd en los momentos en que Plymouth
# no tapa la pantalla (antes de que arranque y al cerrarse, justo antes del login). Es solo
# estético, no acelera el arranque, y vale para cualquier equipo y gráfica.
# Solo si el equipo arranca con GRUB (otro gestor de arranque tiene su propia config), y
# grub.cfg solo se regenera si "quiet" no estaba ya: el resto de veces no se toca nada.
grubConf=/etc/default/grub
if [[ -f "$grubConf" ]] && ! grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT=.*\bquiet\b' "$grubConf"; then
    # Se añade al final, dentro de las comillas (simples o dobles) que cierran el valor
    sudo sed -i -E "/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/(['\"])\$/ quiet\1/" "$grubConf"
    if grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT=.*\bquiet\b' "$grubConf"; then
        sudo grub-mkconfig -o /boot/grub/grub.cfg
    else
        echo "Aviso: no se pudo añadir quiet a GRUB_CMDLINE_LINUX_DEFAULT en $grubConf (¿sin comillas?)"
    fi
fi

echo "Arranque seguro (Secure Boot)"

# Esto NO activa Secure Boot: crear y registrar las claves exige poner la BIOS en Setup Mode
# a mano y, si sale mal, el equipo no arranca. Se hace una vez, a mano y en el equipo que lo
# necesite (ver README). Aquí solo se deja el mantenimiento: si Secure Boot ya está activo y
# se arranca con GRUB, un hook de pacman que, al actualizar grub, repite el grub-install (con
# las mismas opciones que se usaron al configurarlo) y vuelve a firmar el resultado. Sin él,
# GRUB nuevo = binario sin firmar = la BIOS lo rechaza y el equipo no arranca. Los kernels no
# hacen falta: el hook que trae sbctl (zz-sbctl) ya vuelve a firmar los registrados con "-s".
# En un equipo sin Secure Boot (o sin GRUB) no se toca nada.
secureBootVar=/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c
secureBootOn=false
# La variable son 4 bytes de atributos y uno de valor: 1 = activado. No se usa "sbctl status"
# porque su salida está pensada para leerla una persona, no para comparar texto
if [[ -r "$secureBootVar" && "$(od -An -t u1 "$secureBootVar" | awk '{ print $NF }')" == 1 ]]; then
    secureBootOn=true
fi
if $secureBootOn && command -v sbctl &>/dev/null && [[ -f /etc/default/grub ]]; then
    # La ESP y la carpeta donde está grubx64.efi (que no es la de BOOT, el respaldo) salen del
    # propio equipo, no se fijan aquí: cambian de una instalación a otra. La ESP solo la lee
    # root, de ahí el sudo
    esp=$(sudo bootctl --print-esp-path 2>/dev/null || true)
    grubDir=$(sudo find "$esp/EFI" -mindepth 2 -maxdepth 2 -iname grubx64.efi ! -ipath '*/EFI/BOOT/*' \
        -printf '%h\n' 2>/dev/null | head -n 1 || true)
    if [[ -z "$esp" || -z "$grubDir" ]]; then
        echo "Aviso: Secure Boot está activo, pero no encuentro grubx64.efi en la ESP: no se instala el hook de GRUB"
    else
        # Se registra en la base de datos de sbctl (-s) para que "sign-all" del hook lo
        # encuentre; si ya estaba, no hace nada
        sudo sbctl sign -s "$grubDir/grubx64.efi" > /dev/null
        hookFile=/etc/pacman.d/hooks/95-grub-secureboot.hook
        # --modules=tpm y --disable-shim-lock porque no se usa shim; es lo que se ejecutó al
        # configurar Secure Boot. Va con 95 para que corra antes que zz-sbctl
        hookText="[Trigger]
Operation = Upgrade
Type = Package
Target = grub

[Action]
Description = Reinstalando GRUB y firmandolo para Secure Boot
When = PostTransaction
Depends = sbctl
Exec = /bin/sh -c 'grub-install --target=x86_64-efi --efi-directory=$esp --bootloader-id=${grubDir##*/} --modules=tpm --disable-shim-lock && /usr/bin/sbctl sign-all'"
        if [[ "$(cat "$hookFile" 2>/dev/null)" != "$hookText" ]]; then
            sudo mkdir -p "$(dirname "$hookFile")"
            printf '%s\n' "$hookText" | sudo tee "$hookFile" > /dev/null
        fi
    fi
fi

echo "Listo"
