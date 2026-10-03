// Recursos: https://www.youtube.com/watch?v=leCzeCeNxas&t=268s
// En el video también enseña como ahcer que se queden ahí y poner botones para quitrlas
// Se pueden generar notificaciones desde terminal con: notify-send "Titulo" "Contenido"
// Pueden ser críticas con: notify-send -u critical "Titulo" "Contenido"
// Se ocultan solas a los 10 s (defaultTimeout) o al tiempo que pida la app (notify-send -t 3000 = 3 s; -t 0 = nunca).
// Ocultarse no es cerrarse: siguen en el popup de SystemStats (bar/SystemStats.qml) hasta
// que se descartan; ver services/NotificationCenter.qml. Las transitorias sí se cierran.
// Las críticas no se ocultan solas. Con el ratón encima, tampoco.
// Clic izquierdo: la acción principal de la app si la tiene (si no, la cierra). Clic derecho: la cierra.
// Con acciones se pintan botones: notify-send -A si=Sí -A no=No "Titulo" "Contenido"
// Como mucho se ven maxVisible a la vez (las más antiguas); el resto espera en cola,
// sin gastar su tiempo, y debajo sale un "+N más". Así una ráfaga (Teams...) no se sale
// de la pantalla. Probar: for i in $(seq 8); do notify-send "Prueba $i"; done


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
                delegate: Rectangle{
                    id: card
                    required property var modelData
                    required property int index

                    // Puesto entre las emergentes, en el orden en que se pintan (-1 = oculta, solo en SystemStats)
                    readonly property int popupRank: {
                        const popups = NotificationCenter.popups
                        if (!popups.includes(modelData.id)) return -1
                        const before = NotificationCenter.active.slice(0, index)
                        return before.filter(n => popups.includes(n.id)).length
                    }

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

                    // La acción "default" no es un botón: es la que se lanza al hacer clic en la
                    // notificación (p.ej. abrir el chat de Teams). El resto se pintan como botones.
                    readonly property var defaultAction: modelData.actions.find(a => a.identifier === "default") ?? null

                    Layout.fillWidth: true
                    Layout.preferredHeight: layout.implicitHeight +20

                    radius: 8
                    color: Theme.background
                    border.width: 2
                    border.color: modelData.urgency === NotificationUrgency.Critical ? Theme.error : Theme.textSelected

                    Timer{
                        interval: card.timeout
                        running: card.visible && card.timeout > 0 && !hover.hovered     // Con el ratón encima no se va (al quitarlo, la cuenta empieza de nuevo). En cola, tampoco
                        onTriggered: NotificationCenter.hidePopup(card.modelData)   // Se quita de la pantalla, pero sigue en SystemStats
                    }

                    HoverHandler{ id: hover }                           // HoverHandler y no MouseArea: se entera también con el ratón sobre los botones

                    // Va antes que el contenido para quedar por debajo: si no, se tragaría los clics de los botones
                    MouseArea{
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: event => {
                            if (event.button === Qt.LeftButton && card.defaultAction) card.defaultAction.invoke()   // Izquierdo: la acción de la app (la cierra sola, salvo que la app pida que se quede)
                            else card.modelData.dismiss()                                                           // Sin acción, o clic derecho: solo cerrarla
                        }
                    }

                    RowLayout{
                        id: layout
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10
                        NotificationIcon{               // La imagen de la app o, si no se puede abrir, el icono de la app
                            size: 36
                            Layout.alignment: Qt.AlignTop
                            image: card.modelData.image
                            appIcon: card.modelData.appIcon
                            desktopEntry: card.modelData.desktopEntry
                            appName: card.modelData.appName
                        }
                        ColumnLayout{
                            Layout.fillWidth: true
                            spacing: 2

                            Text{                           // Título de la notificación
                                Layout.fillWidth: true
                                visible: text !== ""        // Visible si no está vacío
                                text: card.modelData.summary
                                // PlainText: el texto viene de la app y no debe interpretarse como HTML (como en PolkitDialog.qml).
                                // Sin esto Qt adivina si es texto enriquecido y un "<" puede cambiar cómo se pinta.
                                textFormat: Text.PlainText
                                color: Theme.textSelected
                                font.bold: true
                                wrapMode: Text.WordWrap
                            }
                            Text{                           // Mensaje de la notificación
                                Layout.fillWidth: true
                                visible: text !== ""        // Visible si no está vacío
                                text: card.modelData.body
                                // Igual que el título. El servidor no anuncia marcado (bodyMarkupSupported está a false
                                // por defecto), pero la documentación de Quickshell avisa de que algunas apps lo mandan igual
                                textFormat: Text.PlainText
                                color: Theme.textActive
                                wrapMode: Text.WordWrap
                                maximumLineCount: 8         // Un mensaje larguísimo tampoco se sale de la pantalla
                                elide: Text.ElideRight
                            }
                            NotificationActions{            // Botones de las acciones
                                Layout.fillWidth: true
                                Layout.topMargin: 6
                                notification: card.modelData
                            }
                        }
                    }
                }
            }

            Rectangle{                                      // "+N más": las que esperan en cola
                Layout.fillWidth: true
                visible: root.hiddenCount > 0
                implicitHeight: moreText.implicitHeight + 12
                radius: 8
                color: moreMouse.containsMouse ? Theme.surfaceHover : Theme.background
                border.width: 1
                border.color: Theme.border

                Text{
                    id: moreText
                    anchors.centerIn: parent
                    text: "+" + root.hiddenCount + (root.hiddenCount === 1 ? " notificación más" : " notificaciones más")
                          + "  ·  clic derecho: cerrar todas"
                    color: Theme.textActive
                    font.pixelSize: 11
                }

                MouseArea{
                    id: moreMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.RightButton                 // Derecho, como para cerrar una sola: así no se borran todas por un clic sin querer
                    onClicked: NotificationCenter.dismissPopups()   // Las de la pantalla; las que ya solo están en SystemStats, no
                }
            }
        }
    }
}
