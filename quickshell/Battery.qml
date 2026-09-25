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

    // --- Aviso de batería baja ------------------------------------------------
    // Una notificación al bajar de lowLevel y otra (crítica) al bajar de criticalLevel,
    // solo con el cargador quitado. Al enchufarlo se rearman, para volver a avisar en
    // la siguiente descarga. Si arranca ya por debajo de criticalLevel, solo sale la crítica.
    readonly property int lowLevel: 20          // % del aviso normal
    readonly property int criticalLevel: 10     // % del aviso crítico
    property int warnedLevel: 101               // Último umbral avisado en esta descarga (101 = ninguno)

    function checkLow() {
        if (!battery.ready) return                              // Hasta que UPower da los datos, percentage vale 0: avisaría de más al arrancar
        if (!UPower.onBattery) { warnedLevel = 101; return }    // Enchufado: se rearman los avisos
        if (level <= criticalLevel && warnedLevel > criticalLevel) {
            warnedLevel = criticalLevel
            Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Batería", "-i", "battery-caution",
                "Batería muy baja", "Queda un " + level + " %. Conecta el cargador o el equipo se apagará."])
        } else if (level <= lowLevel && warnedLevel > lowLevel) {
            warnedLevel = lowLevel
            Quickshell.execDetached(["notify-send", "-u", "normal", "-a", "Batería", "-i", "battery-low",
                "Batería baja", "Queda un " + level + " %."])
        }
    }

    onLevelChanged: checkLow()
    Component.onCompleted: checkLow()
    Connections { target: UPower; function onOnBatteryChanged() { root.checkLow() } }      // Al quitar/poner el cargador
    Connections { target: root.battery; function onReadyChanged() { root.checkLow() } }    // Cuando UPower termina de leer la batería

    readonly property string icon: {
        if (charging) return String.fromCodePoint(0xF0084)
        if (level>=100) return String.fromCodePoint(0xF0079)
        if (level<10) return String.fromCodePoint(0xF0083)
        return String.fromCodePoint(0xF007A + Math.floor(level/10) - 1)
    }

    Text{
        text: root.icon
        color: Theme.textActive
        font.pixelSize: 18
        Layout.alignment: Qt.AlignHCenter
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            acceptedButtons: Qt.RightButton
            onClicked: root.showLevel = !root.showLevel  // Con el botón derecho se esconde/muestra el valor de carga
        }
    }

    Text {                                              // Texto con el valor de carga, se cambia la visibilidad con botón derecho
        visible: root.showLevel
        text: root.level + "%"
        color: Theme.textActive
        font.pixelSize: 10                              // Si es muy grande no cabe en la barra y descentra los textos
        Layout.alignment: Qt.AlignHCenter
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            acceptedButtons: Qt.RightButton
            onClicked: root.showLevel = !root.showLevel
        }
    }
}
