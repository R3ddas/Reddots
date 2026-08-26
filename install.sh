#!/usr/bin/env bash
set -euo pipefail
#cd "(dirname "$0")"

echo "Instalando"

echo "Paquetes necesarios"

sed 's/#.*//' packages.txt | grep -v '^\s*$' \
| xargs -r sudo pacman -S --needed  --noconfirm

#Si quisiera separar Steam (o cualquier otro paquete)
#echo "Steam"
#sed 's/#.*//' packages.txt | grep -v '^\s*$' | grep -vw 'steam' \
#| xargs -r sudo pacman -S --needed --noconfirm
#read -r -p "¿Instalar steam? [s/N] " respuesta
#if [[ "$respuesta" =~ ^[sS]$ ]]; then
#    sudo pacman -S --needed steam
#fi

echo "Paquetes no utilizados"

# Quito dolphin porque instalo nemo
# pacman -Qq comprueba si existe; si no está, la parte de la derecha no se ejecuta y el script sigue como si nada.
sudo pacman -Qq dolphin &>/dev/null && sudo pacman -Rns --noconfirm dolphin || true

echo "Sistema de archivos"

mkdir -p ~/.config/quickshell

echo "Otras configuraciones"

timedatectl set-local-rtc 1 --adjust-system-clock # Para que el reloj no se cambie cada vez que arranca windows

echo "Listo"
