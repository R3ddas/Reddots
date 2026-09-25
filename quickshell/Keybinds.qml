// Keybinds.qml
// Chuleta de atajos de teclado: ventana en el centro de la pantalla que se abre
// desde el menú de Reddots (Reddots.qml). No lleva una lista escrita a mano: cada
// vez que se abre le pide a Hyprland sus atajos ("hyprctl binds -j") y pinta los que
// tienen "description" en hypr/keybinds.lua, así nunca se queda desfasada.
// La descripción tiene el formato "Sección: qué hace"; los atajos con la misma
// descripción salen juntos en una línea (Super + ← → ↑ ↓, Super + 1 … 0...).
// Se cierra con Esc o haciendo clic fuera.

import Quickshell
import Quickshell.Io        // Para lanzar hyprctl
import Quickshell.Hyprland  // Para el HyprlandFocusGrab
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    visible: false

    // Sin anchors: el compositor la coloca en el centro de la pantalla
    implicitWidth: 560
    implicitHeight: Math.min(content.implicitHeight + 32, (screen ? screen.height : 1080) * 0.85)   // Si no cabe, se hace scroll

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "reddots:keybinds"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None   // Igual que el Launcher: OnDemand para que el grab se entere del clic fuera

    property var sections: []       // [{ name, rows: [{ keys, text }] }], en el orden de hypr/keybinds.lua

    onVisibleChanged: {
        if (visible) {
            bindsProc.running = false
            bindsProc.running = true            // Siempre los atajos actuales (por si se ha tocado keybinds.lua)
            flick.contentY = 0
            flick.forceActiveFocus()            // Para recibir el Esc
            grabTimer.restart()
        } else {
            flick.focus = false                 // Nada con foco mientras está cerrada (ver el comentario de Keys, más abajo)
            grabTimer.stop(); grab.active = false
        }
    }

    // --- De "hyprctl binds -j" a texto -----------------------------------------

    // Modificadores de "modmask" (bits de Hyprland), en el orden en que se escriben
    function modNames(mask) {
        const names = []
        if (mask & 64) names.push("Super")
        if (mask & 4)  names.push("Ctrl")
        if (mask & 8)  names.push("Alt")
        if (mask & 1)  names.push("Shift")
        return names
    }

    // Nombre legible de cada tecla (las que no están aquí salen tal cual: "T", "1"...)
    readonly property var keyNames: ({
        "left": "←", "right": "→", "up": "↑", "down": "↓",
        "mouse_down": "Rueda ↓", "mouse_up": "Rueda ↑",
        "mouse:272": "Clic izquierdo", "mouse:273": "Clic derecho", "mouse:274": "Clic central",
        "TAB": "Tab", "RETURN": "Intro", "SPACE": "Espacio", "ESCAPE": "Esc", "Print": "Impr",
        "XF86AudioRaiseVolume": "Volumen +", "XF86AudioLowerVolume": "Volumen −",
        "XF86AudioMute": "Silencio", "XF86AudioMicMute": "Micro",
        "XF86MonBrightnessUp": "Brillo +", "XF86MonBrightnessDown": "Brillo −",
        "XF86AudioNext": "Siguiente", "XF86AudioPrev": "Anterior",
        "XF86AudioPlay": "Play", "XF86AudioPause": "Pausa"
    })

    // Atajos con la misma descripción y los mismos modificadores, en una sola combinación:
    // "Super + ← → ↑ ↓"; si son muchas teclas, solo la primera y la última ("Super + 1 … 0")
    function comboText(mask, keys) {
        const mods = modNames(mask)
        const labels = keys.filter(k => !k.startsWith("SUPER_")).map(k => keyNames[k] ?? k)   // "SUPER + SUPER_L" es Super sola
        const keyText = labels.length > 4 ? labels[0] + " … " + labels[labels.length - 1] : labels.join(" ")
        return mods.concat(keyText ? [keyText] : []).join(" + ")
    }

    function buildSections(binds) {
        const sections = []
        for (const b of binds) {
            const desc = b.description || ""
            const sep = desc.indexOf(": ")
            const sectionName = sep > 0 ? desc.slice(0, sep) : "Otros"                     // Sin "Sección: " va al final
            const text = sep > 0 ? desc.slice(sep + 2) : (desc || "(sin descripción)")     // Así se ve si a alguno le falta

            let section = sections.find(s => s.name === sectionName)
            if (!section) { section = { name: sectionName, rows: [] }; sections.push(section) }
            let row = section.rows.find(r => r.text === text)
            if (!row) { row = { text: text, combos: [] }; section.rows.push(row) }
            let combo = row.combos.find(c => c.mask === b.modmask)
            if (!combo) { combo = { mask: b.modmask, keys: [] }; row.combos.push(combo) }
            combo.keys.push(b.key)
        }
        const others = sections.findIndex(s => s.name === "Otros")                        // "Otros" siempre la última
        if (others >= 0) sections.push(sections.splice(others, 1)[0])
        return sections.map(s => ({
            name: s.name,
            rows: s.rows.map(r => ({ text: r.text, keys: r.combos.map(c => comboText(c.mask, c.keys)).join("   ·   ") }))
        }))
    }

    Process {
        id: bindsProc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.sections = root.buildSections(JSON.parse(text)) }
                catch (e) { root.sections = [] }                                    // Salida rara: se queda vacía en vez de romperse
            }
        }
    }

    // --- Ventana -----------------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        radius: Geometry.popupRounding              // Mismo estilo que los desplegables de la barra
        border.color: Theme.textSelected
        border.width: Geometry.popupBorderWidth

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 16
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            // Esc con Keys y el foco solo mientras está abierta, como en el Launcher. No con un
            // Shortcut: Quickshell a veces se cuelga (segfault) al cerrarse por culpa de él, aunque
            // la chuleta esté cerrada. Y al probar, no crear esta ventana ya visible (visible: true
            // de inicio) con algo con foco dentro: también se cuelga al cerrar Quickshell.
            Keys.onEscapePressed: root.visible = false

            ColumnLayout {
                id: content
                width: flick.width
                spacing: 14

                RowLayout {                         // Título
                    Layout.fillWidth: true
                    Text {
                        text: "Atajos de teclado"
                        color: Theme.textSelected
                        font.pixelSize: 16
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "Esc para cerrar"
                        color: Theme.textDisabled
                        font.pixelSize: 11
                    }
                }

                Text {
                    visible: root.sections.length === 0
                    text: "No se han podido leer los atajos de Hyprland"
                    color: Theme.textDisabled
                }

                Repeater {
                    model: root.sections
                    delegate: ColumnLayout {
                        id: section
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 4

                        Text {                      // Nombre de la sección
                            text: section.modelData.name
                            color: Theme.textSelected
                            font.bold: true
                            Layout.bottomMargin: 2
                        }

                        Rectangle {                 // Línea bajo el nombre
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Theme.border
                            Layout.bottomMargin: 4
                        }

                        Repeater {
                            model: section.modelData.rows
                            delegate: RowLayout {
                                id: row
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 16

                                Text {              // Teclas
                                    text: row.modelData.keys
                                    color: Theme.textActive
                                    font.bold: true
                                    Layout.preferredWidth: 230
                                    wrapMode: Text.WordWrap
                                    Layout.alignment: Qt.AlignTop
                                }
                                Text {              // Qué hace
                                    text: row.modelData.text
                                    color: Theme.textActive
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    Layout.alignment: Qt.AlignTop
                                }
                            }
                        }
                    }
                }
            }
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
