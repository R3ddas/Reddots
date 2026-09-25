// Recursos: https://www.youtube.com/watch?v=Vlpyz4c4Xdw

import Quickshell
import QtQuick
import QtQuick.Layouts      // Para usar RowLayout o ColumnLayout

ColumnLayout{
    id: root
    property bool showDate: false   // Se alterna con click derecho sobre la hora

    onShowDateChanged: if (!showDate) menu.visible = false   // Si se oculta la fecha, el calendario también

    Text{
        id: timeText
        text: Qt.formatDateTime(clock.date, "hh\nmm")
        color: Theme.textActive
        font.pixelSize: 15
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        Layout.alignment: Qt.AlignHCenter

        MouseArea{
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true                                  // Para el tooltip con la fecha completa
            acceptedButtons: Qt.RightButton
            onContainsMouseChanged: dateTooltip.active = containsMouse
            onClicked: {
                dateTooltip.active = false
                root.showDate = !root.showDate
            }
        }

        LazyLoader {                                            // "jueves, 25 de septiembre de 2026" al dejar el ratón encima de la hora
            id: dateTooltip
            active: false
            BarTooltip {
                anchorItem: timeText
                text: menu.visible ? "" : Qt.locale("es_ES").toString(clock.date, "dddd, d 'de' MMMM 'de' yyyy")
                hovered: true
            }
        }
    }

    Text{
        id: dateText
        visible: root.showDate
        text: Qt.formatDateTime(clock.date, "dd\nMM")
        color: menu.visible ? Theme.textSelected : Theme.textDisabled   // Con el color de acento mientras el calendario está abierto
        font.pixelSize: 11
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        Layout.alignment: Qt.AlignHCenter

        MouseArea{
            anchors.fill: parent
            anchors.margins: -4
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: event => {
                if (event.button === Qt.LeftButton) menu.visible = !menu.visible   // Izquierdo: abre/cierra el calendario
                else root.showDate = !root.showDate                                 // Derecho: oculta la fecha, como en la hora
            }
        }
    }

    SystemClock{
        id:clock
        precision: SystemClock.Minutes      // Sólo lo actualizo cada minuto porque no me interesan los segundos
    }

    // --- Calendario -----------------------------------------------------------
    // Hecho a mano (en vez del MonthGrid de QtQuick.Controls) para que use los
    // colores del tema igual que el resto de desplegables.
    BarPopup {
        id: menu
        anchorItem: dateText
        property int viewYear: 0            // Mes que se está viendo (se cambia con las flechas o la rueda)
        property int viewMonth: 0           // 0 = enero

        function goToToday() {
            viewYear = clock.date.getFullYear()
            viewMonth = clock.date.getMonth()
        }

        function moveMonth(delta) {
            const d = new Date(viewYear, viewMonth + delta, 1)   // Date ya se encarga de pasar de diciembre a enero
            viewYear = d.getFullYear()
            viewMonth = d.getMonth()
        }

        // Número de semana ISO 8601 de un lunes: la semana 1 es la que tiene el primer
        // jueves del año, así que se cuenta a partir del jueves de esa semana (lunes + 3).
        // En UTC para que el cambio de hora de marzo/octubre no descuadre la división.
        function isoWeek(monday) {
            const thursday = Date.UTC(monday.getFullYear(), monday.getMonth(), monday.getDate() + 3)
            const yearStart = Date.UTC(new Date(thursday).getUTCFullYear(), 0, 1)
            return Math.floor((thursday - yearStart) / 86400000 / 7) + 1
        }

        // Los 42 días (6 semanas) que se pintan, empezando en el lunes de la semana del día 1
        readonly property var days: {
            const offset = (new Date(viewYear, viewMonth, 1).getDay() + 6) % 7   // getDay(): 0 = domingo -> lunes = 0
            const list = []
            for (let i = 0; i < 42; i++) list.push(new Date(viewYear, viewMonth, 1 - offset + i))
            return list
        }


        implicitWidth: calCol.implicitWidth + 16
        implicitHeight: calCol.implicitHeight + 16

        onVisibleChanged: if (visible) goToToday()   // Siempre abre en el mes actual

        MouseArea {                                     // La rueda en cualquier parte del calendario cambia de mes
            anchors.fill: parent
            onWheel: wheel => menu.moveMonth(wheel.angleDelta.y > 0 ? -1 : 1)
        }

        ColumnLayout {
            id: calCol
            anchors.centerIn: parent
            spacing: 6

            RowLayout {                                 // Cabecera: ‹  septiembre 2026  ›
                Layout.fillWidth: true

                Text {
                    text: "‹"
                    color: Theme.textActive
                    font.pixelSize: 16
                    Layout.preferredWidth: 20
                    horizontalAlignment: Text.AlignHCenter
                    MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: menu.moveMonth(-1) }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: {
                        const name = Qt.locale("es_ES").standaloneMonthName(menu.viewMonth)
                        return name.charAt(0).toUpperCase() + name.slice(1) + " " + menu.viewYear
                    }
                    color: Theme.textSelected
                    font.bold: true
                    MouseArea { anchors.fill: parent; onClicked: menu.goToToday() }   // Clic en el título: vuelve al mes actual
                }

                Text {
                    text: "›"
                    color: Theme.textActive
                    font.pixelSize: 16
                    Layout.preferredWidth: 20
                    horizontalAlignment: Text.AlignHCenter
                    MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: menu.moveMonth(1) }
                }
            }

            RowLayout {                                 // Números de semana | separador | días
                spacing: 6

                // Columna con el número de semana ISO 8601 (el que se usa en España).
                // Mismas alturas y separación que las filas de los días para que
                // cada número quede alineado con su semana.
                ColumnLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignTop

                    Item { Layout.preferredHeight: 16 }     // Hueco a la altura de las iniciales de los días

                    Repeater {
                        model: 6                            // Una por fila de días
                        delegate: Text {
                            required property int index
                            text: menu.isoWeek(menu.days[index * 7])   // El lunes de esa fila
                            color: Theme.textDisabled
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 24
                        }
                    }
                }

                Rectangle {                                 // Barra vertical que separa las semanas de los días
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    color: Theme.border
                }

                GridLayout {
                    columns: 7
                    columnSpacing: 2
                    rowSpacing: 2

                    Repeater {                              // Iniciales de los días, empezando en lunes
                        model: ["L", "M", "X", "J", "V", "S", "D"]
                        delegate: Text {
                            required property string modelData
                            text: modelData
                            color: Theme.textDisabled
                            font.pixelSize: 10
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 16      // Fija, para que la columna de semanas pueda alinearse
                        }
                    }

                    Repeater {
                        model: menu.days
                        delegate: Rectangle {
                            id: dayCell
                            required property var modelData
                            readonly property bool inMonth: modelData.getMonth() === menu.viewMonth
                            readonly property bool isToday: modelData.toDateString() === clock.date.toDateString()

                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 24
                            radius: 6
                            color: isToday ? Theme.textSelected : "transparent"   // Hoy, relleno con el color de acento

                            Text {
                                anchors.centerIn: parent
                                text: dayCell.modelData.getDate()
                                color: dayCell.isToday ? Theme.surface
                                     : dayCell.inMonth ? Theme.textActive
                                     : Theme.textDisabled                            // Días del mes anterior/siguiente, apagados
                                font.pixelSize: 11
                                font.bold: dayCell.isToday
                            }
                        }
                    }
                }
            }
        }
    }
}
