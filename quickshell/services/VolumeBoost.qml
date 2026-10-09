pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire   // Para leer y cambiar el volumen de la salida
import QtQuick

// Límite del volumen de la salida (100 % o, con el aumento activado, 150 %) compartido por
// el popup de la barra (bar/Volume.qml), el indicador (windows/Osd.qml) y las teclas de
// volumen (hypr/keybinds.lua, vía "qs ipc call volume up/down" en ShellIpc.qml). Así los tres
// respetan el mismo tope.
//
// A propósito NO se guarda: cada vez que arranca Quickshell empieza desactivado (por encima
// del 100 % el sonido puede distorsionar).
Singleton {
    id: root

    property bool boost: false
    readonly property real maxVolume: boost ? 1.5 : 1

    readonly property var sink: Pipewire.defaultAudioSink

    // Activa/desactiva el aumento. Al desactivarlo, si se estaba por encima del 100 %, se baja
    // a 100 para que el volumen no quede fuera del rango que ahora se muestra.
    function setBoost(on) {
        boost = on
        if (!on && sink && sink.audio.volume > 1) sink.audio.volume = 1
    }

    // Sube o baja el volumen de la salida (delta en fracción: 0.05 = 5 %) sin pasar del tope.
    // Subirlo quita el silencio, como al mover el slider.
    function step(delta) {
        if (!sink) return
        // Se redondea a 2 decimales para que no se acumulen errores de coma flotante (0.30000000000000004...)
        const v = Math.round(Math.max(0, Math.min(maxVolume, sink.audio.volume + delta)) * 100) / 100
        sink.audio.volume = v
        if (delta > 0) sink.audio.muted = false
    }

    // Hace falta el nodo enganchado para poder leer/escribir su volumen desde aquí
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }
}
