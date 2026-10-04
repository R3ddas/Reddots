// Icono en la barra + popup para editar en caliente las medidas de Geometry.qml
// (ancho de la barra lateral; grosor, redondeo, sombra y opacidad de la sombra del borde) y las de
// HyprGeometry.qml (gaps, borde/redondeo y opacidad de ventana, que viven en Hyprland).
// Los cambios de Geometry se aplican al momento (Border.qml, Bar.qml y los desplegables
// están enlazados a Geometry); los de HyprGeometry se aplican en caliente con "hyprctl eval".
// Ambos se guardan solos en disco gracias a sus respectivos FileView.
// Las opciones salen agrupadas por lo que tocan (barra lateral, borde de la pantalla,
// desplegables, ventanas): cada entrada dice su sección con "group".
import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

ColumnLayout {
    id: root
    spacing: 6

    BarIcon {
        id: iconText
        text: String.fromCodePoint(0xEEB0)
        tooltip: "Medidas de la barra y las ventanas"
        popup: menu
    }

    BarPopup {
        id: menu
        anchorItem: iconText
        implicitWidth: 260                  // Etiqueta y stepper en la misma línea
        spacing: 16                         // Entre secciones: más que entre filas, para que se vea dónde empieza cada una

        // Las entradas de Geometry.editable + HyprGeometry.editable, agrupadas por su
        // "group" en secciones, en el orden en que aparecen (ver Geometry.qml)
        Repeater {
            model: {
                const sections = []
                for (const entry of Geometry.editable.concat(HyprGeometry.editable)) {
                    let section = sections.find(s => s.title === entry.group)
                    if (!section) sections.push(section = { title: entry.group, entries: [] })
                    section.entries.push(entry)
                }
                return sections
            }

            delegate: ColumnLayout {
                id: section
                required property var modelData
                Layout.fillWidth: true
                spacing: 6

                SectionTitle {                          // Título de la sección, como Claros/Oscuros en ThemeSettings.qml
                    text: section.modelData.title
                    font.pixelSize: 11
                    spacing: 6
                }

                // Una fila por entrada: etiqueta + stepper (-/valor/+) que lee y
                // escribe la propiedad por nombre en su singleton
                // (modelData.target[modelData.key]).
                Repeater {
                    model: section.modelData.entries

                    // Todo en una línea: la etiqueta a la izquierda (se come el sitio que
                    // sobre) y el stepper pegado a la derecha
                    delegate: RowLayout {
                        id: row
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.label
                            color: Theme.textActive
                            font.pixelSize: 11
                            elide: Text.ElideRight              // Por si una etiqueta nueva no cabe: que no empuje al stepper
                        }

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
                            Layout.preferredWidth: 40           // Ancho fijo (cabe "100%"): así los steppers de todas las filas quedan en columna
                            horizontalAlignment: Text.AlignHCenter
                            text: row.modelData.target[row.modelData.key] + (row.modelData.unit ?? "px")   // Unidad opcional de la entrada (p.ej. "%")
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
