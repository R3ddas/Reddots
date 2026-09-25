// Icono en la barra + popup para elegir el tema de color activo (Theme.qml).
// Cada fila muestra el nombre del tema y una muestra de sus colores; al
// pulsar una fila se aplica al momento y queda guardada (Theme.qml persiste
// activeTheme solo, igual que Geometry.qml con sus medidas).
import Quickshell
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 6

    BarIcon {
        id: iconText
        text: String.fromCodePoint(0xf195A)
        tooltip: menu.visible ? "" : "Tema: " + Theme.activeTheme
        onClicked: menu.toggle()
    }

    BarPopup {
        id: menu
        anchorItem: iconText

        implicitWidth: 220
        implicitHeight: Math.min(360, listCol.implicitHeight + 16)

        // Flickable en vez de Repeater suelto porque hay 35 temas: con
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

                // Dos secciones, Claros y Oscuros (según el fondo del tema, ver Theme.isLight()),
                // cada una con los temas en el orden de Theme.qml
                Repeater {
                    model: [{ title: "Claros", light: true }, { title: "Oscuros", light: false }]

                    delegate: ColumnLayout {
                        id: section
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.topMargin: index > 0 ? 8 : 0     // Aire antes de la segunda sección
                        spacing: 2

                        Text {                                  // Título de la sección, como en la chuleta de atajos
                            text: section.modelData.title
                            color: Theme.textSelected
                            font.pixelSize: 11
                            font.bold: true
                            Layout.leftMargin: 6
                        }

                        Rectangle {                             // Línea bajo el título
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Theme.border
                            Layout.bottomMargin: 2
                        }

                        Repeater {
                            model: Theme.themes.filter(t => Theme.isLight(t) === section.modelData.light)

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

                                    // Muestra de colores del tema: fondo, acento, rojo, verde y azul
                                    Row {
                                        spacing: 2
                                        Repeater {
                                            model: [
                                                themeRow.modelData.base[0],                         // base00: fondo
                                                Theme.roles(themeRow.modelData).textSelected,       // El acento del tema
                                                themeRow.modelData.base[8],                         // base08: rojo
                                                themeRow.modelData.base[11],                        // base0B: verde
                                                themeRow.modelData.base[13]                         // base0D: azul
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
                                        text: themeRow.modelData.name.replace(/ (Claro|Oscuro)$/, "")   // Sin "Claro"/"Oscuro": ya lo dice la sección ("Ayu Mirage" se queda igual)
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
    }
}
