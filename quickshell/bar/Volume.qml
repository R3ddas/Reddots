// Icono de volumen en la barra + popup con cuatro partes: lo que se está reproduciendo
// (NowPlaying.qml, solo si hay algún reproductor abierto), la salida (volumen y a qué altavoz/auricular
// va), el micrófono (volumen y cuál se usa) y el volumen de cada aplicación que está sonando.
//   Clic izquierdo: abre/cierra el popup
//   Clic derecho: silencia/quita el silencio sin abrir nada
import Quickshell
import Quickshell.Services.Pipewire   // Para el control de volumen (Pipewire)
import Quickshell.Io                  // Para consultar la disponibilidad real de los puertos (Process/pactl)
import Quickshell.Widgets             // Para el IconImage de las aplicaciones
import QtQuick
import QtQuick.Layouts                // Para usar RowLayout o ColumnLayout
import qs.components
import qs.services

ColumnLayout{
    id: root
    spacing: 6

    // Al crearse el icono se pide ya el estado de los puertos, para que la primera vez
    // que se abra el menú no salga un instante la lista sin filtrar.
    Component.onCompleted: refreshPortAvailability()

    // La salida y el micrófono que se usan (con su volumen, su silencio y su icono) y el
    // aumento hasta el 150 % están en services/Audio.qml: los comparten las teclas de volumen
    // y el indicador (Osd.qml).

    // --- Salidas que de verdad tienen algo enchufado ----------------------
    // Quickshell.Services.Pipewire no dice si un puerto (un jack) tiene algo enchufado:
    // eso está en el Device/Route de PipeWire, no en el Node. Por eso se pregunta aparte
    // con `pactl -f json list cards`, que sí lo da por puerto: "not available",
    // "available" o "availability unknown".
    //
    // portAvailability: "deviceId:portIndex" -> estado del puerto. Se rehace entero cada
    // vez que se llama a refreshPortAvailability().
    property var portAvailability: ({})

    // Clave común para cruzar el "device.id" y el "card.profile.device" de un PwNode con
    // el "index" de la tarjeta y el "card.profile.port" de pactl.
    function keyForPort(deviceId, portIndex) {
        return String(deviceId) + ":" + String(portIndex)
    }

    // Vuelve a preguntar a pactl. Se llama al arrancar y cada vez que se abre el menú
    // (por si se acaba de enchufar o quitar un cable).
    function refreshPortAvailability() {
        portsProc.running = false
        portsProc.running = true
    }

    // Lanza `pactl -f json list cards` y lee si cada puerto de cada tarjeta de sonido
    // tiene algo enchufado. Si pactl no está o no devuelve el JSON esperado, la lista
    // queda vacía y no se filtra nada: mejor enseñar de más que esconder una salida que
    // sí se pueda usar.
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
                    // Sin pactl o con una salida rara: no se filtra nada
                }
                root.portAvailability = avail
            }
        }
    }

    // --- Listas de nodos ----------------------------------------------------
    // Ojo: estas tres listas dependen SOLO de propiedades de PwNode que no cambian nunca
    // (isSink e isStream, constantes en Quickshell). Son las que se le pasan al
    // PwObjectTracker de más abajo, que es quien engancha los nodos de PipeWire y los
    // mantiene al día.
    //
    // Si dependieran de algo que cambia (n.properties, portAvailability...), se formaría un
    // bucle: enganchar un nodo hace que PipeWire rellene sus properties -> avisa con
    // propertiesChanged -> se recalcula la lista -> cambia lo que recibe
    // PwObjectTracker.objects -> vuelve a engancharlos -> y así sin fin. Es lo que pasó la
    // primera vez que se puso aquí el filtro: "Binding loop detected for property sinks" y
    // Quickshell se cerró. Todo lo que llegue a PwObjectTracker.objects tiene que depender
    // solo de propiedades que no cambian.
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)      // Altavoces, auriculares, HDMI...
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream)   // Micrófonos (y nodos sin audio, que se quitan al pintar)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isSink && n.isStream)     // Aplicaciones que están sonando

    // El puerto de este nodo está marcado "not available": no tiene nada enchufado (p.ej.
    // una salida HDMI sin monitor). Si el nodo no tiene device.id o card.profile.device
    // (un dispositivo USB o Bluetooth) o pactl aún no ha respondido, se da por enchufado,
    // por si acaso.
    function isUnplugged(n) {
        const props = n.properties || {}
        const deviceId = props["device.id"]
        const portIndex = props["card.profile.device"]
        if (deviceId === undefined || portIndex === undefined) return false
        return root.portAvailability[root.keyForPort(deviceId, portIndex)] === "not available"
    }

    // Listas SOLO para pintar el menú (el model de los Repeater). Aquí sí se pueden leer
    // n.properties, n.audio y portAvailability: nada de esto llega al PwObjectTracker, así
    // que como mucho el menú se vuelve a pintar cuando cambian.
    readonly property var visibleSinks: root.sinks.filter(n => !root.isUnplugged(n))
    readonly property var visibleSources: root.sources.filter(n => n.audio && !root.isUnplugged(n))   // Sin audio = nodos MIDI y similares
    readonly property var visibleStreams: root.streams.filter(n => n.audio)

    // Volumen de un nodo (salida, micrófono o aplicación), entre 0 y max (1 salvo en la salida con
    // el aumento activado). Subirlo quita el silencio.
    function setNodeVolume(node, fraction, max = 1) {
        if (!node || !node.audio) return
        const v = Math.max(0, Math.min(max, fraction))
        node.audio.volume = v
        if (v > 0) node.audio.muted = false
    }

    // Nombre de una aplicación: el que da ella misma ("Google Chrome"), o el del nodo
    function appName(n) {
        const props = n.properties || {}
        return props["application.name"] || n.description || n.name
    }

    // Icono en la barra: el clic izquierdo abre o cierra el menú, y el derecho silencia
    // o quita el silencio sin abrir nada.
    BarIcon {
        id: iconText
        text: Audio.volumeIcon
        color: Audio.muted ? Theme.textDisabled : Theme.textActive
        tooltip: !Audio.sink ? ""
               : (Audio.muted ? "Silenciado" : "Volumen " + Math.round(Audio.volume * 100) + " %")
                 + " · " + (Audio.sink.nickname || Audio.sink.description || Audio.sink.name)
                 + (Audio.source && Audio.micMuted ? "\nMicrófono silenciado" : "")
                 + (nowPlaying.player && nowPlaying.player.isPlaying && nowPlaying.player.trackTitle     // "Sonando: Canción · Artista"
                    ? "\nSonando: " + nowPlaying.player.trackTitle + (nowPlaying.player.trackArtist ? " · " + nowPlaying.player.trackArtist : "") : "")
        popup: menu
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => { if (event.button === Qt.RightButton && Audio.sink) Audio.sink.audio.muted = !Audio.sink.audio.muted }
    }

    // --- Piezas del popup ----------------------------------------------------

    // Título de cada parte (Salida, Micrófono, Aplicaciones)
    component PartTitle: Text {
        color: Theme.textDisabled
        font.pixelSize: 11
        font.bold: true
        Layout.fillWidth: true
    }

    // Icono a la izquierda de un slider: al pulsarlo silencia ese nodo o le quita el silencio
    component MuteIcon: TextButton {
        id: muteIcon
        property var node: null
        readonly property bool isMuted: !node || !node.audio || node.audio.muted
        color: isMuted ? Theme.textDisabled : Theme.textActive
        font.pixelSize: 16
        Layout.preferredWidth: 20
        horizontalAlignment: Text.AlignHCenter
        onClicked: if (node && node.audio) node.audio.muted = !node.audio.muted
    }

    // Una salida o un micrófono de la lista: con ✓ y el color de acento el que se está usando.
    // Con "nickname" (p.ej. "HDMI 1", "Speaker") en vez de "description" porque varias
    // salidas del mismo chip comparten un prefijo larguísimo ("500 Series Chipset Family HD
    // Audio ...") y, con el ancho fijo del popup y el elide, se veían todas cortadas igual
    // (parecían la misma opción repetida 4 veces).
    component DeviceRow: MenuRow {
        property var node
        property bool current: false
        icon: current ? "✓" : ""
        selected: current
        text: node.nickname || node.description || node.name
    }

    component PartSeparator: Separator { Layout.topMargin: 4; Layout.bottomMargin: 2 }    // Entre parte y parte

    BarPopup {
        id: menu
        anchorItem: iconText
        implicitWidth: 260

        // Se vuelve a mirar qué puertos tienen algo enchufado cada vez que se abre el menú,
        // por si se ha enchufado o quitado algo (un monitor HDMI, unos auriculares...).
        onVisibleChanged: if (visible) root.refreshPortAvailability()

        // --- Reproduciendo (solo si hay algún reproductor abierto) ---
        NowPlaying {
            id: nowPlaying
            popupOpen: menu.visible
            onRaised: menu.visible = false              // Que el popup no tape al reproductor
        }

        PartSeparator { visible: nowPlaying.player !== null }

        // --- Salida ---
        RowLayout {                             // Título + interruptor del aumento (en la misma línea: no ocupa espacio extra)
            Layout.fillWidth: true
            PartTitle { text: "Salida" }
            TextButton {                        // Resaltado cuando está activo; pasar de 100 % solo se puede con él
                text: Audio.boost ? "<150%" : "<100%"      // Muestra el tope actual; al pulsar cambia al otro
                font.pixelSize: 11
                font.bold: Audio.boost
                color: Audio.boost ? Theme.textSelected : (hovered ? Theme.textActive : Theme.textDisabled)
                onClicked: Audio.setBoost(!Audio.boost)
            }
        }

        RowLayout {                             // Silenciar + volumen (arrastrar o rueda)
            Layout.fillWidth: true
            spacing: 6
            MuteIcon { node: Audio.sink; text: Audio.volumeIcon }
            Slider {
                maxValue: Audio.maxVolume
                value: Audio.volume
                dimmed: Audio.muted
                onMoved: v => root.setNodeVolume(Audio.sink, v, Audio.maxVolume)
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
                current: modelData === Audio.sink
                onClicked: {
                    Pipewire.preferredDefaultAudioSink = modelData
                    menu.visible = false
                }
            }
        }

        // --- Micrófono ---
        PartSeparator {}
        PartTitle { text: "Micrófono" }

        RowLayout {
            visible: Audio.source !== null
            Layout.fillWidth: true
            spacing: 6
            MuteIcon { node: Audio.source; text: Audio.micIcon }
            Slider {
                value: Audio.micVolume
                dimmed: Audio.micMuted
                onMoved: v => root.setNodeVolume(Audio.source, v)
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
                current: modelData === Audio.source
                onClicked: {
                    Pipewire.preferredDefaultAudioSource = modelData
                    menu.visible = false
                }
            }
        }

        // --- Aplicaciones (solo si hay alguna sonando) ---
        PartSeparator { visible: root.visibleStreams.length > 0 }
        PartTitle { visible: root.visibleStreams.length > 0; text: "Aplicaciones" }

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

    // Engancha los nodos de PipeWire que se usan aquí, para que estén al día. Con las
    // listas SIN filtrar a propósito: ver arriba lo del bucle.
    PwObjectTracker {
        objects: root.sinks.concat(root.sources, root.streams)
    }
}
