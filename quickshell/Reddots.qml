// Icono en la barra + popup con lo relativo al propio repo Reddots:
//   - Atajos de teclado: abre la chuleta (Keybinds.qml). Este archivo solo avisa con
//     keybindsRequested(); quién la abre lo decide shell.qml.
//   - Actualizar Reddots: baja los cambios del repo (git pull) y ejecuta install.sh, en
//     un Alacritty para que sudo pueda pedir la contraseña y paru hacer sus preguntas.
//     El trabajo lo hace scripts/update-reddots.sh; esto solo lo lanza.
// Va dentro del grupo del engranaje (SettingsToggle) y con un paso más (el popup)
// para no lanzar sin querer una actualización de todo el sistema.
import Quickshell
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 6

    signal keybindsRequested()      // Se ha pulsado "Atajos de teclado"

    BarIcon {
        id: iconText
        text: String.fromCodePoint(0xF06B0)  // update
        tooltip: menu.visible ? "" : "Reddots: atajos de teclado y actualizar"
        onClicked: menu.toggle()
    }

    BarPopup {
        id: menu
        anchorItem: iconText
        implicitWidth: 240
        implicitHeight: listCol.implicitHeight + 16

        ColumnLayout {
            id: listCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            // Una fila por opción, como en Power.qml: icono, texto, qué hace al pulsarla
            // y, si hace falta, un aviso debajo de lo que va a pasar ("hint")
            Repeater {
                model: [
                    { icon: 0xF030C, label: "Atajos de teclado",  run: () => root.keybindsRequested() },     // keyboard
                    { icon: 0xF06B0, label: "Actualizar Reddots",                                             // update
                      hint: "Baja los cambios del repo y ejecuta install.sh en un terminal. Actualiza todo el sistema y pide la contraseña.",
                      run: () => Quickshell.execDetached(["alacritty", "--title", "Actualizar Reddots", "-e",
                                    Quickshell.shellPath("scripts/update-reddots.sh")]) }
                ]

                delegate: MenuRow {
                    required property var modelData
                    icon: String.fromCodePoint(modelData.icon)
                    text: modelData.label
                    hint: modelData.hint ?? ""
                    onClicked: {
                        menu.visible = false
                        modelData.run()
                    }
                }
            }
        }
    }
}
