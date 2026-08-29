// Recursos: https://www.youtube.com/watch?v=Vlpyz4c4Xdw

import Quickshell
import Quickshell.Hyprland // Para acceder a los WorkSpaces
import QtQuick
import QtQuick.Layouts // Para usar RowLayout o ColumnLayout

ColumnLayout{
    Text{
        //Layout.alignment: Qt.AlignHCenter
        //horizontalAlignment: Text.AlignHCenter
        text: Qt.formatDateTime(clock.date, "hh\nmm")
        color: "#f5e2c5"
        font.pixelSize: 14
    }

    SystemClock{
        id:clock
        precision: SystemClock.Minutes
    }

}
