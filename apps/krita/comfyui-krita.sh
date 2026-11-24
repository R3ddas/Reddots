#!/usr/bin/env bash
# Prepara el ComfyUI que instala Stability Matrix para que el plugin de IA de Krita se pueda conectar
# a él ("Custom Server"), en vez de que el plugin monte su propio ComfyUI con sus propios modelos:
# así hay un solo ComfyUI y los modelos que bajes desde Stability Matrix salen también en Krita.
# Lo que comprueba el plugin al conectarse (docs.interstice.cloud/comfyui-setup):
#   - sus nodos (custom_nodes), que se clonan o se actualizan, con sus dependencias instaladas en
#     el venv del propio ComfyUI;
#   - los modelos auxiliares que necesita (inpaint, IP-Adapter, upscalers...), que baja el script
#     download_models.py que trae el plugin. Por defecto los de SDXL, sin checkpoints (esos los
#     eliges tú en Stability Matrix). Para otros, pásale las opciones del script tras la carpeta:
#       comfyui-krita.sh "" --illu --flux2      (la carpeta vacía = la de Stability Matrix)
#       comfyui-krita.sh "" --list --sdxl       (solo lista lo que bajaría)
# Se puede ejecutar tantas veces como se quiera (por ejemplo, tras actualizar el plugin): lo que
# ya está no se vuelve a bajar. Con ComfyUI parado, que no se le cambien los nodos en marcha.
#
# Uso: apps/krita/comfyui-krita.sh [carpeta de ComfyUI] [opciones de download_models.py]
set -euo pipefail

plugin=~/.local/share/krita/pykrita/ai_diffusion
comfy=${1:-}
shift || true
modelArgs=("$@")
(( ${#modelArgs[@]} )) || modelArgs=(--sdxl)

# Sin carpeta, el ComfyUI de la biblioteca de Stability Matrix: la que eligió al arrancar la
# primera vez (~/.config/StabilityMatrix/library.json) o, en modo portable, la de junto al programa
if [[ -z "$comfy" ]]; then
    library=""
    if [[ -f /opt/stabilitymatrix/Data/.sm-portable ]]; then
        library=/opt/stabilitymatrix/Data
    elif [[ -f ~/.config/StabilityMatrix/library.json ]]; then
        library=$(jq -r '.LibraryPath // empty' ~/.config/StabilityMatrix/library.json)
    fi
    # Cada paquete va en Packages/<nombre que le diste>: ComfyUI es el que tiene main.py y comfy/
    for dir in "$library"/Packages/*/; do
        if [[ -f "$dir/main.py" && -d "$dir/comfy" ]]; then comfy=${dir%/}; break; fi
    done
fi

if [[ -z "$comfy" || ! -f "$comfy/main.py" ]]; then
    echo "No encuentro ComfyUI. Instálalo desde Stability Matrix (Paquetes > Añadir paquete > ComfyUI)"
    echo "o pasa su carpeta: $0 /ruta/a/ComfyUI"
    exit 1
fi
python="$comfy/venv/bin/python"
if [[ ! -x "$python" ]]; then
    echo "$comfy no tiene venv/: ¿se terminó de instalar desde Stability Matrix?"
    exit 1
fi
if [[ ! -f "$plugin/download_models.py" ]]; then
    echo "Falta el plugin de IA de Krita: ejecuta install.sh con Krita instalado"
    exit 1
fi
echo "ComfyUI: $comfy"

# Stability Matrix puede crear el venv sin pip (instala con uv)
if ! "$python" -m pip --version &>/dev/null; then "$python" -m ensurepip --upgrade; fi

echo "Nodos que necesita el plugin"

# Los cuatro obligatorios y GGUF, opcional (el plugin lo usa si está, para modelos .gguf, más
# pequeños: vienen bien con poca VRAM). Sus requirements no fijan versión de torch, así que no
# cambian el torch de CUDA o ROCm que instaló Stability Matrix
nodes=(
    Fannovel16/comfyui_controlnet_aux
    cubiq/ComfyUI_IPAdapter_plus
    Acly/comfyui-inpaint-nodes
    Acly/comfyui-tooling-nodes
    city96/ComfyUI-GGUF
)
for repo in "${nodes[@]}"; do
    dir="$comfy/custom_nodes/${repo#*/}"
    if [[ -d "$dir/.git" ]]; then
        git -C "$dir" pull --ff-only --quiet || echo "Aviso: no se ha podido actualizar ${repo#*/}"
    else
        git clone --depth 1 --quiet "https://github.com/$repo" "$dir"
    fi
    if [[ -f "$dir/requirements.txt" ]]; then
        "$python" -m pip install --quiet -r "$dir/requirements.txt"
    fi
done

echo "Modelos que necesita el plugin (${modelArgs[*]})"

# El backend, por la gráfica: así no baja los modelos que solo sirven en la otra. aiohttp y tqdm
# (los usa el script) ya vienen con ComfyUI
backend=auto
if lspci | grep -iE 'vga|3d|display' | grep -qi nvidia; then backend=cuda
elif lspci | grep -iE 'vga|3d|display' | grep -qiE 'amd|ati'; then backend=rocm
fi
# Desde el directorio del plugin no: el script se lanza con -I para que no cargue módulos de ahí
"$python" -I "$plugin/download_models.py" --backend "$backend" "${modelArgs[@]}" "$comfy"

echo "Listo. Arranca ComfyUI desde Stability Matrix y, en Krita, conecta el plugin a"
echo "Custom Server: http://127.0.0.1:8188 (Configurar > Conexión)"
