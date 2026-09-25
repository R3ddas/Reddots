// Osd.qml
// Indicador que aparece un momento abajo en el centro al cambiar el volumen o el
// brillo con las teclas multimedia. Lo abren los atajos de hypr/keybinds.lua con
// "qs ipc call osd volume" / "qs ipc call osd brightness" (igual que el Launcher
// con Super), así que solo sale con las teclas y no al mover el slider de la barra.

import Quickshell
import Quickshell.Io                  // Para el IpcHandler y el Process de brightnessctl
import Quickshell.Wayland
import Quickshell.Services.Pipewire   // Para leer el volumen
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    visible: false

    property string mode: "volume"          // "volume" o "brightness": qué se está mostrando
    property int brightness: 0              // Porcentaje de brillo, leído de brightnessctl

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink ? sink.audio.muted : true
    readonly property int volume: sink ? Math.round(sink.audio.volume * 100) : 0

    readonly property int value: mode === "volume" ? (muted ? 0 : volume) : brightness

    // Mismos glifos que Volume.qml para el volumen
    readonly property string icon: {
        if (mode === "brightness") return String.fromCodePoint(0xF00DF)  // brightness-6
        if (muted || volume === 0) return String.fromCodePoint(0xF075F)  // volume-mute
        if (volume >= 66) return String.fromCodePoint(0xF057E)            // volume-high
        return String.fromCodePoint(0xF0580)                              // volume-medium
    }

    anchors.bottom: true
    margins.bottom: 10
    implicitWidth: 260
    implicitHeight: 48

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "reddots:osd"
    mask: Region {}                         // click-through: no roba ningún clic

    function show(newMode) {
        mode = newMode
        visible = true
        hideTimer.restart()                 // Si se sigue pulsando la tecla, se queda abierto
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.visible = false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        radius: Geometry.popupRounding          // Mismo estilo que los desplegables de la barra
        border.color: Theme.textSelected
        border.width: Geometry.popupBorderWidth

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12

            Text {
                text: root.icon
                color: Theme.textActive
                font.pixelSize: 20
                Layout.preferredWidth: 22
            }

            Rectangle {                         // Barra de nivel
                Layout.fillWidth: true
                implicitHeight: 8
                radius: 4
                color: Theme.background
                border.color: Theme.border

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * Math.min(root.value, 100) / 100
                    radius: parent.radius
                    color: root.mode === "volume" && root.muted ? Theme.textDisabled : Theme.textSelected
                }
            }

            Text {
                text: root.value + "%"
                color: Theme.textActive
                font.pixelSize: 11
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 32
            }
        }
    }

    // Quickshell no tiene servicio de brillo: se lee con brightnessctl. Se pide solo
    // la clase "backlight" porque, en un PC sin pantalla interna, sin ella devuelve un
    // LED del teclado. Si no hay backlight (sale con error), no se muestra nada.
    Process {
        id: brightnessProc
        command: ["brightnessctl", "-m", "-c", "backlight"]     // Salida: "equipo,clase,actual,45%,máximo"
        stdout: StdioCollector {
            onStreamFinished: {
                const percent = parseInt(text.split(",")[3])
                if (isNaN(percent)) return
                root.brightness = percent
                root.show("brightness")
            }
        }
    }

    IpcHandler {
        target: "osd"

        function volume(): void {
            root.show("volume")             // El valor se lee en vivo de Pipewire, aunque llegue un poco después
        }

        function brightness(): void {
            brightnessProc.running = false
            brightnessProc.running = true
        }
    }

    PwObjectTracker {                       // Mantiene enganchado el sink para que volume/muted estén al día
        objects: root.sink ? [root.sink] : []
    }
}
