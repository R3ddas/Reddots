import Quickshell
import Quickshell.Hyprland  // Para acceder a los WorkSpaces
import QtQuick
import QtQuick.Layouts      // Para usar RowLayout o ColumnLayout

Item{
    id: root
    Layout.fillWidth: true      // Todo el ancho de la barra (los números siguen centrados): si no, la rueda solo respondía justo encima de las cifras
    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    // Rueda del ratón sobre los números: recorre los workspaces que existen, igual que
    // Super + rueda (hypr/keybinds.lua). Se acumula el giro hasta un "clic" de rueda
    // (120) para que el touchpad, que manda muchos pasitos, no se salte varios de golpe.
    // Con MouseArea y no WheelHandler: al WheelHandler no le llegaba la rueda.
    // Va debajo de los números: los clics los recogen los MouseArea de cada uno.
    property int wheelAccum: 0
    MouseArea {
        anchors.fill: parent
        anchors.margins: -5                 // Lo mismo que la zona de clic de cada número
        acceptedButtons: Qt.NoButton        // Solo la rueda
        onWheel: event => {
            root.wheelAccum += event.angleDelta.y
            if (Math.abs(root.wheelAccum) < 120) return
            Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + (root.wheelAccum < 0 ? "e+1" : "e-1") + "\" })")   // Hacia abajo, el siguiente
            root.wheelAccum = 0
        }
    }

    ColumnLayout{
        id: column
        anchors.fill: parent

        Repeater{               // Repite algo N veces
            model:6
            Text{
                id: wsText
                property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
                property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
                property bool isUrgent: !isActive && (ws?.urgent ?? false)     // Una ventana pide atención (Hyprland lo quita solo al ir a ese workspace)
                text: index + 1
                //Lógica del color: Si es el actual:Theme.textSelected. Si no lo es, pero contiene algo: Theme.textActive, si no: Theme.textDisabled
                //Si pide atención, con el color de acento y parpadeando (así se distingue en todos los temas)
                color: (isActive || isUrgent) ? Theme.textSelected : (ws ? Theme.textActive : Theme.textDisabled)
                font { pixelSize: 15; bold: true }
                Layout.alignment: Qt.AlignHCenter // Centro verticalemente los números

                SequentialAnimation on opacity {  // Parpadeo mientras pide atención
                    running: wsText.isUrgent
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 500; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutQuad }
                    onRunningChanged: if (!running) wsText.opacity = 1   // Al dejar de pedir atención, que no se quede a medias
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5             // Doy un poco de margen para que sea más fácil hacer click en el número
                    onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + (index + 1) + " })")
                }
            }
        }
    }
}
