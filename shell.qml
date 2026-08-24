import Quickshell
import QtQuick

ShellRoot {
    PanelWindow {
        anchors { top: true; left: true; right: true }
        implicitHeight: 32
        color: "#1e1e2e"

        Text {
            anchors.centerIn: parent
            color: "#cdd6f4"
            font.pointSize: 11
            text: reloj.hora
        }

        QtObject {
            id: reloj
            property string hora: ""
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: reloj.hora = new Date().toLocaleString(Qt.locale(), "ddd d MMM  hh:mm")
        }
    }
}
