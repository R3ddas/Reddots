#!/usr/bin/env bash
set -euo pipefail
#cd "(dirname "$0")"

echo "Instalando"
sed 's/#.*//' packages.txt | grep -v '^\s*s' \
| xargs -r sudo pacman -S --needed

echo "Listo"
