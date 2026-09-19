// Recursos: https://www.youtube.com/watch?v=Vlpyz4c4Xdw

import Quickshell
import Quickshell.Hyprland  // Para acceder a los WorkSpaces
import QtQuick
import QtQuick.Layouts      // Para usar RowLayout o ColumnLayout

ColumnLayout{
    id: root
    property bool showDate: false   // Se alterna con click derecho sobre la hora

    Text{
        text: Qt.formatDateTime(clock.date, "hh\nmm")
        color: Theme.textActive
        font.pixelSize: 15
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        Layout.alignment: Qt.AlignHCenter

        MouseArea{
            anchors.fill: parent
            anchors.margins: -4
            acceptedButtons: Qt.RightButton
            onClicked: root.showDate = !root.showDate
        }
    }

    Text{
        visible: root.showDate
        text: Qt.formatDateTime(clock.date, "dd\nMM")
        color: Theme.textDisabled
        font.pixelSize: 11
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        Layout.alignment: Qt.AlignHCenter

        MouseArea{
            anchors.fill: parent
            anchors.margins: -4
            acceptedButtons: Qt.RightButton
            onClicked: root.showDate = !root.showDate
        }
    }

    SystemClock{
        id:clock
        precision: SystemClock.Minutes      // Sólo lo actualizo cada minuto porque no me interesan los segundos
    }

}
