import Quickshell
import Quickshell.Services.Pipewire   // Para el control de volumen (Pipewire)
import Quickshell.Hyprland            // Para el HyprlandFocusGrab
import Quickshell.Io                  // Para consultar la disponibilidad real de los puertos (Process/pactl)
import QtQuick
import QtQuick.Layouts                // Para usar RowLayout o ColumnLayout

// Icono de volumen en la barra + popup con slider y selector de salida de audio.
ColumnLayout{
    id: root
    spacing: 6

    // Al arrancar el widget, pedimos ya el estado de los puertos para que la
    // primera vez que se abra el menú no salga la lista sin filtrar un instante.
    Component.onCompleted: refreshPortAvailability()

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink ? sink.audio.muted : true
    readonly property real volume: sink ? sink.audio.volume : 0

    // --- Detección de salidas realmente conectadas ------------------------
    // Quickshell.Services.Pipewire no expone si un puerto (jack) tiene algo
    // enchufado (esa info vive en el Device/Route de PipeWire, no en el Node).
    // Por eso la pedimos por fuera con `pactl -f json list cards`, que sí la
    // da por puerto como "not available" / "available" / "availability unknown".
    //
    // portAvailability es un mapa "deviceId:portIndex" -> estado del puerto,
    // reconstruido cada vez que se llama a refreshPortAvailability().
    property var portAvailability: ({})

    // Clave común para cruzar el "device.id" / "card.profile.device" de un
    // PwNode con el "index" de tarjeta / "card.profile.port" de pactl.
    function keyForPort(deviceId, portIndex) {
        return String(deviceId) + ":" + String(portIndex)
    }

    // Relanza la consulta a pactl. Se llama al arrancar y cada vez que se
    // abre el menú (para reflejar un cable que se acaba de enchufar/quitar).
    function refreshPortAvailability() {
        portsProc.running = false
        portsProc.running = true
    }

    // Ejecuta `pactl -f json list cards` y parsea la disponibilidad de cada
    // puerto de cada tarjeta de sonido. Si pactl no existe o la salida no es
    // el JSON esperado, el catch deja portAvailability tal cual estaba y no
    // se filtra nada (fallback seguro: mejor mostrar de más que ocultar algo
    // que sí se pueda usar).
    Process {
        id: portsProc
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: {
                const avail = {}
                try {
                    const cards = JSON.parse(text)
                    for (const card of cards) {
                        const ports = card.ports || {}
                        for (const portName in ports) {
                            const port = ports[portName]
                            const props = port.properties || {}
                            const idx = props["card.profile.port"]
                            if (idx === undefined) continue
                            avail[root.keyForPort(card.index, idx)] = port.availability
                        }
                    }
                } catch (e) {
                    // pactl no disponible o salida inesperada: no filtramos nada
                }
                root.portAvailability = avail
            }
        }
    }

    // --- Lista de sinks -----------------------------------------------------
    // IMPORTANTE: esta lista SOLO depende de propiedades constantes de PwNode
    // (isSink / isStream, marcadas isPropertyConstant en el plugin). Es la que
    // se pasa a PwObjectTracker más abajo, que es quien engancha/mantiene
    // vivos los nodos de PipeWire.
    //
    // Si esta lista dependiera de algo mutable -como n.properties o
    // portAvailability-, se forma un bucle: trackear un nodo hace que
    // PipeWire rellene/actualice sus properties -> se emite propertiesChanged
    // -> se recalcula esta lista -> cambia el array pasado a
    // PwObjectTracker.objects -> vuelve a (re)trackear -> bucle infinito.
    // Eso es justo lo que provocó el "Binding loop detected for property
    // sinks" y el crash de quickshell la primera vez que se probó el filtro
    // aquí mismo. La lección: todo lo que alimente a PwObjectTracker.objects
    // debe depender solo de propiedades constantes.
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)

    // Lista SOLO para pintar el menú (Repeater.model). Aquí sí es seguro leer
    // n.properties y portAvailability, porque nada de esto retroalimenta al
    // PwObjectTracker: como mucho, el menú se repinta cuando cambian.
    // Oculta los sinks cuyo puerto físico está marcado "not available" (nada
    // conectado, p.ej. una salida HDMI sin monitor). Si un sink no tiene
    // device.id/card.profile.device (p.ej. un dispositivo USB o Bluetooth) o
    // pactl no ha respondido todavía, se muestra igualmente por seguridad.
    readonly property var visibleSinks: root.sinks.filter(n => {
        const props = n.properties || {}
        const deviceId = props["device.id"]
        const portIndex = props["card.profile.device"]
        if (deviceId === undefined || portIndex === undefined) return true

        const state = root.portAvailability[root.keyForPort(deviceId, portIndex)]
        return state !== "not available"
    })

    function setVolume(fraction) {
        if (!root.sink) return
        const v = Math.max(0, Math.min(1, fraction))
        root.sink.audio.volume = v
        if (v > 0) root.sink.audio.muted = false
    }

    // Icono según estado de mute/volumen (glifos de Nerd Font).
    readonly property string icon: {
        if (!sink || muted) return String.fromCodePoint(0xF075F)  // volume-mute
        if (volume >= 0.66) return String.fromCodePoint(0xF057E)  // volume-high
        if (volume > 0)     return String.fromCodePoint(0xF0580)  // volume-medium
        return String.fromCodePoint(0xF057F)                      // volume-low
    }

    // Icono en la barra: click izquierdo abre/cierra el menú, click derecho
    // silencia/desilencia directamente sin abrir nada.
    Text{
        id: iconText
        text: root.icon
        color: root.muted ? Theme.textDisabled : Theme.textActive
        font.pixelSize: 18

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: event => {
                if (event.button === Qt.RightButton) {
                    if (root.sink) root.sink.audio.muted = !root.sink.audio.muted
                } else {
                    menu.visible = !menu.visible
                }
            }
        }
    }

    // Popup con el slider de volumen y la lista de salidas de audio.
    PopupWindow {
        id: menu
        visible: false
        color: "transparent"

        anchor.item: iconText
        anchor.rect.y: iconText.height + 8
        anchor.gravity: Edges.Bottom

        implicitWidth: 240
        implicitHeight: Math.max(40, listCol.implicitHeight + 16)

        onVisibleChanged: {
            if (visible) {
                // Refrescamos la disponibilidad de puertos cada vez que se
                // abre el menú, por si se ha conectado/desconectado algo
                // (monitor HDMI, auriculares...) desde la última vez.
                root.refreshPortAvailability()
                grabTimer.restart()
            } else {
                grabTimer.stop()
                grab.active = false
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.surface
            radius: 8
            border.color: Theme.border

            ColumnLayout {
                id: listCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                // Slider de volumen: arrastrar o hacer scroll sobre la barra.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        id: sliderTrack
                        Layout.fillWidth: true
                        implicitHeight: 14
                        radius: 7
                        color: Theme.background
                        border.color: Theme.border

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * Math.min(root.volume, 1)
                            radius: parent.radius
                            color: root.muted ? Theme.textDisabled : Theme.textSelected
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: mouse => root.setVolume(mouse.x / width)
                            onPositionChanged: mouse => { if (pressed) root.setVolume(mouse.x / width) }
                            onWheel: wheel => root.setVolume(root.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                        }
                    }

                    Text {
                        text: Math.round(Math.min(root.volume, 1) * 100) + "%"
                        color: Theme.textActive
                        font.pixelSize: 11
                        Layout.preferredWidth: 32
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.border
                }

                // Mensaje cuando, tras filtrar, no queda ninguna salida usable.
                Text {
                    Layout.fillWidth: true
                    visible: root.visibleSinks.length === 0
                    text: "Sin salidas de audio"
                    color: Theme.textDisabled
                }

                // Lista de salidas de audio disponibles (ya filtrada). Usamos
                // "nickname" (p.ej. "HDMI 1", "Speaker") en vez de
                // "description" porque varias salidas del mismo chip
                // comparten un prefijo larguísimo ("500 Series Chipset
                // Family HD Audio ...") y, con el ancho fijo del popup y el
                // elide, se veían todas cortadas igual (parecían la misma
                // opción repetida 4 veces).
                Repeater {
                    model: root.visibleSinks

                    delegate: Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 26
                        radius: 4
                        color: outMouse.containsMouse ? Theme.surfaceHover : "transparent"

                        Text {
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 12
                            text: (modelData === root.sink ? "✓ " : "") + (modelData.nickname || modelData.description || modelData.name)
                            color: modelData === root.sink ? Theme.textSelected : Theme.textActive
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: outMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                Pipewire.preferredDefaultAudioSink = modelData
                                menu.visible = false
                            }
                        }
                    }
                }
            }
        }
    }

    // Cierra el menú al hacer click fuera de él (grabTimer da un frame de
    // margen antes de activar el grab para no cerrarlo con el mismo click
    // que lo abrió).
    HyprlandFocusGrab {
        id: grab
        windows: [menu]
        active: false
        onCleared: menu.visible = false
    }

    Timer {
        id: grabTimer
        interval: 5
        onTriggered: grab.active = true
    }

    // Mantiene vivos/suscritos los nodos de PipeWire que nos interesan.
    // Ligado a `sinks` (la lista SIN filtrar) a propósito: ver el comentario
    // de más arriba sobre el bucle de bindings.
    PwObjectTracker {
        objects: root.sinks
    }
}
