// Recursos: https://www.youtube.com/watch?v=leCzeCeNxas&t=268s
// En el video también enseña como ahcer que se queden ahí y poner botones para quitrlas
// Se pueden generar notificaciones desde terminal con: notify-send "Titulo" "Contenido"
// Pueden ser críticas con: notify-send -u critical "Titulo" "Contenido"
// Se van solas a los 5 s (defaultTimeout) o al tiempo que pida la app (notify-send -t 3000 = 3 s; -t 0 = nunca).
// Las críticas no se van solas. Con el ratón encima no se van.
// Clic izquierdo: la acción principal de la app si la tiene (si no, la cierra). Clic derecho: la cierra.
// Con acciones se pintan botones: notify-send -A si=Sí -A no=No "Titulo" "Contenido"


import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts                  // Para usar RowLayout o ColumnLayout

Scope{
    id: root
    property alias screen: panel.screen
    readonly property real defaultTimeout: 5    // Segundos en pantalla si la app no pide un tiempo concreto
    NotificationServer{
        id:server
        actionsSupported: true
        bodySupported: true

        onNotification: n => {
            n.tracked = true        }
    }
    PanelWindow{
        id: panel
        anchors{top:true; right:true}
        margins{top:12; right:12}
        implicitWidth: 380
        implicitHeight: Math.max(1, column.implicitHeight)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore         // Para que no reserve espacio todo el rato en la ventana

        ColumnLayout{
            id: column
            width: parent.width
            spacing: 10
            Repeater{
                model: server.trackedNotifications
                delegate: Rectangle{
                    id: card
                    required property var modelData

                    // appIcon puede venir como nombre de icono del tema ("firefox"), como ruta
                    // ("/usr/share/...") o como URL ("file:///..."). Solo el nombre hay que
                    // buscarlo en el tema de iconos; con "true" devuelve "" si no existe.
                    function iconSource(appIcon) {
                        if (!appIcon) return ""
                        if (appIcon.startsWith("/")) return "file://" + appIcon
                        if (appIcon.includes("://")) return appIcon
                        return Quickshell.iconPath(appIcon, true)
                    }

                    // "notify-send -i" llega por image como "image://icon/<nombre o ruta>", y si
                    // ese icono no existe se pinta un damero magenta. Se comprueba igual que appIcon.
                    function imageSource(image) {
                        if (!image) return ""
                        if (image.startsWith("image://icon/")) return iconSource(image.slice(13).split("?")[0])
                        return image
                    }

                    // Milisegundos que se queda en pantalla. La app lo pide en expireTimeout, en milisegundos
                    // (la documentación de Quickshell dice segundos, pero "notify-send -t 3000" llega como 3000):
                    // -1 = "lo que decida el servidor" (defaultTimeout), 0 = no caduca. Las críticas no caducan
                    // nunca: se quedan hasta que se cierran a mano, para no perderse un aviso de batería muy baja.
                    readonly property real timeout: modelData.urgency === NotificationUrgency.Critical ? 0
                                                  : modelData.expireTimeout < 0 ? root.defaultTimeout * 1000
                                                  : modelData.expireTimeout

                    // La acción "default" no es un botón: es la que se lanza al hacer clic en la
                    // notificación (p.ej. abrir el chat de Teams). El resto sí se pintan como botones.
                    readonly property var defaultAction: modelData.actions.find(a => a.identifier === "default") ?? null
                    readonly property var buttonActions: modelData.actions.filter(a => a.identifier !== "default")

                    Layout.fillWidth: true
                    Layout.preferredHeight: layout.implicitHeight +20

                    radius: 8
                    color: Theme.background
                    border.width: 2
                    border.color: modelData.urgency === NotificationUrgency.Critical ? "#ff0000" : Theme.textSelected

                    Timer{
                        interval: card.timeout
                        running: card.timeout > 0 && !hover.hovered     // Con el ratón encima no se va (al quitarlo, la cuenta empieza de nuevo)
                        onTriggered: card.modelData.expire()            // Le dice a la app que ha caducado (no que la haya cerrado el usuario)
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
                        Image{
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            Layout.alignment: Qt.AlignTop
                            fillMode: Image.PreserveAspectFit
                            visible: source.toString() !== "" && status !== Image.Error   // Sin hueco si no hay icono o la ruta no se puede abrir
                            source: card.imageSource(card.modelData.image) || card.iconSource(card.modelData.appIcon)
                        }
                        ColumnLayout{
                            Layout.fillWidth: true
                            spacing: 2

                            Text{                           // Título de la notificación
                                Layout.fillWidth: true
                                visible: text !== ""        // Visible si no está vacío
                                text: card.modelData.summary
                                color: Theme.textSelected
                                font.bold: true
                                wrapMode: Text.WordWrap
                            }
                            Text{                           // Mensaje de la notificación
                                Layout.fillWidth: true
                                visible: text !== ""        // Visible si no está vacío
                                text: card.modelData.body
                                color: Theme.textActive
                                wrapMode: Text.WordWrap
                            }
                            Flow{                           // Botones de las acciones (si no caben en una fila, pasan a la siguiente)
                                Layout.fillWidth: true
                                Layout.topMargin: 6
                                visible: card.buttonActions.length > 0
                                spacing: 6
                                Repeater{
                                    model: card.buttonActions
                                    delegate: Rectangle{
                                        id: actionButton
                                        required property var modelData
                                        implicitWidth: actionText.implicitWidth + 16
                                        implicitHeight: actionText.implicitHeight + 8
                                        radius: 6
                                        color: actionMouse.containsMouse ? Theme.surfaceHover : Theme.surface
                                        border.color: Theme.border

                                        Text{
                                            id: actionText
                                            anchors.centerIn: parent
                                            text: actionButton.modelData.text
                                            color: Theme.textActive
                                            font.pixelSize: 11
                                        }

                                        MouseArea{
                                            id: actionMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: actionButton.modelData.invoke()   // La cierra sola, salvo que la app pida que se quede
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
