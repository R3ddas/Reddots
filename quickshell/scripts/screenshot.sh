#!/usr/bin/env bash
# Capturas de pantalla para Screenshot.qml. Uso: screenshot.sh region|ventana|pantalla|carpeta
#   region   -> se arrastra un rectángulo con el ratón
#   ventana  -> se hace clic en una de las ventanas visibles
#   pantalla -> el monitor entero en el que está el ratón
#   carpeta  -> abre la carpeta de las capturas
# Cada captura se guarda en <carpeta de imágenes>/Capturas, se copia al portapapeles
# y se avisa con una notificación. Esc durante la selección la cancela sin guardar nada.

mode="$1"

dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Capturas"   # ~/Imágenes/Capturas con el sistema en español
mkdir -p "$dir"

if [[ "$mode" == "carpeta" ]]; then
    exec xdg-open "$dir"
fi

file="$dir/Captura $(date '+%Y-%m-%d %H-%M-%S').png"

# Da tiempo a que se cierre el desplegable de la barra, para que no salga en la captura
sleep 0.3

# Mientras se elige la región o la ventana, la pantalla se congela (hyprpicker pinta
# encima una imagen fija de lo que había): así se pueden capturar menús y tooltips
# que desaparecerían al mover el ratón. Se quita al terminar, pase lo que pase.
freeze() {
    hyprpicker --render-inactive --no-zoom >/dev/null 2>&1 &
    freeze_pid=$!
    sleep 0.2       # Que llegue a pintarse antes de que aparezca slurp
}
unfreeze() { [[ -n "${freeze_pid:-}" ]] && kill "$freeze_pid" 2>/dev/null; }
trap unfreeze EXIT

case "$mode" in
    region)
        freeze
        geometry=$(slurp -d) || exit 0      # -d: muestra el tamaño mientras se arrastra. Esc = cancelar
        grim -g "$geometry" "$file" || exit 1
        ;;
    ventana)
        freeze
        # Rectángulos ("x,y anchoxalto") de las ventanas de los workspaces que se ven ahora
        # en algún monitor; slurp -r solo deja elegir uno de ellos con un clic
        visible=$(hyprctl monitors -j | jq '[.[].activeWorkspace.id]')
        geometry=$(hyprctl clients -j \
            | jq -r --argjson visible "$visible" \
                '.[] | select(.workspace.id as $w | $visible | index($w)) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' \
            | slurp -r) || exit 0
        grim -g "$geometry" "$file" || exit 1
        ;;
    pantalla)
        monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
        grim -o "$monitor" "$file" || exit 1
        ;;
    *)
        echo "uso: $0 region|ventana|pantalla|carpeta" >&2
        exit 2
        ;;
esac

wl-copy --type image/png < "$file"
notify-send -a "Captura" -i "$file" "Captura guardada y copiada" "${file/#$HOME/\~}"
