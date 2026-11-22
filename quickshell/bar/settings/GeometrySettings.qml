// Icono en la barra + popup para editar en caliente las medidas de Geometry.qml: las de
// Quickshell (ancho de la barra lateral; grosor, redondeo y sombra del borde; desplegables)
// y las de las ventanas, que vive Hyprland (gaps, borde, redondeo, opacidad y wobble). Las primeras
// se aplican al momento (Border.qml, Bar.qml y los desplegables están enlazados a Geometry)
// y las de Hyprland en caliente con "hyprctl eval". Todas se guardan solas en disco.
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

    // Botón − o + de una fila: suma "delta" a la medida, sin pasarse de su mínimo ni de su máximo
    component StepButton: Button {
        required property var entry         // La entrada de Geometry.editable de esa fila
        property int delta: 0
        implicitWidth: 22
        implicitHeight: 22
        radius: 4
        onClicked: Geometry[entry.key] = Math.max(entry.min, Math.min(entry.max, Geometry[entry.key] + delta))
    }

    BarIcon {
        id: iconText
        text: String.fromCodePoint(0xEEB0)   // shapes (de Font Awesome)
        tooltip: Lang.tr("Medidas de la barra y las ventanas")
        popup: menu
    }

    BarPopup {
        id: menu
        anchorItem: iconText
        implicitWidth: 260                  // Etiqueta y stepper en la misma línea
        spacing: 16                         // Entre secciones: más que entre filas, para que se vea dónde empieza cada una

        // Las entradas de Geometry.editable, agrupadas por su "group" en secciones, en el
        // orden en que aparecen (ver Geometry.qml)
        Repeater {
            model: {
                const sections = []
                for (const entry of Geometry.editable) {
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
                    text: Lang.tr(section.modelData.title)        // Los nombres de Geometry.editable van en español
                    font.pixelSize: 11
                    spacing: 6
                }

                // Una fila por entrada: etiqueta + stepper (-/valor/+) que lee y
                // escribe la propiedad de Geometry por su nombre (Geometry[modelData.key]).
                Repeater {
                    model: section.modelData.entries

                    // Todo en una línea: la etiqueta a la izquierda (se come el sitio que
                    // sobre) y el stepper pegado a la derecha
                    delegate: RowLayout {
                        id: row
                        required property var modelData
                        readonly property bool isToggle: modelData.toggle === true

                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: Lang.tr(row.modelData.label)
                            color: Theme.textActive
                            font.pixelSize: 11
                            elide: Text.ElideRight              // Por si una etiqueta nueva no cabe: que no empuje al stepper
                        }

                        StepButton { visible: !row.isToggle; text: "−"; delta: -(row.modelData.step ?? 0); entry: row.modelData }

                        Text {
                            visible: !row.isToggle
                            Layout.preferredWidth: 40           // Ancho fijo (cabe "100%"): así los steppers de todas las filas quedan en columna
                            horizontalAlignment: Text.AlignHCenter
                            text: Geometry[row.modelData.key] + (row.modelData.unit ?? "px")   // Unidad opcional de la entrada (p.ej. "%")
                            color: Theme.textActive
                        }

                        StepButton { visible: !row.isToggle; text: "+"; delta: row.modelData.step ?? 0; entry: row.modelData }

                        // Entradas sí/no ("toggle" en Geometry.editable): un botón que la cambia,
                        // del ancho del stepper (− 22, valor 40, + 22 y los dos huecos) para que
                        // quede en la misma columna. Resaltado cuando está en "sí"
                        Button {
                            visible: row.isToggle
                            Layout.preferredWidth: 22 * 2 + 40 + 6 * 2
                            implicitHeight: 22
                            radius: 4
                            accent: !!Geometry[row.modelData.key]
                            text: Lang.tr(Geometry[row.modelData.key] ? "Sí" : "No")
                            onClicked: Geometry[row.modelData.key] = !Geometry[row.modelData.key]
                        }
                    }
                }
            }
        }
    }
}
