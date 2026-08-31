// Recursos: https://www.youtube.com/watch?v=Vlpyz4c4Xdw


import Quickshell
import Quickshell.Services.UPower  // Para la información de la batería
import QtQuick
import QtQuick.Layouts // Para usar RowLayout o ColumnLayout

ColumnLayout{
    id: root
    spacing: 6

    readonly property UPowerDevice battery: UPower.displayDevice
    readonly property bool charging:                            // Definiciones de cargando segun UPower (Si está enchufado y al 100% detecta FullyCharged, no Charging)
    battery.state == UPowerDeviceState.Charging                 // Batería a la que literalmente le está entrando carga
    || battery.state == UPowerDeviceState.PendingCharge
    || battery.state == UPowerDeviceState.FullyCharged          // Batería completamente cargada

    readonly property int level: Math.round(battery.percentage * 100)

    property bool showLevel: false

    readonly property string icon: {
        if (charging) return String.fromCodePoint(0xF0084)
        if (level>=100) return String.fromCodePoint(0xF0079)
        if (level<10) return String.fromCodePoint(0xF0083)
        return String.fromCodePoint(0xF007A + Math.floor(level/10) - 1)
    }

    Text{
        text: root.icon
        color: Theme.text
        font.pixelSize: 18
        Layout.alignment: Qt.AlignHCenter
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            acceptedButtons: Qt.RightButton
            onClicked: root.showLevel = !root.showLevel  // Si se pulsa botón izquierdo se esconde/muestra el valor de carga
        }
    }

    Text {                                              // Texto con el valor de carga, se cambia la visibilidad con botón derecho
        visible: root.showLevel
        text: root.level + "%"
        color: Theme.text
        font.pixelSize: 10                              // Si es muy grande no cabe en la barra y descentra los textos
        Layout.alignment: Qt.AlignHCenter
    }
}
