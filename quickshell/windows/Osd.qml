// Indicador que aparece un momento abajo en el centro al cambiar el volumen o el
// brillo, o al silenciar el micrófono, con las teclas multimedia. Lo abren los atajos
// de hypr/keybinds.lua con "qs ipc call osd volume" / "... brightness" / "... mic"
// (igual que el Launcher con Super), así que solo sale con las teclas y no al mover
// el slider de la barra.

import Quickshell
import Quickshell.Io                  // Para el Process de brightnessctl
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

PanelWindow {
    id: root
    visible: false

    property string mode: "volume"          // "volume", "brightness" o "mic": qué se está mostrando
    property int brightness: 0              // Porcentaje de brillo, leído de brightnessctl

    // Volumen y micro, de services/Audio.qml (los mismos iconos que el popup de la barra)
    readonly property int value: mode === "volume" ? (Audio.muted ? 0 : Math.round(Audio.volume * 100))
                               : mode === "mic" ? (Audio.micMuted ? 0 : Math.round(Audio.micVolume * 100))
                               : brightness

    readonly property string icon: mode === "brightness" ? String.fromCodePoint(0xF00DF)   // brightness-6
                                 : mode === "mic" ? Audio.micIcon
                                 : Audio.volumeIcon

    anchors.bottom: true
    margins.bottom: 10
    implicitWidth: 260
    implicitHeight: 48

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "reddots:osd"
    mask: Region {}                         // Transparente a los clics: no roba ninguno

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

    Frame {                                     // Mismo estilo que los desplegables de la barra
        anchors.fill: parent

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

            Slider {                            // Barra de nivel con el porcentaje (la misma que en la barra, sin poder moverla)
                interactive: false
                barHeight: 8
                maxValue: root.mode === "volume" ? Audio.maxVolume : 1   // Con el aumento activado la barra llega a 150 %
                value: root.value / 100
                dimmed: (root.mode === "volume" && Audio.muted) || (root.mode === "mic" && Audio.micMuted)
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

    Connections {                   // "qs ipc call osd ..." desde las teclas (el IpcHandler está en services/ShellIpc.qml)
        target: ShellIpc
        function onOsdRequested(mode) {
            if (mode === "brightness") {    // El brillo hay que leerlo antes con brightnessctl, que luego lo muestra
                brightnessProc.running = false
                brightnessProc.running = true
            } else {
                root.show(mode)             // Volumen y micro: el valor se lee en vivo de Audio.qml, aunque llegue un poco después
            }
        }
    }
}
