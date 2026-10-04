// Launcher.qml
// Widget que aparece al pulsar Super solo (sin combinar con otra tecla), anclado abajo-derecha
// Lista las aplicaciones instaladas (con icono) y las lanza al hacer clic
// Al abrirse ya se puede escribir para filtrar: flechas para moverse, Intro para lanzar, Esc para cerrar

import Quickshell
import Quickshell.Io        // Para el JsonAdapter (cuántas veces se ha abierto cada app)
import Quickshell.Wayland
import Quickshell.Widgets  // Para el IconImage
import QtQuick
import QtQuick.Layouts     // Para RowLayout
import qs.components
import qs.services

OverlayWindow {             // Se cierra al hacer clic fuera (ver OverlayWindow.qml)
    id: root

    anchors { bottom: true; right: true }

    implicitWidth: 320
    implicitHeight: 480

    WlrLayershell.namespace: "reddots:launcher"

    onVisibleChanged: {
        if (visible) {
            searchInput.text = ""                       // Cada vez que se abre empieza sin filtro
            list.currentIndex = 0
            searchInput.input.forceActiveFocus()
        }
    }

    // Aplicaciones instaladas (sin las ocultas)
    property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay)

    // Qué tal coincide una app con lo escrito: cuanto más bajo, más arriba sale; -1 = no coincide.
    //   0: el nombre empieza por lo escrito                     ("fi" -> "Firefox")
    //   1: alguna palabra del nombre empieza por lo escrito     ("code" -> "Visual Studio Code")
    //   2: el nombre lo contiene en medio
    //   3: lo contiene el nombre genérico ("Navegador web") o las palabras clave del .desktop
    function matchRank(entry, query) {
        const name = Search.normalize(entry.name)
        if (name.startsWith(query)) return 0
        if (name.split(/[\s\-_.]+/).some(word => word.startsWith(query))) return 1
        if (name.includes(query)) return 2
        if (Search.normalize([entry.genericName, ...(entry.keywords || [])].join(" ")).includes(query)) return 3
        return -1
    }

    // Cuántas veces se ha abierto cada aplicación desde aquí, para sacar primero las que más
    // se usan. Se guarda en launcher.json (fuera del repo, junto a theme.json y
    // wallpaper.json), así que sobrevive a reiniciar Quickshell y a que esta ventana se
    // vuelva a crear al cerrar la tapa o cambiar de monitor: el recuento vive en el archivo.
    // La clave es el id del .desktop ("code", "org.kde.kate"...), no el nombre que se ve:
    // el nombre cambia con el idioma o al actualizar la app, el id no.
    StateFile {
        name: "launcher.json"
        blockLoading: true                              // Es un archivo diminuto: así el primer orden ya lo tiene en cuenta

        JsonAdapter {
            id: usage
            property var counts: ({})                   // id -> veces que se ha abierto (vacío hasta que se abre algo)
        }
    }

    // Lo que se ve en la lista. Sin nada escrito: primero las más usadas (ver "usage") y
    // luego el resto por nombre. Escribiendo: por cómo coinciden (matchRank) y, dentro de
    // cada grupo, igual: las más usadas primero y luego por nombre.
    property var filteredApps: {
        const query = Search.normalize(searchInput.text.trim())
        const list = apps.map(e => ({ entry: e, rank: query === "" ? 0 : matchRank(e, query), uses: usage.counts[e.id] ?? 0 }))
                         .filter(a => a.rank >= 0)
        list.sort((a, b) => a.rank - b.rank || b.uses - a.uses || a.entry.name.localeCompare(b.entry.name))
        return list.map(a => a.entry)
    }

    function launch(entry) {
        if (!entry) return
        // Para que la próxima vez salga más arriba. Objeto nuevo y no counts[id]++: si se
        // cambia por dentro, QML no se entera (ni se reordena la lista ni se guarda el archivo)
        const next = Object.assign({}, usage.counts)
        next[entry.id] = (next[entry.id] ?? 0) + 1
        usage.counts = next
        entry.execute()
        root.visible = false
    }

    Frame {                                     // Como los desplegables de la barra, pero solo con la esquina superior izquierda redondeada:
        id: background                          // el resto llega al borde de la pantalla
        anchors.fill: parent
        anchors.rightMargin: -border.width      // Los bordes derecho e inferior quedan fuera de la ventana: solo se ve el borde
        anchors.bottomMargin: -border.width     // de arriba y el de la izquierda, no una línea pegada al filo de la pantalla
        radius: 0
        topLeftRadius: 24
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            anchors.rightMargin: 12 + background.border.width   // Compensa el borde que queda fuera de la ventana
            anchors.bottomMargin: 12 + background.border.width
            spacing: 8

            InputField {                        // Campo de búsqueda: ↑ ↓ mueven la selección de la lista
                id: searchInput
                placeholder: "Buscar…"
                list: list
                onAccepted: root.launch(root.filteredApps[list.currentIndex])
                onEscapePressed: root.visible = false
            }

            SelectionList {
                id: list
                model: root.filteredApps
                onActivated: index => root.launch(root.filteredApps[index])

                delegate: Item {
                    required property var modelData
                    width: ListView.view.width
                    height: 44

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10

                        IconImage {
                            implicitSize: 28
                            source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: modelData.name
                            color: Theme.textActive
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }
        }
    }

    Connections {                   // Super: "qs ipc call launcher toggle" (el IpcHandler está en services/ShellIpc.qml)
        target: ShellIpc
        function onLauncherToggled() { root.visible = !root.visible }
    }
}
