// Icono de apagado, abre un menú para apagar, reiniciar o suspender el equipo

import Quickshell          // También para lanzar systemctl (execDetached)
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 6

    BarIcon {
        id: iconText
        text: String.fromCodePoint(0xF0425)  // power
        font.pixelSize: 20
        tooltip: menu.visible ? "" : "Apagar, reiniciar o suspender"
        onClicked: menu.toggle()
    }

    BarPopup {
        id: menu
        anchorItem: iconText                // A la altura del icono; como está al final de la barra, en la práctica queda pegado abajo
        implicitWidth: 170
        implicitHeight: listCol.implicitHeight + 16

        ColumnLayout {
            id: listCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            // Una fila por opción: icono, texto y qué hace al pulsarla
            Repeater {
                model: [
                    { icon: 0xF0425, label: "Apagar",         run: () => Quickshell.execDetached(["systemctl", "poweroff"]) },  // power
                    { icon: 0xF0709, label: "Reiniciar",      run: () => Quickshell.execDetached(["systemctl", "reboot"]) },    // restart
                    { icon: 0xF0904, label: "Suspender",      run: () => Quickshell.execDetached(["systemctl", "suspend"]) },   // power-sleep
                    { icon: 0xF0379, label: "Salvapantallas", run: () => root.launchScreensaver() }                            // monitor
                ]

                delegate: MenuRow {
                    required property var modelData
                    icon: String.fromCodePoint(modelData.icon)
                    text: modelData.label
                    onClicked: {
                        menu.visible = false
                        modelData.run()
                    }
                }
            }
        }
    }

    // Cambia aquí el comando si en el futuro quieres otro salvapantallas.
    // Lanza un Alacritty a pantalla completa por cada monitor conectado, usando el
    // dispatcher exec_cmd de Hyprland con la regla "monitor" para fijar cada uno a su pantalla
    // (Hyprland.dispatch() envía expresiones Lua porque este Hyprland usa hyprland.lua como config).
    function launchScreensaver() {
        // El "sleep" evita que cmatrix mida el tamaño del terminal antes de que Alacritty termine de pasar a pantalla completa (si no, se queda dibujando solo en el área pequeña inicial)
        // cmatrix -s se cierra solo al pulsar una tecla en SU terminal; en cuanto Alacritty termina (por eso, o por cierre manual)
        // el "pkill" mata los cmatrix de los demás monitores, lo que a su vez hace que sus Alacritty también se cierren
        const matrix = "cmatrix -bsu 10"    // Una sola vez: el pkill tiene que buscar exactamente lo mismo que se lanza (el -u es la velocidad)
        const cmd = `alacritty -o 'window.startup_mode="Fullscreen"' -e sh -c 'sleep 0.5 && exec ${matrix}'; pkill -f '${matrix}'`
        const escapedCmd = cmd.replace(/"/g, "\\\"")
        for (const mon of Hyprland.monitors.values) {
            Hyprland.dispatch(`hl.dsp.exec_cmd("${escapedCmd}", { monitor = "${mon.name}" })`)
        }
    }
}
