pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.components                // StateFile

// Idioma de la interfaz: español (el de siempre) o inglés. Se elige en el menú del logo de
// Reddots (Reddots.qml) y se guarda en language.json, en el directorio de estado de Quickshell.
//
// Los textos siguen escritos en español en cada archivo, y se pasan por tr():
//     text: Lang.tr("Suspender")
//     tooltip: Lang.tr("Batería %1 %", level)       // %1, %2... se sustituyen por lo que siga
// En inglés, tr() busca la frase tal cual en en.json; si no está, la deja en español (y lo
// avisa una vez en el log de Quickshell, para saber que falta). Como tr() lee "code" y
// "strings", todo lo que la usa en un binding se vuelve a calcular al cambiar de idioma o al
// editar en.json, sin reiniciar. Lo que ya se ha creado con un texto (una notificación, un
// aviso guardado) se queda en el idioma en que se creó.
//
// Al cambiarlo desde el menú cambia también el idioma de los textos del sistema (solo
// LC_MESSAGES: los formatos de fecha, números, moneda... siguen los de LANG). Se apunta en
// ~/.local/state/reddots/lc_messages, que lee apps/fish/config.fish: así lo tiene cada
// terminal nuevo y, al entrar, Hyprland y todo lo que arranca. Lo que ya está abierto sigue
// en su idioma, porque los programas solo lo leen al arrancar; las apps del lanzador sí
// salen ya en el nuevo (Launcher.qml las lanza con systemLocale).
Singleton {
    id: root

    property alias code: adapter.code       // "es" o "en"
    // El LC_MESSAGES elegido para el sistema ("en_US.UTF-8"...). Vacío si nunca se ha cambiado
    // el idioma desde el menú: entonces no se toca el del sistema
    readonly property alias systemLocale: adapter.systemLocale

    // Para los nombres de días y meses (Clock.qml, LockScreen.qml): los del idioma elegido,
    // sea cual sea el del sistema
    readonly property var locale: Qt.locale(code === "en" ? "en_US" : "es_ES")

    // Las traducciones de en.json, ya sin los grupos: { "Suspender": "Suspend", ... }. Un binding
    // a text() y no un onLoaded: así ya están cuando se calculan los textos por primera vez
    // (onLoaded llega después), y se vuelve a calcular solo al guardar en.json
    readonly property var strings: {
        const all = {}
        try {
            for (const group of Object.values(JSON.parse(enFile.text() || "{}")))
                if (typeof group === "object") Object.assign(all, group)   // Los grupos; "_léeme" es solo una nota
        } catch (e) {
            console.warn("Lang: en.json no es un JSON válido:", e)
        }
        return all
    }
    onStringsChanged: warned = ({})         // Que vuelva a avisar de las que sigan faltando
    property var warned: ({})               // Frases sin traducir de las que ya se ha avisado

    function tr(text, ...args) { return root.trIn(root.code, text, ...args) }

    // tr() en un idioma concreto, sea cual sea el elegido
    function trIn(lang, text, ...args) {
        let out = text
        if (lang === "en") {
            if (text in root.strings) out = root.strings[text]
            else if (Object.keys(root.strings).length > 0 && !root.warned[text]) {      // Sin en.json, no avisa de todas
                root.warned[text] = true
                console.warn("Lang: falta la traducción de", JSON.stringify(text))
            }
        }
        args.forEach((arg, i) => out = out.split("%" + (i + 1)).join(arg))
        return out
    }

    function toggle() {
        // Todo con estas dos variables y no volviendo a leer code o systemLocale: al cambiar una
        // propiedad, StateFile guarda language.json y lo vuelve a leer, y leerla justo después
        // puede dar todavía el valor anterior
        const next = root.code === "en" ? "es" : "en"
        const locale = next === "en" ? "en_US.UTF-8" : "es_ES.UTF-8"
        adapter.code = next
        adapter.systemLocale = locale
        // El archivo de config.fish y, para las apps que lance systemd o D-Bus a partir de
        // ahora (diálogos de los portales...), su entorno
        Quickshell.execDetached(["sh", "-c",
            'dir="${XDG_STATE_HOME:-$HOME/.local/state}/reddots"; mkdir -p "$dir" && printf "%s\\n" "$1" > "$dir/lc_messages"; '
            + 'systemctl --user set-environment LC_MESSAGES="$1"', "sh", locale])
        NotificationCenter.notify("Reddots", "preferences-desktop-locale", root.trIn(next, "Idioma del sistema: español"),
            root.trIn(next, "Las apps que abras desde el lanzador y los terminales nuevos ya salen en español. El resto, al reiniciar la sesión."))
    }

    StateFile {
        name: "language.json"

        JsonAdapter {
            id: adapter
            property string code: "es"
            property string systemLocale: ""
        }
    }

    // en.json se lee con un FileView y no se importa como un .js: Quickshell no vigila los .js
    // importados, y un cambio en las traducciones no se vería hasta reiniciarlo
    FileView {
        id: enFile
        path: Quickshell.shellPath("services/en.json")
        blockLoading: true                  // Ya en el primer fotograma: si no, los textos saldrían un instante en español
        watchChanges: true
        onFileChanged: reload()
    }
}
