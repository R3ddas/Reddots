// Recursos: https://www.youtube.com/watch?v=leCzeCeNxas&t=268s
// En el video también enseña como ahcer que se queden ahí y poner botones para quitrlas
// Se pueden generar notificaciones desde terminal con: notify-send "Titulo" "Contenido"
// Pueden ser críticas con: notify-send -u critical "Titulo" "Contenido"


import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts                  // Para usar RowLayout o ColumnLayout

Scope{
    id: root
    property alias screen: panel.screen
    NotificationServer{
        id:server
        actionsSupported: true
        bodySupported: true

        onNotification: n => {
            n.tracked = true
        }
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

                    Layout.fillWidth: true
                    Layout.preferredHeight: layout.implicitHeight +20

                    radius: 8
                    color: Theme.background
                    border.width: 2
                    border.color: modelData.urgency === NotificationUrgency.Critical ? "#ff0000" : Theme.textSelected

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
                        }
                    }

                    MouseArea{
                        anchors.fill: parent
                        onClicked: card.modelData.dismiss()      // Cierra la notificación al hacer click
                    }
                }
            }
        }
    }
}
