// Background.qml
// Fondo de pantalla, pintado por Quickshell (sustituye a hyprpaper). Una ventana por
// monitor en la capa más baja (Background), por debajo de las ventanas y de la barra.
// La imagen es la de Wallpaper.path (se elige en WallpaperSettings.qml); al cambiarla,
// la nueva aparece con un fundido sobre la anterior.
// Si Quickshell no está en marcha (p.ej. unos instantes al reiniciarlo), el fondo se ve negro.

import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore         // Ocupa toda la pantalla, también debajo de la barra
    color: "black"                              // Lo que se ve mientras carga la primera imagen (o si no se encuentra)
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "reddots:background"
    mask: Region {}                             // No recoge clics (tampoco hay nada que pulsar)

    readonly property string source: Wallpaper.ready && Wallpaper.path ? "file://" + Wallpaper.path : ""

    // Dos imágenes una encima de otra: "front" es la que se ve; al cambiar de fondo, la
    // nueva se carga en "back" (invisible) y, cuando está lista, aparece con un fundido
    // y pasa a ser la de delante. La de detrás se vacía para no ocupar memoria.
    property Image front: imageA
    readonly property Image back: front === imageA ? imageB : imageA
    property string requested: ""               // Último fondo pedido (se compara con esto y no con Image.source, que es una URL y puede venir codificada: "Im%C3%A1genes")

    function show(src) {
        if (src === "" || src === requested) return
        if (requested === "") front.source = src    // Primera imagen: sin fundido
        else back.source = src                      // El fundido lo lanza la imagen al terminar de cargar
        requested = src
    }
    onSourceChanged: show(source)
    Component.onCompleted: show(source)

    component WallpaperImage: Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop      // Rellena la pantalla recortando lo que sobre (el "cover" de hyprpaper)
        // Se decodifica ya al tamaño de la pantalla: un fondo 8K no ocupa la memoria de un 8K
        sourceSize.width: root.width
        sourceSize.height: root.height
        asynchronous: true                      // No bloquea la barra mientras decodifica
        smooth: true
        mipmap: true                            // Mejor calidad al reducir una imagen mucho más grande que la pantalla
    }

    WallpaperImage {
        id: imageA
        z: root.front === imageA ? 0 : 1        // La que entra, encima
        onStatusChanged: if (status === Image.Ready && root.back === imageA) fadeIn.start()
    }

    WallpaperImage {
        id: imageB
        z: root.front === imageB ? 0 : 1
        opacity: 0
        onStatusChanged: if (status === Image.Ready && root.back === imageB) fadeIn.start()
    }

    SequentialAnimation {
        id: fadeIn
        PropertyAction { target: root.back; property: "opacity"; value: 0 }
        NumberAnimation { target: root.back; property: "opacity"; to: 1; duration: 500; easing.type: Easing.InOutQuad }
        ScriptAction {
            script: {
                const old = root.front
                root.front = root.back          // La nueva pasa a ser la de delante...
                old.opacity = 0
                old.source = ""                 // ...y la vieja se vacía
            }
        }
    }
}
