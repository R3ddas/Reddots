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
// Con los desplegables "unidos a la barra" (Geometry.popupAttached) las tarjetas salen pegadas a
// la esquina de arriba a la derecha del marco de la pantalla, del color de la barra, como los
// desplegables y el lanzador, una contra otra y separadas por sus esquinas redondeadas (ver
// "attached" más abajo).
//
// Recursos: https://www.youtube.com/watch?v=leCzeCeNxas&t=268s (también enseña cómo hacer
// que se queden y poner botones para quitarlas)

import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland                // Para el namespace y la capa de la ventana
import QtQuick
import QtQuick.Layouts                  // Para usar RowLayout o ColumnLayout
import QtQuick.Shapes                   // Para el fondo del estilo unido
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

    // Estilo unido: en vez de tarjetas sueltas a 12 px de la esquina, un fondo continuo del color de
    // la barra que empieza en el borde interior del marco, con una curva hacia dentro ("oreja") donde
    // se junta con él: una hacia la izquierda por el marco de arriba y otra hacia abajo por el de la
    // derecha. Por la izquierda, cada tarjeta tiene sus esquinas redondeadas: donde acaba la curva de
    // una empieza la de la siguiente, así que se distinguen sin línea y sin hueco entre ellas
    readonly property bool attached: Geometry.popupAttached
    readonly property int ear: attached ? Geometry.popupRounding : 0

    PanelWindow{
        id: panel
        // Sin notificaciones la ventana no existe: si no, quedaba una franja invisible
        // arriba a la derecha que se tragaba los clics
        visible: root.count > 0
        anchors{top:true; right:true}
        margins{
            top: root.attached ? Geometry.borderThickness : 12
            right: root.attached ? Geometry.borderThickness : 12
        }
        implicitWidth: 380 + root.ear
        implicitHeight: Math.max(1, column.implicitHeight + root.ear)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore         // Para que no reserve espacio todo el rato en la ventana
        WlrLayershell.layer: WlrLayer.Top           // La que ya tenía por defecto: por debajo de las ventanas en pantalla completa
        WlrLayershell.namespace: "reddots:notifications"   // Para poder darle reglas de capa (layerrule) en Hyprland, como a las demás

        // Fondo del estilo unido, sacado de dónde ha colocado el layout cada tarjeta que se ve (y el
        // "+N más"). Coordenadas de la ventana: arriba (y = 0) y a la derecha (x = width) está el
        // borde interior del marco, y las tarjetas empiezan en x = ear. Se recorre así: oreja de
        // arriba (del marco de arriba hacia abajo), las esquinas de la izquierda de cada tarjeta
        // (salvo la de arriba de la primera, que es la oreja), oreja de abajo (del borde de abajo de
        // la última al marco derecho) y vuelta por el marco. En SVG, el 1 de los arcos es en el
        // sentido de las agujas del reloj y el 0, al revés
        Shape{
            anchors.fill: parent
            visible: root.attached
            preferredRendererType: Shape.CurveRenderer

            ShapePath{
                fillColor: Theme.background             // El de la barra y el marco: así no se ve la junta
                strokeWidth: 0
                strokeColor: "transparent"

                PathSvg{
                    path: {
                        if (!root.attached) return ""
                        const W = panel.width
                        const L = column.x
                        const e = root.ear
                        const pieces = []
                        for (const child of column.children)    // Leer y, height y visible aquí hace que se recalcule al cambiar
                            if (child.visible && child.height > 0) pieces.push({ top: column.y + child.y, bottom: column.y + child.y + child.height })
                        if (pieces.length === 0) return ""
                        pieces.sort((a, b) => a.top - b.top)

                        let d = `M 0 ${pieces[0].top} A ${e} ${e} 0 0 1 ${L} ${pieces[0].top + e} `
                        pieces.forEach((piece, i) => {
                            const r = Math.min(Geometry.popupRounding, (piece.bottom - piece.top) / 2)   // Sin pasarse en una tarjeta bajita
                            if (i > 0)
                                d += `L ${L + r} ${piece.top} A ${r} ${r} 0 0 0 ${L} ${piece.top + r} `
                            d += `L ${L} ${piece.bottom - r} A ${r} ${r} 0 0 0 ${L + r} ${piece.bottom} `
                        })
                        const bottom = pieces[pieces.length - 1].bottom
                        d += `L ${W - e} ${bottom} A ${e} ${e} 0 0 1 ${W} ${bottom + e} L ${W} ${pieces[0].top} Z`
                        return d
                    }
                }
            }
        }

        ColumnLayout{
            id: column
            x: root.ear
            width: parent.width - root.ear
            spacing: root.attached ? 0 : 10        // Unidas, una contra otra: las separan sus esquinas redondeadas
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
                    flat: root.attached                         // Unidas, el fondo lo pone el Shape de arriba
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
                idleColor: root.attached ? "transparent" : Theme.background     // Unido, el fondo lo pone el Shape, como el de las tarjetas
                border.width: root.attached ? 0 : 1
                border.color: Theme.border
                acceptedButtons: Qt.RightButton                 // Derecho, como para cerrar una sola: así no se borran todas por un clic sin querer
                onClicked: NotificationCenter.dismissPopups()   // Las de la pantalla; las que ya solo están en SystemStats, no

                Text{
                    id: moreText
                    anchors.centerIn: parent
                    text: (root.hiddenCount === 1 ? Lang.tr("+1 notificación más") : Lang.tr("+%1 notificaciones más", root.hiddenCount))
                          + "  ·  " + Lang.tr("clic derecho: cerrar todas")
                    color: Theme.textActive
                    font.pixelSize: 11
                }
            }
        }
    }
}
