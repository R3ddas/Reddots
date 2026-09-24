// Icono en la barra + popup para editar en caliente las medidas de Geometry.qml
// (ancho de la barra lateral, grosor y redondeo del borde) y las de
// HyprGeometry.qml (gaps y borde/redondeo de ventana, que vive en Hyprland).
// Los cambios de Geometry se aplican al momento (Border.qml y shell.qml están
// enlazados a Geometry); los de HyprGeometry se aplican con "hyprctl reload".
// Ambos se guardan solos en disco gracias a sus respectivos FileView.
import Quickshell
import Quickshell.Hyprland   // Para el HyprlandFocusGrab
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 6

    Text {
        id: iconText
        text: String.fromCodePoint(0xEEB0)
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
        anchor.rect.y: iconText.height + 8
        anchor.gravity: Edges.Bottom | Edges.Right  // Sin "Right" el popup se centra en el punto de anclaje y vuelve a tapar la barra
        anchor.onAnchoring: anchor.rect.y = Geometry.popupY(iconText, anchor.rect.x, implicitHeight, iconText.height + 8)  // Si no cabe debajo, lo sube para dejar abajo el mismo hueco que a la izquierda

        implicitWidth: 220
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
                spacing: 10

                // Una fila por cada entrada de Geometry.editable +
                // HyprGeometry.editable: etiqueta + stepper (-/valor/+) que
                // lee y escribe la propiedad por nombre en su singleton
                // (modelData.target[modelData.key]).
                Repeater {
                    model: Geometry.editable.concat(HyprGeometry.editable)

                    delegate: ColumnLayout {
                        id: row
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: row.modelData.label
                            color: Theme.textActive
                            font.pixelSize: 11
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                implicitWidth: 22
                                implicitHeight: 22
                                radius: 4
                                color: minusMouse.containsMouse ? Theme.surfaceHover : "transparent"
                                border.color: Theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text: "−"
                                    color: Theme.textActive
                                }

                                MouseArea {
                                    id: minusMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: row.modelData.target[row.modelData.key] = Math.max(row.modelData.min, row.modelData.target[row.modelData.key] - row.modelData.step)
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: row.modelData.target[row.modelData.key] + "px"
                                color: Theme.textActive
                            }

                            Rectangle {
                                implicitWidth: 22
                                implicitHeight: 22
                                radius: 4
                                color: plusMouse.containsMouse ? Theme.surfaceHover : "transparent"
                                border.color: Theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    color: Theme.textActive
                                }

                                MouseArea {
                                    id: plusMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: row.modelData.target[row.modelData.key] = Math.min(row.modelData.max, row.modelData.target[row.modelData.key] + row.modelData.step)
                                }
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
