// Recursos: https://www.youtube.com/watch?v=Vlpyz4c4Xdw

import Quickshell
import Quickshell.Networking  // Para la información de las conexiones
import QtQuick
import QtQuick.Layouts // Para usar RowLayout o ColumnLayout

ColumnLayout{
    id: root
    spacing: 6

    property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
    property var active: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) : null

    readonly property real signal: active? active.signalStrength : 0

    readonly property string icon: {
        if (!Networking.wifiEnabled) return String.fromCodePoint (0xF05AA)
        if (!active) return String.fromCodePoint(0xF092D)

        let tier = signal >= 0.75 ? 3
                 : signal >= 0.50 ? 2
                 : signal >= 0.25 ? 1
                 : 0
        return String.fromCodePoint(0xF091F + tier*3)
    }

    Text{
        text: root.icon
        color: Networking.wifiEnabled? Theme.text : Theme.textMuted
        font.pixelSize: 18
    }

}
