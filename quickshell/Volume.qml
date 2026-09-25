import Quickshell
import Quickshell.Services.Pipewire   // Para el control de volumen (Pipewire)
import Quickshell.Io                  // Para consultar la disponibilidad real de los puertos (Process/pactl)
import Quickshell.Widgets             // Para el IconImage de las aplicaciones
import QtQuick
import QtQuick.Layouts                // Para usar RowLayout o ColumnLayout

// Icono de volumen en la barra + popup con tres partes: la salida (volumen y a qué
// altavoz/auricular va), el micrófono (volumen y cuál se usa) y el volumen de cada
// aplicación que está sonando.
ColumnLayout{
    id: root
    spacing: 6

    // Al arrancar el widget, pedimos ya el estado de los puertos para que la
    // primera vez que se abra el menú no salga la lista sin filtrar un instante.
    Component.onCompleted: refreshPortAvailability()

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink ? sink.audio.muted : true
    readonly property real volume: sink ? sink.audio.volume : 0

    readonly property var source: Pipewire.defaultAudioSource              // El micrófono que se usa
    readonly property bool micMuted: source ? source.audio.muted : true

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

    // --- Listas de nodos ----------------------------------------------------
    // IMPORTANTE: estas tres listas SOLO dependen de propiedades constantes de
    // PwNode (isSink / isStream, marcadas isPropertyConstant en el plugin). Son
    // las que se pasan a PwObjectTracker más abajo, que es quien engancha/mantiene
    // vivos los nodos de PipeWire.
    //
    // Si dependieran de algo mutable -como n.properties o portAvailability-, se
    // forma un bucle: trackear un nodo hace que PipeWire rellene/actualice sus
    // properties -> se emite propertiesChanged -> se recalcula la lista -> cambia
    // el array pasado a PwObjectTracker.objects -> vuelve a (re)trackear -> bucle
    // infinito. Eso es justo lo que provocó el "Binding loop detected for property
    // sinks" y el crash de quickshell la primera vez que se probó el filtro aquí
    // mismo. La lección: todo lo que alimente a PwObjectTracker.objects debe
    // depender solo de propiedades constantes.
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)      // Altavoces, auriculares, HDMI...
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream)   // Micrófonos (y nodos sin audio, que se quitan al pintar)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isSink && n.isStream)     // Aplicaciones que están sonando

    // ¿El puerto físico de este nodo está marcado "not available" (nada
    // conectado, p.ej. una salida HDMI sin monitor)? Si el nodo no tiene
    // device.id/card.profile.device (p.ej. un dispositivo USB o Bluetooth) o
    // pactl no ha respondido todavía, se da por conectado por seguridad.
    function isUnplugged(n) {
        const props = n.properties || {}
        const deviceId = props["device.id"]
        const portIndex = props["card.profile.device"]
        if (deviceId === undefined || portIndex === undefined) return false
        return root.portAvailability[root.keyForPort(deviceId, portIndex)] === "not available"
    }

    // Listas SOLO para pintar el menú (Repeater.model). Aquí sí es seguro leer
    // n.properties, n.audio y portAvailability, porque nada de esto retroalimenta
    // al PwObjectTracker: como mucho, el menú se repinta cuando cambian.
    readonly property var visibleSinks: root.sinks.filter(n => !root.isUnplugged(n))
    readonly property var visibleSources: root.sources.filter(n => n.audio && !root.isUnplugged(n))   // Sin audio = nodos MIDI y similares
    readonly property var visibleStreams: root.streams.filter(n => n.audio)

    // Volumen de un nodo (salida, micrófono o aplicación), entre 0 y 1. Subirlo quita el silencio.
    function setNodeVolume(node, fraction) {
        if (!node || !node.audio) return
        const v = Math.max(0, Math.min(1, fraction))
        node.audio.volume = v
        if (v > 0) node.audio.muted = false
    }

    // Nombre de una aplicación: el que da ella misma ("Google Chrome"), o el del nodo
    function appName(n) {
        const props = n.properties || {}
        return props["application.name"] || n.description || n.name
    }

    // Icono según estado de mute/volumen (glifos de Nerd Font).
    // Tres tramos: por debajo de 1/3 bajo, hasta 2/3 medio y de ahí para arriba alto (igual que en Osd.qml).
    readonly property string icon: {
        if (!sink || muted || volume === 0) return String.fromCodePoint(0xF075F)  // volume-mute
        if (volume >= 0.66) return String.fromCodePoint(0xF057E)                  // volume-high
        if (volume >= 0.33) return String.fromCodePoint(0xF0580)                  // volume-medium
        return String.fromCodePoint(0xF057F)                                      // volume-low
    }
    readonly property string micIcon: String.fromCodePoint(micMuted ? 0xF036D : 0xF036C)   // microphone-off / microphone

    // Icono en la barra: click izquierdo abre/cierra el menú, click derecho
    // silencia/desilencia directamente sin abrir nada.
    BarIcon {
        id: iconText
        text: root.icon
        color: root.muted ? Theme.textDisabled : Theme.textActive
        tooltip: menu.visible || !root.sink ? ""
               : (root.muted ? "Silenciado" : "Volumen " + Math.round(Math.min(root.volume, 1) * 100) + " %")
                 + " · " + (root.sink.nickname || root.sink.description || root.sink.name)
                 + (root.source && root.micMuted ? "\nMicrófono silenciado" : "")
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton) {
                if (root.sink) root.sink.audio.muted = !root.sink.audio.muted
            } else {
                menu.toggle()
            }
        }
    }

    // --- Piezas del popup ----------------------------------------------------

    // Título de cada parte (Salida, Micrófono, Aplicaciones)
    component SectionTitle: Text {
        color: Theme.textDisabled
        font.pixelSize: 11
        font.bold: true
        Layout.fillWidth: true
    }

    // Icono a la izquierda de un slider: al pulsarlo silencia/desilencia ese nodo
    component MuteIcon: Text {
        id: muteIcon
        property var node: null
        readonly property bool isMuted: !node || !node.audio || node.audio.muted
        color: isMuted ? Theme.textDisabled : Theme.textActive
        font.pixelSize: 16
        Layout.preferredWidth: 20
        horizontalAlignment: Text.AlignHCenter
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            onClicked: if (muteIcon.node && muteIcon.node.audio) muteIcon.node.audio.muted = !muteIcon.node.audio.muted
        }
    }

    // Una salida o un micrófono de la lista: con ✓ y el color de acento el que se está usando
    component DeviceRow: Rectangle {
        id: deviceRow
        property var node
        property bool current: false
        signal picked()

        Layout.fillWidth: true
        implicitHeight: 26
        radius: 4
        color: deviceMouse.containsMouse ? Theme.surfaceHover : "transparent"

        // Usamos "nickname" (p.ej. "HDMI 1", "Speaker") en vez de "description"
        // porque varias salidas del mismo chip comparten un prefijo larguísimo
        // ("500 Series Chipset Family HD Audio ...") y, con el ancho fijo del
        // popup y el elide, se veían todas cortadas igual (parecían la misma
        // opción repetida 4 veces).
        Text {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 12
            text: (deviceRow.current ? "✓ " : "") + (deviceRow.node.nickname || deviceRow.node.description || deviceRow.node.name)
            color: deviceRow.current ? Theme.textSelected : Theme.textActive
            elide: Text.ElideRight
        }

        MouseArea {
            id: deviceMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: deviceRow.picked()
        }
    }

    component Separator: Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.bottomMargin: 2
        implicitHeight: 1
        color: Theme.border
    }

    BarPopup {
        id: menu
        anchorItem: iconText
        implicitWidth: 260
        implicitHeight: Math.max(40, listCol.implicitHeight + 16)

        // Refrescamos la disponibilidad de puertos cada vez que se abre el
        // menú, por si se ha conectado/desconectado algo (monitor HDMI,
        // auriculares...) desde la última vez.
        onVisibleChanged: if (visible) root.refreshPortAvailability()

        ColumnLayout {
            id: listCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            // --- Salida ---
            SectionTitle { text: "Salida" }

            RowLayout {                             // Silenciar + volumen (arrastrar o rueda)
                Layout.fillWidth: true
                spacing: 6
                MuteIcon { node: root.sink; text: root.icon }
                Slider {
                    value: root.volume
                    dimmed: root.muted
                    onMoved: v => root.setNodeVolume(root.sink, v)
                }
            }

            Text {                                  // Cuando, tras filtrar, no queda ninguna salida usable
                Layout.fillWidth: true
                visible: root.visibleSinks.length === 0
                text: "Sin salidas de audio"
                color: Theme.textDisabled
            }

            Repeater {
                model: root.visibleSinks
                delegate: DeviceRow {
                    required property var modelData
                    node: modelData
                    current: modelData === root.sink
                    onPicked: {
                        Pipewire.preferredDefaultAudioSink = modelData
                        menu.visible = false
                    }
                }
            }

            // --- Micrófono ---
            Separator {}
            SectionTitle { text: "Micrófono" }

            RowLayout {
                visible: root.source !== null
                Layout.fillWidth: true
                spacing: 6
                MuteIcon { node: root.source; text: root.micIcon }
                Slider {
                    value: root.source ? root.source.audio.volume : 0
                    dimmed: root.micMuted
                    onMoved: v => root.setNodeVolume(root.source, v)
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.visibleSources.length === 0
                text: "Sin micrófonos"
                color: Theme.textDisabled
            }

            Repeater {
                model: root.visibleSources
                delegate: DeviceRow {
                    required property var modelData
                    node: modelData
                    current: modelData === root.source
                    onPicked: {
                        Pipewire.preferredDefaultAudioSource = modelData
                        menu.visible = false
                    }
                }
            }

            // --- Aplicaciones (solo si hay alguna sonando) ---
            Separator { visible: root.visibleStreams.length > 0 }
            SectionTitle { visible: root.visibleStreams.length > 0; text: "Aplicaciones" }

            Repeater {
                model: root.visibleStreams
                delegate: RowLayout {
                    id: appRow
                    required property var modelData
                    readonly property bool appMuted: modelData.audio.muted
                    Layout.fillWidth: true
                    spacing: 6

                    IconImage {                     // Icono de la app; al pulsarlo la silencia
                        implicitSize: 18
                        source: Quickshell.iconPath((appRow.modelData.properties || {})["application.icon-name"] ?? "", "audio-x-generic")
                        opacity: appRow.appMuted ? 0.35 : 1
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 20
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            onClicked: appRow.modelData.audio.muted = !appRow.modelData.audio.muted
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: root.appName(appRow.modelData)
                            color: appRow.appMuted ? Theme.textDisabled : Theme.textActive
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Slider {
                            barHeight: 10
                            value: appRow.modelData.audio.volume
                            dimmed: appRow.appMuted
                            onMoved: v => root.setNodeVolume(appRow.modelData, v)
                        }
                    }
                }
            }
        }
    }

    // Mantiene vivos/suscritos los nodos de PipeWire que nos interesan.
    // Ligado a las listas SIN filtrar a propósito: ver el comentario de más
    // arriba sobre el bucle de bindings.
    PwObjectTracker {
        objects: root.sinks.concat(root.sources, root.streams)
    }
}
