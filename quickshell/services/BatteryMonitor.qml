pragma Singleton
import Quickshell
import Quickshell.Services.UPower   // Para la información de la batería
import QtQuick

// Estado de la batería y avisos de batería baja. Lo usa el icono de la barra
// (bar/Battery.qml), que solo pinta. Está aquí y no en el icono porque la barra se
// destruye y se vuelve a crear al cerrar la tapa o cambiar de monitor: con el aviso
// dentro, se olvidaba de que ya había avisado y repetía la notificación.
// Solo se crea en equipos con batería (el icono es el primero que lo usa, y la barra
// solo crea el icono si hay batería, ver bar/Bar.qml).
Singleton {
    id: root

    readonly property UPowerDevice battery: UPower.displayDevice
    readonly property bool charging:                            // Definiciones de cargando segun UPower (Si está enchufado y al 100% detecta FullyCharged, no Charging)
    battery.state == UPowerDeviceState.Charging                 // Batería a la que literalmente le está entrando carga
    || battery.state == UPowerDeviceState.PendingCharge
    || battery.state == UPowerDeviceState.FullyCharged          // Batería completamente cargada

    readonly property int level: Math.round(battery.percentage * 100)

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
}
