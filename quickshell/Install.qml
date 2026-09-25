// Icono en la barra + popup para actualizar Reddots: baja los cambios del repo
// (git pull) y ejecuta install.sh, en un Alacritty para que sudo pueda pedir la
// contraseña y paru hacer sus preguntas. El trabajo lo hace
// scripts/update-reddots.sh; esto solo lo lanza. Va dentro del grupo del
// engranaje (SettingsToggle) y con un paso más (el popup) para no lanzar sin
// querer una actualización de todo el sistema.
import Quickshell
import Quickshell.Hyprland          // Para el HyprlandFocusGrab
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 6

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
                spacing: 6

                Text {                                      // Qué va a pasar, antes de pulsar
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    text: "Baja los cambios del repo y ejecuta install.sh en un terminal. Actualiza todo el sistema y pide la contraseña."
                    color: Theme.textDisabled
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }

                Rectangle {                                 // Mismo estilo que las filas de Power.qml
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 4
                    color: runMouse.containsMouse ? Theme.surfaceHover : "transparent"

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8

                        Text {
                            text: String.fromCodePoint(0xF06B0)  // update
                            color: Theme.textActive
                            font.pixelSize: 15
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Actualizar Reddots"
                            color: Theme.textActive
                            anchors.left: parent.left
                            anchors.leftMargin: 28
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: runMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            menu.visible = false
                            Quickshell.execDetached(["alacritty", "--title", "Actualizar Reddots", "-e",
                                Quickshell.env("HOME") + "/.config/quickshell/scripts/update-reddots.sh"])
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
