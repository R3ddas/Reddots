import Quickshell
import Quickshell.Hyprland  // Para acceder a los WorkSpaces
import QtQuick
import QtQuick.Layouts      // Para usar RowLayout o ColumnLayout

ColumnLayout{
    Repeater{               // Repite algo N veces
        model:5
        Text{
            property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
            property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
            text: index + 1
            //Lógica del color: Si es el actual:Theme.textSelected. Si no lo es, pero contiene algo: Theme.textActive, si no: Theme.textDisabled
            color: isActive ? Theme.textSelected : (ws ? Theme.textActive : Theme.textDisabled)
            font { pixelSize: 15; bold: true }
            Layout.alignment: Qt.AlignHCenter // Centro verticalemente los números

            MouseArea {
                anchors.fill: parent
                anchors.margins: -5             // Doy un poco de margen para que sea más fácil hacer click en el número
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + (index + 1) + " })")
            }
        }
    }
}
