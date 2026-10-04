// NotificationList.qml
// Lista de notificaciones del popup de SystemStats.qml (en esta misma carpeta), debajo del
// uso del sistema. El estado está en services/NotificationCenter.qml; aquí solo se pinta.
//   - Activas: las que no se han descartado, aunque ya no estén en pantalla (al acabar su
//     tiempo solo se ocultan). Con sus botones de acción. Clic izquierdo: la acción
//     principal de la app (si no tiene, la descarta); clic derecho o la ✕: descartarla.
//   - Descartadas: las últimas que se han cerrado, solo para leerlas (ya no tienen
//     acciones). Solo en memoria: al reiniciar o recargar Quickshell se vacía. Clic
//     derecho o la ✕: quitarla de la lista.
import QtQuick
import QtQuick.Layouts
import qs.components                // NotificationCard (la misma que las tarjetas emergentes) y TextButton
import qs.services

ColumnLayout {
    id: root
    spacing: 4

    signal actionInvoked()              // Se ha lanzado la acción principal de una: quien la contiene puede cerrarse

    readonly property int count: NotificationCenter.active.length

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
        TextButton {
            text: header.action
            color: hovered ? Theme.textSelected : Theme.textDisabled
            font.pixelSize: 11
            onClicked: header.triggered()
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
        delegate: NotificationCard {
            required property var modelData
            Layout.fillWidth: true
            compact: true
            notification: modelData
            time: NotificationCenter.arrivals[modelData.id] ?? 0
            onActivated: root.actionInvoked()
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
        delegate: NotificationCard {                            // Copias: sin "notification", ni acciones ni clic izquierdo
            required property var modelData
            Layout.fillWidth: true
            compact: true
            dimmed: true
            entry: modelData
            time: modelData.time
            onCloseRequested: NotificationCenter.removeFromHistory(modelData)
        }
    }
}
