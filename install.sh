#!/usr/bin/env bash
set -euo pipefail
#cd "(dirname "$0")"

echo "Instalando"

echo "Paquetes necesarios"

sed 's/#.*//' packages.txt | grep -v '^\s*s' \
| xargs -r sudo pacman -S --needed  --noconfirm

echo "Paquetes no utilizados"

sudo pacman -Rns dolphin # Quito dolphin porque instalo nemo

echo "Sistema de archivos"

mkdir -p ~/.config/quickshell

echo "Listo"
