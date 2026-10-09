// Widget que aparece al pulsar Super solo (sin combinar con otra tecla), anclado abajo-derecha
// Lista las aplicaciones instaladas (con icono) y las lanza al hacer clic
// Al abrirse ya se puede escribir para filtrar: flechas para moverse, Intro para lanzar, Esc para cerrar
// La rueda junto al buscador pasa a elegir qué apps se ocultan (ver "editing") o se desinstalan (UninstallPanel.qml)

import Quickshell
import Quickshell.Io        // Para el JsonAdapter (cuántas veces se ha abierto cada app y cuáles se ocultan)
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
            editing = false                             // ...y lanzando apps, no ocultándolas
            uninstallPanel.cancel()                     // ...y sin el aviso de desinstalar de la vez anterior (salvo si sigue desinstalando)
            list.currentIndex = 0
            searchInput.input.forceActiveFocus()
        }
    }

    // Con la rueda activada, la lista es para elegir qué apps se ocultan: salen también las
    // ocultas (atenuadas) y al pulsar una (clic o Intro) se oculta o se vuelve a mostrar en
    // vez de abrirse. Se sale con la rueda otra vez o con Esc, y al cerrar el launcher.
    property bool editing: false

    // Aplicaciones instaladas. Sin las que el propio .desktop pide no mostrar (NoDisplay:
    // ajustes internos, ayudantes de otras apps...), que no se pueden ni elegir, ni las
    // ocultadas desde aquí, salvo mientras se eligen.
    property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay && (editing || !isHidden(e)))

    function isHidden(entry) { return usage.hidden.includes(entry.id) }

    // Oculta la app o la vuelve a mostrar. Lista nueva y no push/splice, por lo mismo que en
    // launch(): si se cambia por dentro, QML no se entera
    function toggleHidden(entry) {
        if (!entry) return
        usage.hidden = isHidden(entry) ? usage.hidden.filter(id => id !== entry.id)
                                       : [...usage.hidden, entry.id]
    }

    // Intro o clic en una fila: abrirla u ocultarla/mostrarla, según el modo
    function activate(entry) {
        if (editing) toggleHidden(entry)
        else launch(entry)
    }

    // Qué tal coincide una app con lo escrito: cuanto más bajo, más arriba sale; -1 = no coincide.
    //   0: el nombre empieza por lo escrito                     ("fi" -> "Firefox")
    //   1: alguna palabra del nombre empieza por lo escrito     ("code" -> "Visual Studio Code")
    //   2: el nombre lo contiene en medio
    //   3: lo contiene el nombre genérico ("Navegador web") o las palabras clave del .desktop
    function matchRank(entry, query) {
        const name = Utils.normalize(entry.name)
        if (name.startsWith(query)) return 0
        if (name.split(/[\s\-_.]+/).some(word => word.startsWith(query))) return 1
        if (name.includes(query)) return 2
        if (Utils.normalize([entry.genericName, ...(entry.keywords || [])].join(" ")).includes(query)) return 3
        return -1
    }

    // Cuántas veces se ha abierto cada aplicación desde aquí, para sacar primero las que más
    // se usan, y cuáles se han ocultado con la rueda. Se guarda en launcher.json (fuera del repo, junto a theme.json y
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
            property var hidden: []                     // ids de las apps ocultas. Sustituye a la lista que había en install.sh (hidden_apps.txt):
                                                        // así se cambia sin tocar el repo ni reinstalar, y cada equipo tiene la suya
        }
    }

    // Lo que se ve en la lista. Sin nada escrito: primero las más usadas (ver "usage") y
    // luego el resto por nombre. Escribiendo: por cómo coinciden (matchRank) y, dentro de
    // cada grupo, igual: las más usadas primero y luego por nombre.
    property var filteredApps: {
        const query = Utils.normalize(searchInput.text.trim())
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

            RowLayout {
                spacing: 8

                InputField {                    // Campo de búsqueda: ↑ ↓ mueven la selección de la lista
                    id: searchInput
                    placeholder: root.editing ? "Buscar app para ocultar…" : "Buscar…"
                    list: list
                    // Con el aviso de desinstalar abierto, Intro es su botón principal (ver más abajo)
                    onAccepted: {
                        if (uninstallPanel.request) uninstallPanel.primary()
                        else root.activate(root.filteredApps[list.currentIndex])
                    }
                    // Esc primero cierra el aviso de desinstalar, luego sale de elegir las ocultas
                    // (como si se pulsara la rueda) y por último cierra el launcher
                    onEscapePressed: {
                        if (uninstallPanel.request) uninstallPanel.cancel()
                        else if (root.editing) root.editing = false
                        else root.visible = false
                    }
                    onKeyPressed: event => {
                        // Shift + Supr como en el portapapeles: Supr sola borra letras del buscador
                        if (root.editing && event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                            uninstallPanel.ask(root.filteredApps[list.currentIndex])
                            event.accepted = true
                        }
                    }
                }

                // Rueda: entra y sale de elegir las ocultas. Con el color de acento mientras se
                // eligen, para que se note que al pulsar una fila no se va a abrir.
                // El clic no le quita el foco al buscador (un MouseArea no lo coge): se puede
                // seguir escribiendo sin volver a pulsar en el campo.
                TextButton {
                    text: String.fromCodePoint(0xF0493)     // cog
                    font.pixelSize: 18
                    color: root.editing ? Theme.textSelected : hovered ? Theme.textActive : Theme.textDisabled
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: {
                        root.editing = !root.editing
                        uninstallPanel.cancel()     // El aviso de desinstalar es del modo de elegir: se va con él
                    }
                }
            }

            SelectionList {
                id: list
                model: root.filteredApps
                onActivated: index => root.activate(root.filteredApps[index])

                delegate: Item {
                    id: appDelegate
                    required property var modelData
                    // Depende de usage.hidden (lo lee isHidden), así que cambia en cuanto se pulsa la fila.
                    // Solo puede ser true eligiendo las ocultas: si no, las ocultas no están en la lista
                    readonly property bool hidden: root.isHidden(modelData)
                    width: ListView.view.width
                    height: 44

                    // El clic lo recoge la lista entera (SelectionList.qml), que pregunta aquí antes:
                    // si cae en la papelera es para desinstalar, no para ocultar
                    function handleClick(x, y) {
                        if (!trash.visible || !trash.contains(trash.mapFromItem(appDelegate, x, y))) return false
                        uninstallPanel.ask(modelData)
                        return true
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10
                        opacity: appDelegate.hidden ? 0.4 : 1   // Atenuada, pero se sigue viendo para poder volver a mostrarla

                        IconImage {
                            implicitSize: 28
                            source: Quickshell.iconPath(appDelegate.modelData.icon, "application-x-executable")
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: appDelegate.modelData.name
                            color: Theme.textActive
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {                              // Solo eligiendo las ocultas: si se ve o no en el launcher.
                            visible: root.editing           // Es solo un indicador: el clic lo recoge la lista (toda la fila)
                            text: String.fromCodePoint(appDelegate.hidden ? 0xF0209 : 0xF0208)    // eye-off / eye
                            color: Theme.textActive
                            font.pixelSize: 16
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {                              // Desinstalar (ver handleClick): solo eligiendo las ocultas
                            id: trash
                            visible: root.editing
                            text: String.fromCodePoint(0xF0A7A)     // trash-can-outline
                            // Marcada la de la app del aviso de desinstalar, para saber de cuál es
                            color: uninstallPanel.request?.entry === appDelegate.modelData ? Theme.textSelected : Theme.textActive
                            font.pixelSize: 16
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }

            Text {                                  // Recordatorio mientras se eligen las ocultas (como el de Clipboard.qml)
                visible: root.editing && !uninstallPanel.request
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Intro o clic: ocultar / mostrar   ·   Esc: volver\nShift + Supr o papelera: desinstalar"
                color: Theme.textDisabled
                font.pixelSize: 11
            }

            // Aviso antes de desinstalar (UninstallPanel.qml): ocupa el sitio del recordatorio
            UninstallPanel {
                id: uninstallPanel
                hiddenIds: usage.hidden
                onHideRequested: entry => root.toggleHidden(entry)
                // Ya no hace falta tenerlas en la lista de ocultas: si algún día se vuelven a instalar, que salgan
                onUninstalled: ids => usage.hidden = usage.hidden.filter(id => !ids.includes(id))
            }
        }
    }

    Connections {                   // Super: "qs ipc call launcher toggle" (el IpcHandler está en services/ShellIpc.qml)
        target: ShellIpc
        function onLauncherToggled() { root.visible = !root.visible }
    }
}
