// Aviso antes de desinstalar una app desde el Launcher (Launcher.qml), abajo del todo: ocupa
// el sitio del recordatorio de teclas, y la lista se encoge para dejarle sitio. Se pide con
// ask() (la papelera de una fila o Shift + Supr, mientras se eligen las ocultas) y solo se
// desinstala al confirmarlo. Antes se mira con scripts/uninstall-check.sh (no cambia nada) si:
//   - otro paquete la necesita: pacman no deja quitarla, así que se ofrece ocultarla
//   - la instala el repo (packages.txt...): se puede quitar, pero install.sh la volvería a
//     poner, así que se avisa para quitarla también de ahí
//   - el paquete trae más apps, que también se irían, o dependencias que se quedan sin uso
// Se desinstala con pkexec (la contraseña la pide PolkitDialog.qml) y "pacman -Rns".
//
// Las apps ocultas son del Launcher (launcher.json): aquí solo se leen ("hiddenIds") y se
// pide cambiarlas con hideRequested() y uninstalled().
import Quickshell
import Quickshell.Io                // Para los Process de uninstall-check.sh y de pacman
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

Rectangle {
    id: root

    property var hiddenIds: []          // Las apps ocultas del Launcher (ids de .desktop)
    signal hideRequested(var entry)     // Ocultar esta app en vez de desinstalarla (la necesita otro paquete)
    signal uninstalled(var ids)         // Se han desinstalado estas apps: ya no hace falta tenerlas en las ocultas

    // La desinstalación pedida:
    //   null, o { entry, state: "checking" | "ready" | "running",
    //             pkg, remove: [], apps: [], repo: [], blocked: [], error }
    // Objeto nuevo en cada cambio, no request.state = ...: si se cambia por dentro, QML no se entera
    property var request: null
    readonly property bool canUninstall: request?.state === "ready" && !request.error && request.blocked.length === 0

    readonly property var u: request ?? ({})
    readonly property bool blocked: (u.blocked ?? []).length > 0

    function isHidden(entry) { return hiddenIds.includes(entry?.id) }

    function ask(entry) {
        if (!entry || request?.state === "running") return     // Mientras desinstala una, no se pide otra
        request = { entry: entry, state: "checking" }
        checkProc.exec([Quickshell.shellPath("scripts/uninstall-check.sh"), entry.id])     // exec: si estaba mirando otra, la corta
    }

    function confirm() {
        if (!canUninstall) return
        request = Object.assign({}, request, { state: "running" })
        // La salida de pacman y luego su código, para saber cómo ha ido sin depender de en qué
        // orden llegan el final de la salida y el exited() del proceso
        removeProc.exec(["sh", "-c", 'pkexec pacman -Rns --noconfirm "$1" 2>&1; echo "exit|$?"', "sh", request.pkg])
    }

    function cancel() {
        if (request?.state !== "running") request = null       // Ya desinstalando no se corta: el aviso se queda hasta que acabe
    }

    // Intro en el buscador: lo mismo que el botón principal que se esté viendo
    function primary() {
        if (canUninstall) confirm()
        else if (u.state === "ready" && blocked) {
            if (!isHidden(u.entry)) hideRequested(u.entry)      // Si ya estaba oculta, no se vuelve a mostrar
            cancel()
        }
        else if (u.state === "ready") cancel()                  // Con error solo hay "Cerrar"
    }

    Process {
        id: checkProc
        stdout: StdioCollector {
            onStreamFinished: {
                const u = root.request
                // Solo si sigue esperando justo esta: entretanto se ha podido cancelar o pedir otra
                if (u?.state !== "checking" || Utils.parseLines(text, "id")[0] !== u.entry.id) return
                root.request = Object.assign({}, u, {
                    state: "ready",
                    pkg: Utils.parseLines(text, "pkg")[0] ?? "",
                    remove: Utils.parseLines(text, "remove"),
                    apps: Utils.parseLines(text, "app"),
                    repo: Utils.parseLines(text, "repo"),
                    blocked: Utils.parseLines(text, "blocked"),
                    error: Utils.parseLines(text, "error")[0] ?? ""
                })
            }
        }
    }

    Process {
        id: removeProc
        stdout: StdioCollector {
            onStreamFinished: {
                const u = root.request
                if (u?.state !== "running") return
                const code = parseInt(Utils.parseLines(text, "exit")[0] ?? "-1")
                if (code === 0) {
                    // Ya no hace falta tenerla en la lista de ocultas (ni las otras apps del paquete):
                    // si algún día se vuelve a instalar, que salga
                    root.uninstalled([u.entry.id, ...u.apps])
                    NotificationCenter.notify("Launcher", "edit-delete", "Desinstalada " + u.entry.name,
                                              "Se ha quitado el paquete " + u.pkg + ".")
                    root.request = null             // Su fila se va sola: DesktopEntries ve que ya no está el .desktop
                } else if (code === 126 || code === 127) {
                    // pkexec: se ha cancelado la contraseña o no era la buena. Se vuelve al aviso, por si se reintenta
                    root.request = Object.assign({}, u, { state: "ready" })
                } else {
                    // Ha fallado pacman (otro pacman en marcha...): su última línea, para saber por qué
                    const lines = text.split("\n").filter(l => l !== "" && !l.startsWith("exit|"))
                    root.request = Object.assign({}, u, { state: "ready", error: "pacman: " + (lines[lines.length - 1] ?? "ha fallado") })
                }
            }
        }
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

    visible: request !== null
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
            text: "Desinstalar " + (root.u.entry?.name ?? "")
            color: Theme.textActive
            font.bold: true
            elide: Text.ElideRight
        }

        Repeater {
            model: root.lines
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
            visible: root.u.state === "ready"
            Layout.alignment: Qt.AlignRight
            spacing: 8

            Button {
                visible: root.canUninstall
                text: "Desinstalar"
                accent: true
                onClicked: root.confirm()
            }
            Button {
                visible: root.blocked && !root.u.error
                // Si ya estaba oculta, no hay nada que ofrecer: solo cerrar
                enabled: !root.isHidden(root.u.entry)
                text: "Ocultar"
                accent: true
                onClicked: root.primary()
            }
            Button {
                text: root.canUninstall || (root.blocked && !root.u.error) ? "Cancelar" : "Cerrar"
                onClicked: root.cancel()
            }
        }
    }
}
