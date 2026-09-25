// Icono en la barra + popup con lo relativo al propio repo Reddots:
//   - Atajos de teclado: abre la chuleta (Keybinds.qml). Este archivo solo avisa con
//     keybindsRequested(); quién la abre lo decide shell.qml.
//   - Actualizar Reddots: baja los cambios del repo (git pull) y ejecuta install.sh, en
//     un Alacritty para que sudo pueda pedir la contraseña y paru hacer sus preguntas.
//     El trabajo lo hace scripts/update-reddots.sh; esto solo lo lanza.
// Va dentro del grupo del engranaje (SettingsToggle) y con un paso más (el popup)
// para no lanzar sin querer una actualización de todo el sistema.
import Quickshell
import Quickshell.Hyprland          // Para el HyprlandFocusGrab
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 6

    signal keybindsRequested()      // Se ha pulsado "Atajos de teclado"

    Text {
        id: iconText
        text: String.fromCodePoint(0xF06B0)  // update
        color: Theme.textActive
        font.pixelSize: 18
        Layout.alignment: Qt.AlignHCenter

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            onClicked: menu.visible = !menu.visible
        }
    }

    PopupWindow {
        id: menu
        visible: false
        color: "transparent"

        anchor.item: iconText
        anchor.rect.x: Geometry.sidebarWidth // Que el menú no tape la barra, aparece a partir de su borde derecho
        anchor.gravity: Edges.Bottom | Edges.Right  // Sin "Right" el popup se centra en el punto de anclaje y vuelve a tapar la barra
        anchor.onAnchoring: anchor.rect.y = Geometry.popupY(iconText, anchor.rect.x, implicitHeight)  // A la altura del icono; si no cabe, se mueve lo justo para dejar el mismo hueco que a la izquierda

        implicitWidth: 240
        implicitHeight: listCol.implicitHeight + 16

        onVisibleChanged: {
            if (visible) grabTimer.restart()
            else { grabTimer.stop(); grab.active = false }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.surface
            radius: Geometry.popupRounding                  // Redondeo propio de los desplegables (editable en GeometrySettings)
            border.color: Theme.textSelected                // Borde con el color de acento del tema
            border.width: Geometry.popupBorderWidth         // Grosor editable en GeometrySettings

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
                                        Quickshell.env("HOME") + "/.config/quickshell/scripts/update-reddots.sh"]) }
                    ]

                    delegate: Rectangle {
                        id: row
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: rowCol.implicitHeight + 10
                        radius: 4
                        color: rowMouse.containsMouse ? Theme.surfaceHover : "transparent"

                        ColumnLayout {
                            id: rowCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 2

                            Item {
                                Layout.fillWidth: true
                                implicitHeight: 18

                                Text {
                                    text: String.fromCodePoint(row.modelData.icon)
                                    color: Theme.textActive
                                    font.pixelSize: 15
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: row.modelData.label
                                    color: Theme.textActive
                                    anchors.left: parent.left
                                    anchors.leftMargin: 28
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Text {                              // Aviso de qué va a pasar, antes de pulsar
                                visible: !!row.modelData.hint
                                text: row.modelData.hint ?? ""
                                color: Theme.textDisabled
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                Layout.leftMargin: 28           // Alineado con el texto, no con el icono
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                menu.visible = false
                                row.modelData.run()
                            }
                        }
                    }
                }
            }
        }
    }

    HyprlandFocusGrab {
        id: grab
        windows: [menu]
        active: false
        onCleared: menu.visible = false
    }

    Timer {
        id: grabTimer
        interval: 5
        onTriggered: grab.active = true
    }
}
