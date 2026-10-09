// Notificaciones emergentes: tarjetas arriba a la derecha de la pantalla de la barra, una por
// notificación, con sus botones de acción. El servidor y el estado están en
// services/NotificationCenter.qml; aquí solo se pintan.
//   Clic izquierdo: la acción principal de la app si la tiene (si no, la cierra)
//   Clic derecho: la cierra
// Se ocultan solas a los 10 s (defaultTimeout) o al tiempo que pida la app. Las críticas no
// se ocultan solas; con el ratón encima, tampoco. Ocultarse no es cerrarse: siguen en el
// popup de SystemStats (bar/settings/SystemStats.qml) hasta que se descartan. Las
// transitorias sí se cierran.
// Como mucho se ven maxVisible a la vez (las más antiguas); el resto espera en cola, sin
// gastar su tiempo, y debajo sale un "+N más". Así una ráfaga (Teams...) no se sale de la
// pantalla.
//
// Para probarlas desde un terminal:
//   notify-send "Título" "Contenido"
//   notify-send -u critical "Título" "Contenido"          Crítica
//   notify-send -t 3000 "Título" "Contenido"              3 s en pantalla (-t 0: no se oculta)
//   notify-send -A si=Sí -A no=No "Título" "Contenido"    Con botones de acción
//   for i in $(seq 8); do notify-send "Prueba $i"; done   Una ráfaga (cola y "+N más")
//
// Recursos: https://www.youtube.com/watch?v=leCzeCeNxas&t=268s (también enseña cómo hacer
// que se queden y poner botones para quitarlas)

import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland                // Para el namespace y la capa de la ventana
import QtQuick
import QtQuick.Layouts                  // Para usar RowLayout o ColumnLayout
import qs.components
import qs.services

Scope{
    id: root
    property alias screen: panel.screen
    // El servidor de notificaciones (el que las recibe por D-Bus) y qué se enseña como tarjeta
    // viven en services/NotificationCenter.qml, fuera del Variants de la pantalla: esta ventana
    // se destruye y se vuelve a crear al cerrar la tapa del portátil o cambiar de monitor, y con
    // ellos dentro se perdían las notificaciones que hubiese. Aquí solo se pintan.
    readonly property int count: NotificationCenter.popups.length
    readonly property real defaultTimeout: 10   // Segundos en pantalla si la app no pide un tiempo concreto
    readonly property int maxVisible: 4         // Notificaciones que se ven a la vez; las demás esperan su turno
    readonly property int hiddenCount: Math.max(0, count - maxVisible)
    PanelWindow{
        id: panel
        // Sin notificaciones la ventana no existe: si no, quedaba una franja invisible
        // arriba a la derecha que se tragaba los clics
        visible: root.count > 0
        anchors{top:true; right:true}
        margins{top:12; right:12}
        implicitWidth: 380
        implicitHeight: Math.max(1, column.implicitHeight)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore         // Para que no reserve espacio todo el rato en la ventana
        WlrLayershell.layer: WlrLayer.Top           // La que ya tenía por defecto: por debajo de las ventanas en pantalla completa
        WlrLayershell.namespace: "reddots:notifications"   // Para poder darle reglas de capa (layerrule) en Hyprland, como a las demás

        ColumnLayout{
            id: column
            width: parent.width
            spacing: 10
            // Recorre todas las activas, no solo las emergentes: las ocultas se quedan sin pintar
            // (visible: false). Así, al ocultarse o cerrarse una, las demás no se recrean.
            Repeater{
                model: NotificationCenter.server.trackedNotifications
                delegate: NotificationCard{
                    id: card
                    required property var modelData

                    // Puesto entre las emergentes, en el orden en que se pintan (-1 = oculta, solo en SystemStats)
                    readonly property int popupRank: NotificationCenter.popupRanks[modelData.id] ?? -1

                    // Las que no caben esperan ocultas (el layout no les deja hueco). Se hace
                    // así, y no recortando el modelo, para que las que ya se ven no se
                    // recreen (y vuelvan a empezar su cuenta) cada vez que llega otra.
                    visible: popupRank >= 0 && popupRank < root.maxVisible

                    // Milisegundos que se queda en pantalla. La app lo pide en expireTimeout, en milisegundos
                    // (la documentación de Quickshell dice segundos, pero "notify-send -t 3000" llega como 3000):
                    // -1 = "lo que decida el servidor" (defaultTimeout), 0 = no caduca. Las críticas no caducan
                    // nunca: se quedan hasta que se cierran a mano, para no perderse un aviso de batería muy baja.
                    readonly property real timeout: modelData.urgency === NotificationUrgency.Critical ? 0
                                                  : modelData.expireTimeout < 0 ? root.defaultTimeout * 1000
                                                  : modelData.expireTimeout

                    notification: modelData
                    Layout.fillWidth: true
                    onCloseRequested: modelData.dismiss()       // Clic derecho, o clic izquierdo sin acción de la app

                    Timer{
                        interval: card.timeout
                        running: card.visible && card.timeout > 0 && !card.hovered     // Con el ratón encima no se va (al quitarlo, la cuenta empieza de nuevo). En cola, tampoco
                        onTriggered: NotificationCenter.hidePopup(card.modelData)   // Se quita de la pantalla, pero sigue en SystemStats
                    }
                }
            }

            HoverRect{                                      // "+N más": las que esperan en cola
                Layout.fillWidth: true
                visible: root.hiddenCount > 0
                implicitHeight: moreText.implicitHeight + 12
                radius: 8
                idleColor: Theme.background
                border.width: 1
                border.color: Theme.border
                acceptedButtons: Qt.RightButton                 // Derecho, como para cerrar una sola: así no se borran todas por un clic sin querer
                onClicked: NotificationCenter.dismissPopups()   // Las de la pantalla; las que ya solo están en SystemStats, no

                Text{
                    id: moreText
                    anchors.centerIn: parent
                    text: "+" + root.hiddenCount + (root.hiddenCount === 1 ? " notificación más" : " notificaciones más")
                          + "  ·  clic derecho: cerrar todas"
                    color: Theme.textActive
                    font.pixelSize: 11
                }
            }
        }
    }
}
