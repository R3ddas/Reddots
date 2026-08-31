// Recursos: https://www.youtube.com/watch?v=Vlpyz4c4Xdw

import Quickshell
import Quickshell.Hyprland // Para acceder a los WorkSpaces
import QtQuick
import QtQuick.Layouts // Para usar RowLayout o ColumnLayout

ColumnLayout{
    Text{
        text: Qt.formatDateTime(clock.date, "hh\nmm")
        color: Theme.text
        font.pixelSize: 15
        font.bold: true
    }

    SystemClock{
        id:clock
        precision: SystemClock.Minutes
    }

}
