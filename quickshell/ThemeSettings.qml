// Icono en la barra + popup para elegir el tema de color activo (Theme.qml).
// Cada fila muestra el nombre del tema y una muestra de sus colores; al
// pulsar una fila se aplica al momento y queda guardada (Theme.qml persiste
// activeTheme solo, igual que Geometry.qml con sus medidas).
import Quickshell
import Quickshell.Hyprland   // Para el HyprlandFocusGrab
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 6

    Text {
        id: iconText
        text: String.fromCodePoint(0xF08B5)  // palette-swatch
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
        anchor.rect.x: Geometry.sidebarWidth - iconText.mapToItem(null, 0, 0).x  // Que el menú no tape la barra, aparece a partir de su borde derecho
        anchor.rect.y: iconText.height + 8
        anchor.gravity: Edges.Bottom

        implicitWidth: 220
        implicitHeight: Math.min(360, listCol.implicitHeight + 16)

        onVisibleChanged: {
            if (visible) grabTimer.restart()
            else { grabTimer.stop(); grab.active = false }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.surface
            radius: 8
            border.color: Theme.border

            // Flickable en vez de Repeater suelto porque hay ~30 temas: con
            // todos desplegados no cabrían en pantalla, así que se recorta a
            // 360px y se puede hacer scroll con la rueda del ratón.
            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                contentWidth: width
                contentHeight: listCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: listCol
                    width: flick.width
                    spacing: 2

                    Repeater {
                        model: Theme.themes

                        delegate: Rectangle {
                            id: themeRow
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: 30
                            radius: 4
                            color: rowMouse.containsMouse ? Theme.surfaceHover : "transparent"
                            border.width: themeRow.modelData.name === Theme.activeTheme ? 1 : 0
                            border.color: Theme.textSelected

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 6

                                // Muestra de colores del tema: fondo, seleccionado y los 3 acentos
                                Row {
                                    spacing: 2
                                    Repeater {
                                        model: [
                                            themeRow.modelData.background,
                                            themeRow.modelData.textSelected,
                                            themeRow.modelData.extra1,
                                            themeRow.modelData.extra2,
                                            themeRow.modelData.extra3
                                        ]
                                        delegate: Rectangle {
                                            width: 12
                                            height: 12
                                            radius: 3
                                            color: modelData
                                            border.width: 1
                                            border.color: Theme.border
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: themeRow.modelData.name
                                    color: Theme.textActive
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: themeRow.modelData.name === Theme.activeTheme
                                    text: "✓"
                                    color: Theme.textSelected
                                    font.pixelSize: 11
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Theme.activeTheme = themeRow.modelData.name
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
