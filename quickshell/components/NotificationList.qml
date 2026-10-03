// NotificationList.qml
// Lista de notificaciones del popup de SystemStats (bar/SystemStats.qml), debajo del uso
// del sistema. El estado está en services/NotificationCenter.qml; aquí solo se pinta.
//   - Activas: las que no se han descartado, aunque ya no estén en pantalla (al acabar su
//     tiempo solo se ocultan). Con sus botones de acción. Clic izquierdo: la acción
//     principal de la app (si no tiene, la descarta); clic derecho o la ✕: descartarla.
//   - Descartadas: las últimas que se han cerrado, solo para leerlas (ya no tienen
//     acciones). Solo en memoria: al reiniciar o recargar Quickshell se vacía. Clic
//     derecho o la ✕: quitarla de la lista.
import Quickshell
import Quickshell.Services.Notifications   // Para NotificationUrgency
import QtQuick
import QtQuick.Layouts
import qs.services

ColumnLayout {
    id: root
    spacing: 4

    signal actionInvoked()              // Se ha lanzado la acción principal de una: quien la contiene puede cerrarse

    readonly property int count: NotificationCenter.active.length

    // "14:05" si es de hoy; si no, también el día ("2/10 14:05"). 0 = no se sabe: sin hora.
    function formatTime(ms) {
        if (!ms) return ""
        const date = new Date(ms)
        const time = Qt.formatTime(date, "HH:mm")
        return date.toDateString() === new Date().toDateString() ? time : Qt.formatDate(date, "d/M") + " " + time
    }

    // Fila de una notificación, activa o del historial. Con "notification" (las activas)
    // pinta también los botones de acción.
    component NotificationRow: Rectangle {
        id: row

        property var notification: null
        property string appName: ""
        property string appIcon: ""
        property string desktopEntry: ""
        property string image: ""
        property string summary: ""
        property string body: ""
        property bool critical: false
        property real time: 0
        property bool dimmed: false                     // Del historial: en gris, que se vea que ya no está activa
        signal clicked()
        signal closeRequested()

        Layout.fillWidth: true
        implicitHeight: rowLayout.implicitHeight + 12
        radius: 6
        color: rowHover.hovered ? Theme.surfaceHover : "transparent"
        border.width: critical && !dimmed ? 1 : 0       // Las críticas, con el borde rojo como en las tarjetas emergentes
        border.color: Theme.error

        HoverHandler { id: rowHover }                   // HoverHandler y no MouseArea: se entera también con el ratón sobre los botones

        // Va antes que el contenido para quedar por debajo: si no, se tragaría los clics de los botones
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: event => event.button === Qt.LeftButton ? row.clicked() : row.closeRequested()
        }

        RowLayout {
            id: rowLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            spacing: 8

            NotificationIcon {                          // La imagen de la app o, si ya no existe, el icono de la app
                size: row.dimmed ? 20 : 28
                Layout.alignment: Qt.AlignTop
                opacity: row.dimmed ? 0.6 : 1
                image: row.image
                appIcon: row.appIcon
                desktopEntry: row.desktopEntry
                appName: row.appName
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {                             // App · hora, y la ✕ a la derecha
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        Layout.fillWidth: true
                        text: [row.appName, root.formatTime(row.time)].filter(s => s !== "").join("  ·  ")
                        textFormat: Text.PlainText      // Viene de la app: que no se interprete como HTML
                        color: Theme.textDisabled
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                    Text {
                        text: "✕"
                        color: closeMouse.containsMouse ? Theme.textSelected : Theme.textDisabled
                        font.pixelSize: 11
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            anchors.margins: -4         // Zona de clic algo más grande que el dibujo
                            hoverEnabled: true
                            onClicked: row.closeRequested()
                        }
                    }
                }
                Text {                                  // Título
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: row.summary
                    textFormat: Text.PlainText
                    color: row.dimmed ? Theme.textDisabled : Theme.textSelected
                    font.bold: true
                    wrapMode: Text.WordWrap
                }
                Text {                                  // Mensaje
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: row.body
                    textFormat: Text.PlainText
                    color: row.dimmed ? Theme.textDisabled : Theme.textActive
                    wrapMode: Text.WordWrap
                    maximumLineCount: row.dimmed ? 2 : 5    // Aquí caben menos que en las tarjetas: el resto, cortado
                    elide: Text.ElideRight
                }
                NotificationActions {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    notification: row.notification
                }
            }
        }
    }

    // Cabecera de cada sección: título y, a la derecha, un enlace para vaciarla
    component SectionHeader: RowLayout {
        id: header
        property string title: ""
        property string action: ""
        signal triggered()

        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        Text {
            Layout.fillWidth: true
            text: header.title
            color: Theme.textActive
            font.bold: true
        }
        Text {
            text: header.action
            color: actionMouse.containsMouse ? Theme.textSelected : Theme.textDisabled
            font.pixelSize: 11
            MouseArea {
                id: actionMouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                onClicked: header.triggered()
            }
        }
    }

    SectionHeader {
        title: "Notificaciones"
        action: root.count > 0 ? "Descartar todas" : ""
        onTriggered: NotificationCenter.dismissAll()
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        visible: root.count === 0
        text: NotificationCenter.history.length > 0 ? "Ninguna activa" : "No hay notificaciones"
        color: Theme.textDisabled
        font.pixelSize: 11
    }

    Repeater {
        model: NotificationCenter.active.slice().reverse()     // La más reciente arriba
        delegate: NotificationRow {
            required property var modelData
            notification: modelData
            appName: modelData.appName
            appIcon: modelData.appIcon
            desktopEntry: modelData.desktopEntry
            image: modelData.image
            summary: modelData.summary
            body: modelData.body
            critical: modelData.urgency === NotificationUrgency.Critical
            time: NotificationCenter.arrivals[modelData.id] ?? 0
            onClicked: {
                const action = modelData.actions.find(a => a.identifier === "default")
                if (action) {
                    root.actionInvoked()            // Suele abrir o traer al frente una ventana: el popup se cierra para no taparla
                    action.invoke()                 // La cierra sola, salvo que la app pida que se quede
                } else modelData.dismiss()          // Sin acción, como en las tarjetas: solo cerrarla
            }
            onCloseRequested: modelData.dismiss()
        }
    }

    SectionHeader {
        visible: NotificationCenter.history.length > 0
        Layout.topMargin: 8
        title: "Descartadas"
        action: "Borrar"
        onTriggered: NotificationCenter.clearHistory()
    }

    Repeater {
        model: NotificationCenter.history
        delegate: NotificationRow {
            required property var modelData
            dimmed: true
            appName: modelData.appName
            appIcon: modelData.appIcon
            desktopEntry: modelData.desktopEntry
            image: modelData.image
            summary: modelData.summary
            body: modelData.body
            critical: modelData.critical
            time: modelData.time
            onCloseRequested: NotificationCenter.removeFromHistory(modelData)
        }
    }
}
