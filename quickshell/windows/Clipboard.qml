// Historial del portapapeles: ventana en el centro de la pantalla que se abre con
// Super + V ("qs ipc call clipboard toggle", ver hypr/keybinds.lua). El historial lo
// guarda cliphist, que Hyprland arranca al iniciar ("wl-paste --watch cliphist store",
// ver hypr/hyprland.lua); esto solo lo lee y lo muestra.
// Al elegir una entrada se vuelve a copiar al portapapeles, lista para pegar con Ctrl + V.
// Se puede escribir para filtrar: flechas para moverse, Intro para copiar,
// Shift + Supr para borrar la entrada del historial, Esc para cerrar.
// cliphist no guarda lo que copian los gestores de contraseñas (lo marcan como sensible).

import Quickshell
import Quickshell.Io        // Para lanzar cliphist
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

OverlayWindow {             // Se cierra al hacer clic fuera (ver OverlayWindow.qml)
    id: root

    // Sin anchors: el compositor la coloca en el centro de la pantalla
    implicitWidth: 520
    implicitHeight: 560

    WlrLayershell.namespace: "reddots:clipboard"

    // Miniaturas de las imágenes: se sacan de cliphist a esta carpeta la primera vez que
    // se ven. En XDG_RUNTIME_DIR (memoria), así se borran solas al apagar.
    readonly property string thumbDir: Quickshell.env("XDG_RUNTIME_DIR") + "/reddots-cliphist"

    property var entries: []        // [{ id, text, image, info }], lo más reciente primero

    onVisibleChanged: {
        if (visible) {
            searchInput.text = ""                       // Cada vez que se abre empieza sin filtro
            list.currentIndex = 0
            reload()
            searchInput.input.forceActiveFocus()
        } else {
            searchInput.input.focus = false                 // Nada con foco mientras está cerrada (ver Keybinds.qml)
        }
    }

    function reload() {
        listProc.running = false
        listProc.running = true
    }

    property var filteredEntries: {
        const query = Utils.normalize(searchInput.text.trim())
        if (query === "") return entries
        return entries.filter(e => Utils.normalize(e.image ? "imagen " + e.info : e.text).includes(query))   // Las imágenes se encuentran escribiendo "imagen"
    }

    function copy(entry) {
        if (!entry) return
        // El id se pasa como argumento ($1) y no pegado en el comando, por si acaso
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", entry.id])
        root.visible = false
    }

    function remove(entry) {
        if (!entry) return
        const index = list.currentIndex
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "sh", entry.id])
        if (entry.image) Quickshell.execDetached(["rm", "-f", "--", root.thumbDir + "/" + entry.id])   // Y su miniatura, si la tenía
        entries = entries.filter(e => e.id !== entry.id)            // Sin esperar a cliphist: desaparece ya de la lista
        list.currentIndex = Math.min(index, list.count - 1)
    }

    // Borra las miniaturas de imágenes que ya no están en el historial: las que cliphist
    // quita solo al llenarse, o todas tras un "cliphist wipe". Se llama cada vez que se
    // abre, con la lista recién leída. Los nombres de las miniaturas son los id de cliphist.
    function pruneThumbs() {
        const keep = entries.filter(e => e.image).map(e => e.id)
        Quickshell.execDetached(["sh", "-c",
            "cd \"$1\" 2>/dev/null || exit 0; shift; for f in *; do [ -e \"$f\" ] || continue; "
            + "case \" $* \" in *\" $f \"*) ;; *) rm -f -- \"$f\" ;; esac; done",
            "sh", thumbDir].concat(keep))
    }

    // "cliphist list": una línea por entrada, "id<TAB>vista previa". Los saltos de línea
    // y tabuladores del texto ya vienen como espacios. Las imágenes vienen como
    // "[[ binary data 6 KiB png 60x440 ]]".
    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l.includes("\t")).map(line => {
                    const tab = line.indexOf("\t")
                    const preview = line.slice(tab + 1)
                    const image = preview.match(/^\[\[ binary data (.+) \]\]$/)
                    return { id: line.slice(0, tab), text: preview, image: image !== null, info: image ? image[1] : "" }
                })
                root.pruneThumbs()
            }
        }
        // Si todavía no se ha copiado nada, cliphist sale con error y no escribe nada: la lista se queda vacía
        onExited: code => {
            if (code !== 0) {
                root.entries = []
                root.pruneThumbs()          // Sin historial (p.ej. tras "cliphist wipe"): fuera todas las miniaturas
            }
        }
    }

    Frame {                                         // Mismo estilo que los desplegables de la barra
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            InputField {                            // Campo de búsqueda (como el del Launcher): ↑ ↓ mueven la selección de la lista
                id: searchInput
                placeholder: "Buscar en el portapapeles…"
                list: list
                onAccepted: root.copy(root.filteredEntries[list.currentIndex])
                onEscapePressed: root.visible = false
                onKeyPressed: event => {
                    if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {   // Supr sola borra letras del buscador
                        root.remove(root.filteredEntries[list.currentIndex])
                        event.accepted = true
                    }
                }
            }

            SelectionList {
                id: list
                model: root.filteredEntries
                emptyText: root.entries.length === 0 ? "El historial está vacío: copia algo" : "Sin resultados"
                onActivated: index => root.copy(root.filteredEntries[index])

                delegate: Item {
                    id: entryDelegate
                    required property var modelData

                    width: ListView.view.width
                    height: modelData.image ? 72 : 40

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        // Miniatura, solo en las imágenes. Se carga directamente de thumbDir, sin
                        // lanzar nada: solo si aún no está ahí (falla al abrirla) se saca de cliphist
                        // y se vuelve a cargar. Antes cada miniatura lanzaba un sh para comprobarlo,
                        // cada vez que se creaba su fila (al abrir la ventana y al hacer scroll).
                        Image {
                            id: thumb
                            readonly property string file: root.thumbDir + "/" + entryDelegate.modelData.id
                            property bool decoding: false   // Ya se ha pedido a cliphist: si vuelve a fallar, no se insiste
                            visible: entryDelegate.modelData.image
                            source: entryDelegate.modelData.image ? "file://" + file : ""
                            Layout.preferredWidth: 96
                            Layout.preferredHeight: 60
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize.width: 192   // No carga la imagen entera en memoria, solo lo que hace falta para la miniatura
                            sourceSize.height: 120

                            onStatusChanged: if (status === Image.Error && !decoding) {
                                decoding = true
                                decodeProc.running = true
                            }

                            // A un .tmp y luego se renombra: si se corta a medias, no queda una miniatura
                            // rota con el nombre bueno (la próxima vez fallaría al abrirla y se volvería a sacar)
                            Process {
                                id: decodeProc
                                command: ["sh", "-c", "mkdir -p \"$1\" && cliphist decode \"$2\" > \"$1/$2.tmp\" && mv \"$1/$2.tmp\" \"$1/$2\"",
                                          "sh", root.thumbDir, entryDelegate.modelData.id]
                                onExited: code => {
                                    if (code !== 0) return
                                    thumb.source = ""                       // Misma ruta que antes: sin vaciarla, Image no la vuelve a leer
                                    thumb.source = "file://" + thumb.file
                                }
                            }
                        }

                        Text {
                            text: entryDelegate.modelData.image ? "Imagen · " + entryDelegate.modelData.info : entryDelegate.modelData.text
                            color: entryDelegate.modelData.image ? Theme.textDisabled : Theme.textActive
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }

            Text {                                  // Recordatorio de las teclas
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "Intro: copiar   ·   Shift + Supr: borrar del historial   ·   Esc: cerrar"
                color: Theme.textDisabled
                font.pixelSize: 11
            }
        }
    }

    Connections {                   // Super + V: "qs ipc call clipboard toggle" (el IpcHandler está en services/ShellIpc.qml)
        target: ShellIpc
        function onClipboardToggled() { root.visible = !root.visible }
    }
}
