// Launcher.qml
// Widget que aparece al pulsar Super solo (sin combinar con otra tecla), anclado abajo-derecha
// Lista las aplicaciones instaladas (con icono) y las lanza al hacer click

import Quickshell
import Quickshell.Io       // Para el IpcHandler
import Quickshell.Hyprland // Para el HyprlandFocusGrab
import Quickshell.Wayland
import Quickshell.Widgets  // Para el IconImage
import QtQuick
import QtQuick.Layouts     // Para RowLayout

PanelWindow {
    id: root
    visible: false

    anchors { bottom: true; right: true }

    implicitWidth: 320
    implicitHeight: 480

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "reddots:launcher"

    onVisibleChanged: {
        if (visible) grabTimer.restart()
        else { grabTimer.stop(); grab.active = false }
    }

    // Aplicaciones instaladas (sin las ocultas), ordenadas por nombre
    property var apps: {
        let list = DesktopEntries.applications.values.filter(e => !e.noDisplay)
        list.sort((a, b) => a.name.localeCompare(b.name))
        return list
    }

    Rectangle {
        id: background
        anchors.fill: parent
        topLeftRadius: 24        // Solo la esquina superior izquierda es redondeada, el resto llega al borde de la pantalla
        color: Theme.surface
        border.color: Theme.border
        clip: true

        ListView {
            anchors.fill: parent
            anchors.margins: 12
            clip: true
            spacing: 4
            model: root.apps

            delegate: Rectangle {
                id: appDelegate
                required property var modelData

                width: ListView.view.width
                height: 44
                radius: 8
                color: hoverArea.containsMouse ? Theme.surfaceHover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10

                    IconImage {
                        implicitSize: 28
                        source: Quickshell.iconPath(appDelegate.modelData.icon, "application-x-executable")
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        text: appDelegate.modelData.name
                        color: Theme.textActive
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        appDelegate.modelData.execute()
                        root.visible = false
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.visible = !root.visible
        }
    }

    HyprlandFocusGrab {
        id: grab
        windows: [root]
        active: false
        onCleared: root.visible = false   // Se cierra al hacer click fuera
    }

    Timer {
        id: grabTimer
        interval: 5
        onTriggered: grab.active = true
    }
}
