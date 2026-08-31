// Icono de apagado, abre un menú para apagar, reiniciar o suspender el equipo

import Quickshell
import Quickshell.Io       // Para lanzar systemctl
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 6

    Text {
        id: iconText
        text: String.fromCodePoint(0xF0425)  // power
        font.pixelSize: 18
        color: Theme.text
        Layout.alignment: Qt.AlignHCenter

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            onClicked: menu.visible = !menu.visible
        }
    }

    PopupWindow {
        id: menu
        visible: false
        color: "transparent"

        anchor.item: iconText
        anchor.rect.y: -8               // El widget está al final de la barra, así que el menú se abre hacia arriba
        anchor.gravity: Edges.Top

        implicitWidth: 170
        implicitHeight: listCol.implicitHeight + 16

        onVisibleChanged: {
            if (visible) grabTimer.restart()
            else { grabTimer.stop(); grab.active = false }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.surface
            radius: 8
            border.color: Theme.border

            ColumnLayout {
                id: listCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 4
                    color: shutdownMouse.containsMouse ? Theme.surfaceHover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8
                        Text { text: String.fromCodePoint(0xF0425); color: Theme.text; font.pixelSize: 15 }  // power
                        Text { text: "Apagar"; color: Theme.text }
                    }

                    MouseArea {
                        id: shutdownMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            menu.visible = false
                            shutdownProc.startDetached()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 4
                    color: restartMouse.containsMouse ? Theme.surfaceHover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8
                        Text { text: String.fromCodePoint(0xF0709); color: Theme.text; font.pixelSize: 15 }  // restart
                        Text { text: "Reiniciar"; color: Theme.text }
                    }

                    MouseArea {
                        id: restartMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            menu.visible = false
                            restartProc.startDetached()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 4
                    color: suspendMouse.containsMouse ? Theme.surfaceHover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8
                        Text { text: String.fromCodePoint(0xF0904); color: Theme.text; font.pixelSize: 15 }  // power-sleep
                        Text { text: "Suspender"; color: Theme.text }
                    }

                    MouseArea {
                        id: suspendMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            menu.visible = false
                            suspendProc.startDetached()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 4
                    color: screensaverMouse.containsMouse ? Theme.surfaceHover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8
                        Text { text: String.fromCodePoint(0xF0379); color: Theme.text; font.pixelSize: 15 }  // monitor
                        Text { text: "Salvapantallas"; color: Theme.text }
                    }

                    MouseArea {
                        id: screensaverMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            menu.visible = false
                            screensaverProc.startDetached()
                        }
                    }
                }
            }
        }
    }

    Process { id: shutdownProc; command: ["systemctl", "poweroff"] }
    Process { id: restartProc; command: ["systemctl", "reboot"] }
    Process { id: suspendProc; command: ["systemctl", "suspend"] }
    Process {                                                                  // Cambia aquí el comando si en el futuro quieres otro salvapantallas
        id: screensaverProc
        command: ["alacritty", "-o", "window.startup_mode=\"Fullscreen\"", "-e", "cmatrix", "-bsu", "8"]
    }

    HyprlandFocusGrab {
        id: grab
        windows: [menu]
        active: false
        onCleared: menu.visible = false
    }

    Timer {
        id: grabTimer
        interval: 5
        onTriggered: grab.active = true
    }
}
