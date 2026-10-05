// Launcher.qml
// Widget que aparece al pulsar Super solo (sin combinar con otra tecla), anclado abajo-derecha
// Lista las aplicaciones instaladas (con icono) y las lanza al hacer clic
// Al abrirse ya se puede escribir para filtrar: flechas para moverse, Intro para lanzar, Esc para cerrar
// La rueda junto al buscador pasa a elegir qué apps se ocultan (ver "editing") o se desinstalan (ver "uninstall")

import Quickshell
import Quickshell.Io        // Para el JsonAdapter (cuántas veces se ha abierto cada app) y los Process de desinstalar
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
            cancelUninstall()                           // ...y sin el aviso de desinstalar de la vez anterior (salvo si sigue desinstalando)
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

    // --- Desinstalar ---
    // Mientras se eligen las ocultas, la papelera de cada fila (o Shift + Supr) abre abajo un
    // aviso con lo que pasaría al quitar su paquete, y solo se desinstala al confirmarlo.
    // Antes se mira con scripts/uninstall-check.sh (no cambia nada) si:
    //   - otro paquete la necesita: pacman no deja quitarla, así que se ofrece ocultarla
    //   - la instala el repo (packages.txt...): se puede quitar, pero install.sh la volvería a
    //     poner, así que se avisa para quitarla también de ahí
    //   - el paquete trae más apps, que también se irían, o dependencias que se quedan sin uso
    // Se desinstala con pkexec (la contraseña la pide PolkitDialog.qml) y "pacman -Rns".
    //   null, o { entry, state: "checking" | "ready" | "running",
    //             pkg, remove: [], apps: [], repo: [], blocked: [], error }
    // Objeto nuevo en cada cambio, no uninstall.state = ...: si se cambia por dentro, QML no se entera
    property var uninstall: null
    readonly property bool canUninstall: uninstall?.state === "ready" && !uninstall.error && uninstall.blocked.length === 0

    function askUninstall(entry) {
        if (!entry || uninstall?.state === "running") return   // Mientras desinstala una, no se pide otra
        uninstall = { entry: entry, state: "checking" }
        checkProc.exec([Quickshell.shellPath("scripts/uninstall-check.sh"), entry.id])     // exec: si estaba mirando otra, la corta
    }

    function confirmUninstall() {
        if (!canUninstall) return
        uninstall = Object.assign({}, uninstall, { state: "running" })
        // La salida de pacman y luego su código, para saber cómo ha ido sin depender de en qué
        // orden llegan el final de la salida y el exited() del proceso
        removeProc.exec(["sh", "-c", 'pkexec pacman -Rns --noconfirm "$1" 2>&1; echo "exit|$?"', "sh", uninstall.pkg])
    }

    function cancelUninstall() {
        if (uninstall?.state !== "running") uninstall = null    // Ya desinstalando no se corta: el aviso se queda hasta que acabe
    }

    // Lo que dice uninstall-check.sh (una línea "tipo|valor" por dato): los valores de un tipo
    function parseLines(text, kind) {
        return text.split("\n").filter(l => l.startsWith(kind + "|")).map(l => l.slice(kind.length + 1))
    }

    Process {
        id: checkProc
        stdout: StdioCollector {
            onStreamFinished: {
                const u = root.uninstall
                // Solo si sigue esperando justo esta: entretanto se ha podido cancelar o pedir otra
                if (u?.state !== "checking" || root.parseLines(text, "id")[0] !== u.entry.id) return
                root.uninstall = Object.assign({}, u, {
                    state: "ready",
                    pkg: root.parseLines(text, "pkg")[0] ?? "",
                    remove: root.parseLines(text, "remove"),
                    apps: root.parseLines(text, "app"),
                    repo: root.parseLines(text, "repo"),
                    blocked: root.parseLines(text, "blocked"),
                    error: root.parseLines(text, "error")[0] ?? ""
                })
            }
        }
    }

    Process {
        id: removeProc
        stdout: StdioCollector {
            onStreamFinished: {
                const u = root.uninstall
                if (u?.state !== "running") return
                const code = parseInt(root.parseLines(text, "exit")[0] ?? "-1")
                if (code === 0) {
                    // Ya no hace falta tenerla en la lista de ocultas (ni las otras apps del paquete):
                    // si algún día se vuelve a instalar, que salga
                    const gone = [u.entry.id, ...u.apps]
                    usage.hidden = usage.hidden.filter(id => !gone.includes(id))
                    NotificationCenter.notify("Launcher", "edit-delete", "Desinstalada " + u.entry.name,
                                              "Se ha quitado el paquete " + u.pkg + ".")
                    root.uninstall = null           // Su fila se va sola: DesktopEntries ve que ya no está el .desktop
                } else if (code === 126 || code === 127) {
                    // pkexec: se ha cancelado la contraseña o no era la buena. Se vuelve al aviso, por si se reintenta
                    root.uninstall = Object.assign({}, u, { state: "ready" })
                } else {
                    // Ha fallado pacman (otro pacman en marcha...): su última línea, para saber por qué
                    const lines = text.split("\n").filter(l => l !== "" && !l.startsWith("exit|"))
                    root.uninstall = Object.assign({}, u, { state: "ready", error: "pacman: " + (lines[lines.length - 1] ?? "ha fallado") })
                }
            }
        }
    }

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

            RowLayout {
                spacing: 8

                InputField {                    // Campo de búsqueda: ↑ ↓ mueven la selección de la lista
                    id: searchInput
                    placeholder: root.editing ? "Buscar app para ocultar…" : "Buscar…"
                    list: list
                    // Con el aviso de desinstalar abierto, Intro es su botón principal (ver más abajo)
                    onAccepted: {
                        if (root.uninstall) uninstallPanel.primary()
                        else root.activate(root.filteredApps[list.currentIndex])
                    }
                    // Esc primero cierra el aviso de desinstalar, luego sale de elegir las ocultas
                    // (como si se pulsara la rueda) y por último cierra el launcher
                    onEscapePressed: {
                        if (root.uninstall) root.cancelUninstall()
                        else if (root.editing) root.editing = false
                        else root.visible = false
                    }
                    onKeyPressed: event => {
                        // Shift + Supr como en el portapapeles: Supr sola borra letras del buscador
                        if (root.editing && event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                            root.askUninstall(root.filteredApps[list.currentIndex])
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
                        root.cancelUninstall()      // El aviso de desinstalar es del modo de elegir: se va con él
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
                        root.askUninstall(modelData)
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
                            color: root.uninstall?.entry === appDelegate.modelData ? Theme.textSelected : Theme.textActive
                            font.pixelSize: 16
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }

            Text {                                  // Recordatorio mientras se eligen las ocultas (como el de Clipboard.qml)
                visible: root.editing && !root.uninstall
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Intro o clic: ocultar / mostrar   ·   Esc: volver\nShift + Supr o papelera: desinstalar"
                color: Theme.textDisabled
                font.pixelSize: 11
            }

            // Aviso antes de desinstalar (ver "uninstall"): ocupa el sitio del recordatorio y
            // la lista se encoge para dejarle sitio
            Rectangle {
                id: uninstallPanel
                readonly property var u: root.uninstall ?? ({})
                readonly property bool blocked: (u.blocked ?? []).length > 0

                // Intro: lo mismo que el botón principal que se esté viendo
                function primary() {
                    if (root.canUninstall) root.confirmUninstall()
                    else if (u.state === "ready" && blocked) {
                        if (!root.isHidden(u.entry)) root.toggleHidden(u.entry)     // Si ya estaba oculta, no se vuelve a mostrar
                        root.cancelUninstall()
                    }
                    else if (u.state === "ready") root.cancelUninstall()        // Con error solo hay "Cerrar"
                }

                // Lo que se cuenta, una línea por cosa (con su icono las advertencias)
                readonly property var lines: {
                    if (u.state === "checking") return ["Comprobando…"]
                    if (u.state === "running") return ["Desinstalando " + u.pkg + "…"]
                    if (u.error) return [u.error]
                    if (blocked) return ["No se puede: la necesita " + u.blocked.join(", ") + ". Puedes ocultarla en su lugar."]
                    const out = []
                    const deps = (u.remove ?? []).filter(p => p !== u.pkg)
                    out.push("Se quita el paquete " + u.pkg + (deps.length ? " y " + deps.length + (deps.length === 1 ? " dependencia que ya no usa nada" : " dependencias que ya no usa nada") : ""))
                    if (u.apps?.length)                     // Las otras apps del paquete, por su nombre si se puede
                        out.push(String.fromCodePoint(0xF0026) + "  También se va: " + u.apps.map(id => DesktopEntries.byId(id)?.name ?? id).join(", "))
                    for (const file of u.repo ?? [])
                        out.push(String.fromCodePoint(0xF0026) + "  " + (file === "packages_opt.txt"
                            ? "Está en packages_opt.txt: install.sh volverá a preguntar si instalarla"
                            : "La instala el repo (" + file + "): install.sh la volverá a poner. Quítala también de ahí"))
                    return out
                }

                visible: root.uninstall !== null
                Layout.fillWidth: true
                implicitHeight: panelColumn.implicitHeight + 20
                radius: 8
                color: Theme.background
                border.color: Theme.border

                ColumnLayout {
                    id: panelColumn
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: "Desinstalar " + (uninstallPanel.u.entry?.name ?? "")
                        color: Theme.textActive
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Repeater {
                        model: uninstallPanel.lines
                        Text {
                            required property string modelData
                            Layout.fillWidth: true
                            text: modelData
                            textFormat: Text.PlainText      // Lleva mensajes de pacman: que no se interpreten como HTML
                            wrapMode: Text.WordWrap
                            color: Theme.textActive
                            font.pixelSize: 12
                        }
                    }

                    RowLayout {                             // Los botones, a la derecha; mientras mira o desinstala, ninguno
                        visible: uninstallPanel.u.state === "ready"
                        Layout.alignment: Qt.AlignRight
                        spacing: 8

                        Button {
                            visible: root.canUninstall
                            text: "Desinstalar"
                            accent: true
                            onClicked: root.confirmUninstall()
                        }
                        Button {
                            visible: uninstallPanel.blocked && !uninstallPanel.u.error
                            // Si ya estaba oculta, no hay nada que ofrecer: solo cerrar
                            enabled: !root.isHidden(uninstallPanel.u.entry ?? {})
                            text: "Ocultar"
                            accent: true
                            onClicked: uninstallPanel.primary()
                        }
                        Button {
                            text: root.canUninstall || (uninstallPanel.blocked && !uninstallPanel.u.error) ? "Cancelar" : "Cerrar"
                            onClicked: root.cancelUninstall()
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
