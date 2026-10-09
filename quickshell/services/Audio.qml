pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire   // Para leer y cambiar el volumen de la salida y del micrófono
import QtQuick

// La salida y el micrófono que se usan, con su volumen, si están silenciados y su icono, y
// el límite del volumen de la salida (100 % o, con el aumento activado, 150 %). Lo comparten
// el popup de la barra (bar/Volume.qml), el indicador (windows/Osd.qml) y las teclas de
// volumen (hypr/keybinds.lua, vía "qs ipc call volume up/down" en ShellIpc.qml): así los
// tres enseñan los mismos iconos y respetan el mismo tope.
//
// El aumento a propósito NO se guarda: cada vez que arranca Quickshell empieza desactivado
// (por encima del 100 % el sonido puede distorsionar).
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink          // La salida (altavoces, auriculares...)
    readonly property bool muted: sink ? sink.audio.muted : true
    readonly property real volume: sink ? sink.audio.volume : 0     // De 0 a maxVolume

    readonly property var source: Pipewire.defaultAudioSource      // El micrófono
    readonly property bool micMuted: source ? source.audio.muted : true
    readonly property real micVolume: source ? source.audio.volume : 0

    // Icono del volumen (glifos de la Nerd Font). Tres tramos: por debajo de 1/3 bajo, hasta
    // 2/3 medio y de ahí para arriba alto
    readonly property string volumeIcon: {
        if (!sink || muted || volume === 0) return String.fromCodePoint(0xF075F)  // volume-mute
        if (volume >= 0.66) return String.fromCodePoint(0xF057E)                  // volume-high
        if (volume >= 0.33) return String.fromCodePoint(0xF0580)                  // volume-medium
        return String.fromCodePoint(0xF057F)                                      // volume-low
    }
    readonly property string micIcon: String.fromCodePoint(micMuted ? 0xF036D : 0xF036C)   // microphone-off / microphone

    // --- Aumento del volumen ---
    property bool boost: false
    readonly property real maxVolume: boost ? 1.5 : 1

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

    // Hace falta engancharlos para poder leer y cambiar su volumen y su silencio desde aquí
    // (y que estén al día en el indicador aunque el popup de la barra no los tenga enganchados)
    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n)
    }
}
