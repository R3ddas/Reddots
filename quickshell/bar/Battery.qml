// Recursos: https://www.youtube.com/watch?v=Vlpyz4c4Xdw


import Quickshell
import Quickshell.Services.UPower  // Para la información de la batería
import QtQuick
import QtQuick.Layouts // Para usar RowLayout o ColumnLayout
import qs.components
import qs.services

ColumnLayout{
    id: root
    spacing: 6

    // El estado y los avisos de batería baja están en services/BatteryMonitor.qml, que no se
    // destruye con la barra (así no se repiten los avisos). Aquí solo se pinta.
    readonly property UPowerDevice battery: BatteryMonitor.battery
    readonly property bool charging: BatteryMonitor.charging
    readonly property int level: BatteryMonitor.level

    property bool showLevel: false

    readonly property string icon: {
        if (charging) return String.fromCodePoint(0xF0084)
        if (level>=100) return String.fromCodePoint(0xF0079)
        if (level<10) return String.fromCodePoint(0xF0083)
        return String.fromCodePoint(0xF007A + Math.floor(level/10) - 1)
    }

    // "2 h 15 min", "40 min"; vacío si UPower aún no lo sabe (da 0 los primeros segundos)
    function duration(seconds) {
        if (!(seconds > 0)) return ""
        const h = Math.floor(seconds / 3600)
        const m = Math.round((seconds % 3600) / 60)
        return h > 0 ? h + " h " + m + " min" : m + " min"
    }

    readonly property string tooltip: {
        const text = "Batería " + level + " %"
        if (battery.state === UPowerDeviceState.FullyCharged) return text + " · cargada"
        if (charging) {
            const full = duration(battery.timeToFull)
            return text + " · cargando" + (full ? ", llena en " + full : "")
        }
        const left = duration(battery.timeToEmpty)
        return text + (left ? " · quedan " + left : "")
    }

    BarIcon {
        text: root.icon
        tooltip: root.tooltip
        acceptedButtons: Qt.RightButton
        onClicked: root.showLevel = !root.showLevel     // Con el botón derecho se esconde/muestra el valor de carga
    }

    BarIcon {                                           // Texto con el valor de carga, se cambia la visibilidad con botón derecho
        visible: root.showLevel
        text: root.level + "%"
        font.pixelSize: 10                              // Si es muy grande no cabe en la barra y descentra los textos
        acceptedButtons: Qt.RightButton
        onClicked: root.showLevel = !root.showLevel
    }
}
