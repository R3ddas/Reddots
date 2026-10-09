// Icono de una notificación (tarjetas emergentes y lista de SystemStats). Prueba en orden:
//   1. la imagen que manda la app (avatar, captura...),
//   2. el icono de la app que pide la notificación (appIcon),
//   3. el icono de la app según su .desktop (desktopEntry, o adivinado por appName).
// Si uno no se puede abrir pasa al siguiente. Sirve, sobre todo, para el historial: la
// imagen suele ser un archivo temporal que la app borra al poco, y entonces sale el de la
// app. Sin ninguno, no se ve (y el layout no le deja hueco).
import Quickshell
import QtQuick

Item {
    id: root

    property string image: ""
    property string appIcon: ""
    property string desktopEntry: ""
    property string appName: ""
    property int size: 36                               // Lado en píxeles (es cuadrado)

    // appIcon puede venir como nombre de icono del tema ("firefox"), como ruta
    // ("/usr/share/...") o como URL ("file:///..."). Solo el nombre hay que
    // buscarlo en el tema de iconos; con "true" devuelve "" si no existe.
    function iconSource(icon) {
        if (!icon) return ""
        if (icon.startsWith("/")) return "file://" + icon
        if (icon.includes("://")) return icon
        return Quickshell.iconPath(icon, true)
    }

    // "notify-send -i" llega por image como "image://icon/<nombre o ruta>", y si
    // ese icono no existe se pinta un damero magenta. Se comprueba igual que appIcon.
    function imageSource(source) {
        if (!source) return ""
        if (source.startsWith("image://icon/")) return iconSource(source.slice(13).split("?")[0])
        return source
    }

    // El .desktop de la app: el que dice la notificación o, si no dice ninguno, el que más
    // se parezca a su nombre ("Teams" -> teams-for-linux.desktop)
    readonly property var entry: (desktopEntry ? DesktopEntries.byId(desktopEntry) : null)
                              ?? (appName ? DesktopEntries.heuristicLookup(appName) : null)

    readonly property var candidates: [imageSource(image), iconSource(appIcon), iconSource(entry?.icon ?? "")]
                                      .filter((s, i, all) => s !== "" && all.indexOf(s) === i)   // Sin vacíos ni repetidos
    property int attempt: 0
    onCandidatesChanged: attempt = 0

    // Tamaño fijo, y no el del dibujo. Por eso el Image va dentro de un Item: en un Image el
    // tamaño implícito es el de la imagen y no se puede cambiar
    implicitWidth: size
    implicitHeight: size
    visible: img.source.toString() !== "" && img.status !== Image.Error

    Image {
        id: img
        anchors.fill: parent
        source: root.candidates[root.attempt] ?? ""
        onStatusChanged: if (status === Image.Error && root.attempt < root.candidates.length - 1) root.attempt++   // No se puede abrir: el siguiente
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(root.size * 2, root.size * 2)   // Un SVG se rasteriza con nitidez y una foto grande no ocupa memoria de más
    }
}
