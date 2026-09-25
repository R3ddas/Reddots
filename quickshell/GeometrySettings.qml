// Icono en la barra + popup para editar en caliente las medidas de Geometry.qml
// (ancho de la barra lateral, grosor y redondeo del borde) y las de
// HyprGeometry.qml (gaps y borde/redondeo de ventana, que vive en Hyprland).
// Los cambios de Geometry se aplican al momento (Border.qml y shell.qml están
// enlazados a Geometry); los de HyprGeometry se aplican en caliente con "hyprctl eval".
// Ambos se guardan solos en disco gracias a sus respectivos FileView.
import Quickshell
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 6

    BarIcon {
        id: iconText
        text: String.fromCodePoint(0xEEB0)
        tooltip: menu.visible ? "" : "Medidas de la barra y las ventanas"
        onClicked: menu.toggle()
    }

    BarPopup {
        id: menu
        anchorItem: iconText

        implicitWidth: 220
        implicitHeight: listCol.implicitHeight + 16

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
