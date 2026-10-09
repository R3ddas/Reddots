// Una notificación: icono, título, mensaje y botones de acción. La usan las tarjetas
// emergentes (windows/Notifications.qml) y la lista del popup de SystemStats
// (bar/settings/NotificationList.qml, con compact: true: más pequeña, con la app y la hora
// encima y una ✕ para cerrarla).
//   Clic izquierdo: la acción principal de la app ("default", p.ej. abrir el chat de Teams):
//     avisa con activated() y la lanza; si no tiene, pide cerrarla. En las del historial
//     (sin "notification") no hace nada: ya no tienen acciones.
//   Clic derecho o la ✕: pide cerrarla con closeRequested(). Cerrarla de verdad lo decide
//     quien la usa (descartar una activa o quitarla del historial).
//
// "entry" es de donde salen los datos: la propia notificación o, en el historial, la copia
// que guarda NotificationCenter.qml con los mismos nombres (appName, summary, urgency...).
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications   // Para NotificationUrgency
import qs.services

Rectangle {
    id: root

    property var notification: null         // La notificación activa (null en las del historial)
    property var entry: notification
    property bool compact: false
    property bool dimmed: false             // Del historial: en gris, que se vea que ya no está activa
    property real time: 0                   // Hora de llegada (ms), para la cabecera de la lista
    readonly property bool hovered: hover.hovered
    readonly property bool critical: entry ? entry.urgency === NotificationUrgency.Critical : false
    signal activated()
    signal closeRequested()

    // "14:05" si es de hoy; si no, también el día ("2/10 14:05"). 0 = no se sabe: sin hora.
    function formatTime(ms) {
        if (!ms) return ""
        const date = new Date(ms)
        const time = Qt.formatTime(date, "HH:mm")
        return date.toDateString() === new Date().toDateString() ? time : Qt.formatDate(date, "d/M") + " " + time
    }

    implicitHeight: content.implicitHeight + (compact ? 12 : 20)
    radius: compact ? 6 : 8
    // Tarjeta: con el fondo del tema y un borde de 2 px (rojo si es crítica). En la lista:
    // transparente, resaltada con el ratón encima, y con borde solo si es crítica
    color: compact ? (hovered ? Theme.surfaceHover : "transparent") : Theme.background
    border.width: compact ? (critical && !dimmed ? 1 : 0) : 2
    border.color: critical ? Theme.error : Theme.textSelected

    HoverHandler { id: hover }              // HoverHandler y no MouseArea: se entera también con el ratón sobre los botones

    // Va antes que el contenido para quedar por debajo: si no, se tragaría los clics de los botones
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton) { root.closeRequested(); return }
            if (!root.notification) return
            const action = root.notification.actions.find(a => a.identifier === "default")
            if (action) {
                root.activated()            // Suele abrir o traer al frente una ventana: quien la contiene puede cerrarse para no taparla
                action.invoke()             // La cierra sola, salvo que la app pida que se quede
            } else root.closeRequested()    // Sin acción: solo cerrarla
        }
    }

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.compact ? 6 : 10
        spacing: root.compact ? 8 : 10

        NotificationIcon {                  // La imagen de la app o, si no se puede abrir, el icono de la app
            size: !root.compact ? 36 : root.dimmed ? 20 : 28
            Layout.alignment: Qt.AlignTop
            opacity: root.dimmed ? 0.6 : 1
            image: root.entry.image
            appIcon: root.entry.appIcon
            desktopEntry: root.entry.desktopEntry
            appName: root.entry.appName
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: root.compact ? 1 : 2

            RowLayout {                     // Solo en la lista: app · hora, y la ✕ a la derecha
                visible: root.compact
                Layout.fillWidth: true
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: [root.entry.appName, root.formatTime(root.time)].filter(s => s !== "").join("  ·  ")
                    textFormat: Text.PlainText
                    color: Theme.textDisabled
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
                TextButton {
                    text: "✕"
                    color: hovered ? Theme.textSelected : Theme.textDisabled
                    font.pixelSize: 11
                    onClicked: root.closeRequested()
                }
            }

            // PlainText en el título y el mensaje: el texto viene de la app y no debe
            // interpretarse como HTML (como en PolkitDialog.qml). Sin esto Qt adivina si es
            // texto enriquecido y un "<" puede cambiar cómo se pinta. El servidor no anuncia
            // marcado (bodyMarkupSupported está a false), pero algunas apps lo mandan igual.
            Text {                          // Título
                Layout.fillWidth: true
                visible: text !== ""
                text: root.entry.summary
                textFormat: Text.PlainText
                color: root.dimmed ? Theme.textDisabled : Theme.textSelected
                font.bold: true
                wrapMode: Text.WordWrap
            }
            Text {                          // Mensaje: en la lista caben menos líneas que en las tarjetas; el resto, cortado
                Layout.fillWidth: true
                visible: text !== ""
                text: root.entry.body
                textFormat: Text.PlainText
                color: root.dimmed ? Theme.textDisabled : Theme.textActive
                wrapMode: Text.WordWrap
                maximumLineCount: !root.compact ? 8 : root.dimmed ? 2 : 5
                elide: Text.ElideRight
            }
            NotificationActions {           // Botones de las acciones (sin "notification", ninguno)
                Layout.fillWidth: true
                Layout.topMargin: root.compact ? 4 : 6
                notification: root.notification
            }
        }
    }
}
