// Recursos: https://www.youtube.com/watch?v=Vlpyz4c4Xdw

import Quickshell
import Quickshell.Hyprland // Para acceder a los WorkSpaces
import QtQuick
import QtQuick.Layouts // Para usar RowLayout o ColumnLayout

ColumnLayout{
    Text{
        //nchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "hh:\n:mm")
        color: "#f5e2c5"
    }

    SystemClock{
        id:clock
        precision: SystemClock.Minutes
    }

}
