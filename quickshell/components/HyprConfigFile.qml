// HyprConfigFile.qml
// Opciones de Hyprland que pone Quickshell: los colores del tema (Theme.qml) y las medidas
// de las ventanas (Geometry.qml). No hay binding posible con el compositor, así que
// cada cambio se aplica en dos sitios:
//   - En caliente, con "hyprctl eval" de la llamada a hl.config().
//   - Para el siguiente arranque, en ~/.config/hypr/<name>.lua (fuera del repo, generado
//     aquí). hyprland.lua carga ese archivo con dofile() si existe (ver loadIfExists allí),
//     y como es una llamada a hl.config() con solo estas claves, no toca el resto.
// No se usa "hyprctl reload": recargaría todo hyprland.lua y desharía lo que se ha cambiado
// en caliente desde fuera (el mirror de Super+M...).
//
// Quien lo usa da "name" y "generator" y llama a sync() con las tablas de hl.config() en
// una línea ("general = {...}, misc = {...}"). Se le pasan al llamar, y no como una
// propiedad enlazada, para que siempre sean las del momento: en Theme.qml se llama justo al
// cambiar de tema, cuando las propiedades derivadas puede que aún no se hayan actualizado.
import Quickshell
import Quickshell.Io
import QtQuick

FileView {
    id: root

    required property string name           // "shellTheme" -> ~/.config/hypr/shellTheme.lua
    required property string generator      // Quién lo genera, para el aviso de la primera línea

    path: Quickshell.env("HOME") + "/.config/hypr/" + name + ".lua"
    atomicWrites: true
    blockLoading: true                      // Para que text() devuelva ya el contenido actual al arrancar

    // Si el archivo ya tiene esto no se hace nada: es lo que pasa en casi todos los
    // arranques de Quickshell, y Hyprland ya lo cargó al arrancar
    function sync(config) {
        const call = "hl.config({ " + config + " })"
        const content = "-- Generado por " + generator + " (quickshell). No editar a mano: se sobrescribe.\n" + call + "\n"
        if (root.text() === content) return
        root.setText(content)                                   // Para el siguiente arranque de Hyprland
        Quickshell.execDetached(["hyprctl", "eval", call])      // En caliente
    }
}
