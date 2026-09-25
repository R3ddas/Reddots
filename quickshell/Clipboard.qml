// Clipboard.qml
// Historial del portapapeles: ventana en el centro de la pantalla que se abre con
// Super + V ("qs ipc call clipboard toggle", ver hypr/keybinds.lua). El historial lo
// guarda cliphist, que Hyprland arranca al iniciar ("wl-paste --watch cliphist store",
// ver hypr/hyprland.lua); esto solo lo lee y lo muestra.
// Al elegir una entrada se vuelve a copiar al portapapeles, lista para pegar con Ctrl + V.
// Se puede escribir para filtrar: flechas para moverse, Intro para copiar,
// Shift + Supr para borrar la entrada del historial, Esc para cerrar.
// cliphist no guarda lo que copian los gestores de contraseñas (lo marcan como sensible).

import Quickshell
import Quickshell.Io        // Para el IpcHandler y lanzar cliphist
import Quickshell.Hyprland  // Para el HyprlandFocusGrab
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    visible: false

    // Sin anchors: el compositor la coloca en el centro de la pantalla
    implicitWidth: 520
    implicitHeight: 560

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "reddots:clipboard"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None   // Igual que el Launcher: OnDemand para que el grab se entere del clic fuera

    // Miniaturas de las imágenes: se sacan de cliphist a esta carpeta la primera vez que
    // se ven. En XDG_RUNTIME_DIR (memoria), así se borran solas al apagar.
    readonly property string thumbDir: Quickshell.env("XDG_RUNTIME_DIR") + "/reddots-cliphist"

    property var entries: []        // [{ id, text, image, info }], lo más reciente primero

    onVisibleChanged: {
        if (visible) {
            searchInput.text = ""                       // Cada vez que se abre empieza sin filtro
            list.currentIndex = 0
            reload()
            searchInput.forceActiveFocus()
            grabTimer.restart()
        } else {
            searchInput.focus = false                   // Nada con foco mientras está cerrada (ver Keybinds.qml)
            grabTimer.stop(); grab.active = false
        }
    }

    function reload() {
        listProc.running = false
        listProc.running = true
    }

    // Quita mayúsculas y tildes, igual que en el Launcher
    function normalize(s) {
        return (s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
    }

    property var filteredEntries: {
        const query = normalize(searchInput.text.trim())
        if (query === "") return entries
        return entries.filter(e => normalize(e.image ? "imagen " + e.info : e.text).includes(query))   // Las imágenes se encuentran escribiendo "imagen"
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
        entries = entries.filter(e => e.id !== entry.id)            // Sin esperar a cliphist: desaparece ya de la lista
        list.currentIndex = Math.min(index, list.count - 1)
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
            }
        }
        // Si todavía no se ha copiado nada, cliphist sale con error y no escribe nada: la lista se queda vacía
        onExited: code => { if (code !== 0) root.entries = [] }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        radius: Geometry.popupRounding              // Mismo estilo que los desplegables de la barra
        border.color: Theme.textSelected
        border.width: Geometry.popupBorderWidth

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Rectangle {                             // Campo de búsqueda (como el del Launcher)
                Layout.fillWidth: true
                implicitHeight: 36
                radius: 8
                color: Theme.background
                border.color: Theme.border

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.textActive
                    selectionColor: Theme.surfaceHover
                    clip: true

                    onTextChanged: list.currentIndex = 0   // Al filtrar, se selecciona el primer resultado

                    Keys.onDownPressed: list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1)
                    Keys.onUpPressed: list.currentIndex = Math.max(list.currentIndex - 1, 0)
                    Keys.onReturnPressed: root.copy(root.filteredEntries[list.currentIndex])
                    Keys.onEnterPressed: root.copy(root.filteredEntries[list.currentIndex])    // Intro del teclado numérico
                    Keys.onEscapePressed: root.visible = false
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {   // Supr sola borra letras del buscador
                            root.remove(root.filteredEntries[list.currentIndex])
                            event.accepted = true
                        }
                    }

                    Text {                          // Texto de ayuda mientras el campo está vacío
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text === ""
                        text: "Buscar en el portapapeles…"
                        color: Theme.textDisabled
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: root.filteredEntries
                boundsBehavior: Flickable.StopAtBounds
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)  // Hace scroll para que el seleccionado se vea

                Text {
                    visible: list.count === 0
                    text: root.entries.length === 0 ? "El historial está vacío: copia algo" : "Sin resultados"
                    color: Theme.textDisabled
                }

                delegate: Rectangle {
                    id: entryDelegate
                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: modelData.image ? 72 : 40
                    radius: 8
                    color: ListView.isCurrentItem ? Theme.surfaceHover : "transparent"   // El ratón y las flechas mueven la misma selección

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Image {                     // Miniatura, solo en las imágenes
                            id: thumb
                            visible: entryDelegate.modelData.image
                            Layout.preferredWidth: 96
                            Layout.preferredHeight: 60
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize.width: 192   // No carga la imagen entera en memoria, solo lo que hace falta para la miniatura
                            sourceSize.height: 120

                            // La saca de cliphist a thumbDir si aún no está ahí, y luego la carga
                            Process {
                                running: entryDelegate.modelData.image
                                command: ["sh", "-c", "mkdir -p \"$1\" && f=\"$1/$2\" && { [ -s \"$f\" ] || cliphist decode \"$2\" > \"$f\"; } && echo \"$f\"",
                                          "sh", root.thumbDir, entryDelegate.modelData.id]
                                stdout: StdioCollector { onStreamFinished: thumb.source = text.trim() ? "file://" + text.trim() : "" }
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

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: list.currentIndex = entryDelegate.index
                        onClicked: root.copy(entryDelegate.modelData)
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

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            root.visible = !root.visible
        }
    }

    HyprlandFocusGrab {
        id: grab
        windows: [root]
        active: false
        onCleared: root.visible = false             // Se cierra al hacer clic fuera
    }

    Timer {
        id: grabTimer
        interval: 5
        onTriggered: grab.active = true
    }
}
