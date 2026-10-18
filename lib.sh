# Funciones que comparten update.sh, install.sh y quickshell/scripts/uninstall-check.sh.
# No se ejecuta: se carga con source.

# Los nombres de una de las listas del repo (packages*.txt, apps/vscode/extensions.txt), uno
# por línea: sin comentarios (lo que va tras #), sin líneas vacías y sin espacios
listFile() { sed 's/#.*//' "$1" | awk 'NF { print $1 }'; }
