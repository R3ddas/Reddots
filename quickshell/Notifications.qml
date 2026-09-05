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
    NotificationServer{
        id:server
        actionsSupported: true
        bodySupported: true

        onNotification: n => {
            console.log("got:", n.summary, "---", n.body)
            n.tracked = true
        }
    }
    PanelWindow{
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
                            visible: source.toString() !== ""
                            source: card.modelData.image || card.modelData.icon || ""
                        }
                        ColumnLayout{
                            Layout.fillWidth: true
                            spacing: 2

                            Text{                           // Título de la notificación
                                visible: text !== ""        // Visible si no está vacío
                                text: card.modelData.summary
                                color: Theme.textSelected
                                elide: Text.ElideRight
                                font.bold: true
                                wrapMode: Text.WordWrap
                            }
                            Text{                           // Mensaje de la notificación
                                visible: text !== ""        // Visible si no está vacío
                                text: card.modelData.body
                                color: Theme.textActive
                                elide: Text.ElideRight
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
