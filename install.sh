#!/usr/bin/env bash
set -euo pipefail
#cd "(dirname "$0")"

echo "Instalando"

echo "Paquetes necesarios"

sed 's/#.*//' packages.txt | grep -v '^\s*s' \
| xargs -r sudo pacman -S --needed  --noconfirm

echo "Paquetes no utilizados"

# Quito dolphin porque instalo nemo
# pacman -Qq comprueba si existe; si no está, la parte de la derecha no se ejecuta y el script sigue como si nada.
sudo pacman -Qq dolphin &>/dev/null && sudo pacman -Rns --noconfirm dolphin || true

echo "Sistema de archivos"

mkdir -p ~/.config/quickshell

echo "Listo"
