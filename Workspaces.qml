import Quickshell
import Quickshell.Hyprland // Para acceder a los WorkSpaces
import QtQuick
import QtQuick.Layouts // Para usar RowLayout o ColumnLayout

// Gestión de WorkSpaces--------------------------------------------------
ColumnLayout{
    anchors.fill: parent
    anchors.margins: 6
    Repeater{ // Repite algo N veces
        model:9
        Text{
            property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
            property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
            text: index + 1
            //The color logic is straightforward: cyan if it’s the active workspace, blue if it exists but isn’t active, and muted gray if there’s no windows on that workspace.
            color: isActive ? "#0db9d7" : (ws ? "#7aa2f7" : "#444b6a")
            font { pixelSize: 14; bold: true }
            Layout.alignment: Qt.AlignHCenter // Centro verticalemente los números

            MouseArea {
                anchors.fill: parent
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + (index + 1) + " })")
            }
        }
    }
    Item { Layout.fillHeight: true } // Añade espacios entre los WorkSpaces
}
