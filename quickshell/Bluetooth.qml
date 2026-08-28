// Docs: https://quickshell.org/docs/v0.3.0/types/Quickshell.Bluetooth/

import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 6

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter ? adapter.enabled : false

    readonly property var connectedDevices: adapter
        ? adapter.devices.values.filter(d => d.connected)
        : []
    readonly property var active: connectedDevices[0] ?? null

    readonly property string icon: {
        if (!powered) return String.fromCodePoint(0xF00B2)  // bluetooth-off
        if (!active)  return String.fromCodePoint(0xF00AF)  // bluetooth
        return String.fromCodePoint(0xF00B1)                // bluetooth-connect
    }

    Text {
        text: root.icon
        color: root.powered ? "#f5e2c5" : "#5a4d3e"

        TapHandler {
            onTapped: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
        }
    }

    // Batería del dispositivo activo, si la reporta
    Text {
        visible: root.active?.batteryAvailable ?? false
        text: Math.round((root.active?.battery ?? 0) * 100) + "%"
        color: "#f5e2c5"
    }
}